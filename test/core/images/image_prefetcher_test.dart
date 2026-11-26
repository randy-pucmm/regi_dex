import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/images/image_prefetcher.dart';

/// Caché falsa: [cached] ya están, [statuses] fallan con ese HTTP y
/// [networkDown] fallan por la red; el resto se "descarga".
class _FakeCache {
  final cached = <String>{};
  final statuses = <String, int>{};
  final networkDown = <String>{};
  final downloads = <String>[];
  var inFlight = 0;
  var maxInFlight = 0;

  Future<bool> isCached(String url) async => cached.contains(url);

  Future<void> download(String url) async {
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    await Future<void>.delayed(Duration.zero);
    inFlight--;
    final status = statuses[url];
    if (status != null) throw HttpExceptionWithStatus(status, 'HTTP $status');
    if (networkDown.contains(url)) throw const SocketException('sin red');
    downloads.add(url);
    cached.add(url);
  }
}

List<String> _urls(int n) => [
  for (var i = 1; i <= n; i++) 'https://img/$i.png',
];

void main() {
  late _FakeCache cache;
  late ImagePrefetcher prefetcher;

  ImagePrefetcher buildPrefetcher({
    int concurrency = 3,
    int maxConsecutiveFailures = 10,
  }) => ImagePrefetcher(
    isCached: cache.isCached,
    download: cache.download,
    concurrency: concurrency,
    maxConsecutiveFailures: maxConsecutiveFailures,
  );

  setUp(() {
    cache = _FakeCache();
    prefetcher = buildPrefetcher(concurrency: 3);
  });
  tearDown(() => prefetcher.dispose());

  test('descarga lo que falta y salta lo que ya está en caché', () async {
    final urls = _urls(10);
    cache.cached.addAll(urls.take(4));

    final result = await prefetcher.prefetch(urls);

    expect(result.downloaded, 6);
    expect(result.alreadyCached, 4);
    expect(result.isComplete, isTrue);
    expect(cache.downloads, hasLength(6));
  });

  test('una segunda pasada no descarga nada', () async {
    final urls = _urls(8);
    await prefetcher.prefetch(urls);
    cache.downloads.clear();

    final result = await prefetcher.prefetch(urls);

    expect(result.downloaded, 0);
    expect(result.alreadyCached, 8);
    expect(cache.downloads, isEmpty);
  });

  test('las URL repetidas se descargan una sola vez', () async {
    final result = await prefetcher.prefetch([..._urls(3), ..._urls(3)]);

    expect(result.downloaded, 3);
  });

  test('respeta la concurrencia', () async {
    await prefetcher.prefetch(_urls(20));

    expect(cache.maxInFlight, lessThanOrEqualTo(3));
    expect(cache.maxInFlight, greaterThan(1));
  });

  test(
    'una imagen que el servidor no tiene (404) no cuenta como fallo',
    () async {
      final urls = _urls(5);
      cache.statuses[urls[2]] = 404;

      final result = await prefetcher.prefetch(urls);

      expect(result.missing, 1);
      expect(result.downloaded, 4);
      expect(result.isComplete, isTrue);
    },
  );

  test('un error del servidor (5xx) o de red sí es un fallo', () async {
    final urls = _urls(6);
    cache.statuses[urls[1]] = 503;
    cache.networkDown.add(urls[4]);

    final result = await prefetcher.prefetch(urls);

    expect(result.failed, 2);
    expect(result.downloaded, 4);
    expect(result.isComplete, isFalse);
  });

  test(
    'sin red se detiene tras varios fallos seguidos y deja el resto pendiente',
    () async {
      final urls = _urls(100);
      cache.networkDown.addAll(urls);
      prefetcher = buildPrefetcher(maxConsecutiveFailures: 5);

      final result = await prefetcher.prefetch(urls);

      expect(result.isComplete, isFalse);
      expect(result.failed, 100);
      expect(cache.downloads, isEmpty);
      expect(cache.inFlight, 0);
    },
  );

  test('informa el avance y vuelve a inactivo al terminar', () async {
    final seen = <ImagePrefetchProgress>[];
    final subscription = prefetcher.progress.listen(seen.add);
    await pumpEventQueue();

    await prefetcher.prefetch(_urls(4));
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen.first, ImagePrefetchProgress.idle);
    expect(seen, contains(const ImagePrefetchProgress(done: 4, total: 4)));
    expect(seen.last, ImagePrefetchProgress.idle);
    expect(prefetcher.current.isRunning, isFalse);
  });
}

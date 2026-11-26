import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Avance de la descarga de imágenes: [done] de [total]. Con [total] en 0 no
/// hay descarga en curso.
class ImagePrefetchProgress {
  const ImagePrefetchProgress({this.done = 0, this.total = 0});

  static const idle = ImagePrefetchProgress();

  final int done;
  final int total;

  bool get isRunning => total > 0;

  @override
  bool operator ==(Object other) =>
      other is ImagePrefetchProgress &&
      other.done == done &&
      other.total == total;

  @override
  int get hashCode => Object.hash(done, total);
}

/// Resultado de [ImagePrefetcher.prefetch].
class ImagePrefetchResult {
  const ImagePrefetchResult({
    required this.downloaded,
    required this.alreadyCached,
    required this.missing,
    required this.failed,
  });

  /// Imágenes descargadas ahora.
  final int downloaded;

  /// Imágenes que ya estaban en la caché.
  final int alreadyCached;

  /// Imágenes que el servidor no tiene (HTTP 4xx): no se reintentan.
  final int missing;

  /// Imágenes que no se pudieron bajar por la red o el servidor.
  final int failed;

  bool get isComplete => failed == 0;
}

/// Descarga las imágenes pendientes a la caché de disco (ADR-004).
///
/// Las URL de sprites no gastan el presupuesto de PokéAPI, así que se bajan
/// todas en segundo plano. Se saltan las que ya están en caché, se tolera que
/// el servidor no tenga alguna (4xx) y se detiene si la red falla varias veces
/// seguidas, para no insistir sin conexión.
class ImagePrefetcher {
  /// [isCached] dice si una URL ya está en la caché y [download] la baja
  /// (lanza [HttpExceptionWithStatus] si el servidor responde un error).
  /// [concurrency] es cuántas descargas corren a la vez y
  /// [maxConsecutiveFailures] cuántos fallos seguidos de red detienen la pasada.
  ImagePrefetcher({
    required this._isCached,
    required this._download,
    this.concurrency = 6,
    this.maxConsecutiveFailures = 10,
  });

  /// Prefetcher sobre la caché de disco [cache].
  factory ImagePrefetcher.forCache(
    BaseCacheManager cache, {
    int concurrency = 6,
    int maxConsecutiveFailures = 10,
  }) => ImagePrefetcher(
    isCached: (url) async => await cache.getFileFromCache(url) != null,
    download: (url) => cache.getSingleFile(url),
    concurrency: concurrency,
    maxConsecutiveFailures: maxConsecutiveFailures,
  );

  final Future<bool> Function(String url) _isCached;
  final Future<void> Function(String url) _download;
  final int concurrency;
  final int maxConsecutiveFailures;
  final _progress = StreamController<ImagePrefetchProgress>.broadcast();
  var _current = ImagePrefetchProgress.idle;

  /// Avance actual.
  ImagePrefetchProgress get current => _current;

  /// Avance: emite el actual al suscribirse y luego cada cambio.
  Stream<ImagePrefetchProgress> get progress async* {
    yield _current;
    yield* _progress.stream;
  }

  /// Descarga las [urls] que falten y devuelve cuántas se descargaron, ya
  /// estaban, no existen o fallaron. Los duplicados se descargan una vez.
  Future<ImagePrefetchResult> prefetch(Iterable<String> urls) async {
    final pending = urls.toSet().toList();
    var downloaded = 0, cached = 0, missing = 0, failed = 0;
    var done = 0, streak = 0, next = 0;
    _emit(ImagePrefetchProgress(total: pending.length));

    Future<void> worker() async {
      while (next < pending.length && streak < maxConsecutiveFailures) {
        final url = pending[next++];
        switch (await _fetch(url)) {
          case _Outcome.cached:
            cached++;
            streak = 0;
          case _Outcome.downloaded:
            downloaded++;
            streak = 0;
          case _Outcome.missing:
            missing++;
            streak = 0;
          case _Outcome.failed:
            failed++;
            streak++;
        }
        _emit(ImagePrefetchProgress(done: ++done, total: pending.length));
      }
    }

    try {
      await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
    } finally {
      _emit(ImagePrefetchProgress.idle);
    }

    // Lo que quedó sin intentar por cortar la pasada también cuenta como pendiente.
    final skipped = pending.length - done;
    return ImagePrefetchResult(
      downloaded: downloaded,
      alreadyCached: cached,
      missing: missing,
      failed: failed + skipped,
    );
  }

  /// Cierra el flujo de avance.
  void dispose() => unawaited(_progress.close());

  Future<_Outcome> _fetch(String url) async {
    try {
      if (await _isCached(url)) return _Outcome.cached;
      await _download(url);
      return _Outcome.downloaded;
    } on HttpExceptionWithStatus catch (error) {
      final clientError = error.statusCode >= 400 && error.statusCode < 500;
      return clientError ? _Outcome.missing : _Outcome.failed;
    } catch (_) {
      return _Outcome.failed;
    }
  }

  void _emit(ImagePrefetchProgress progress) {
    if (progress == _current) return;
    _current = progress;
    if (!_progress.isClosed) _progress.add(progress);
  }
}

enum _Outcome { cached, downloaded, missing, failed }

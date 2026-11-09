import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/images/regi_image_cache_manager.dart';

void main() {
  late Directory dir;
  late RegiImageCacheManager manager;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dir = await Directory.systemTemp.createTemp('regi_images_test');
    addTearDown(() => dir.delete(recursive: true));
    // La caché guarda sus archivos y su índice donde diga path_provider.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => dir.path,
        );
    manager = RegiImageCacheManager(
      config: Config('regidex_images_test', maxNrOfCacheObjects: 1500),
      maxBytes: 250,
    );
    addTearDown(manager.dispose);
  });

  Future<void> put(String key) async {
    await manager.putFile(key, Uint8List(100), key: key);
    // Que cada archivo tenga una marca de uso distinta.
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  Future<bool> isCached(String key) async =>
      await manager.getFileFromCache(key) != null;

  test(
    'recorta los menos usados hasta que cabe en el límite de bytes',
    () async {
      await put('a');
      await put('b');
      await put('c');

      await manager.trimToSize();

      expect(await isCached('a'), isFalse, reason: '300 B no caben en 250 B');
      expect(await isCached('b'), isTrue);
      expect(await isCached('c'), isTrue);
    },
  );

  test(
    'es LRU: lo que se acaba de ver se salva aunque sea el más viejo',
    () async {
      await put('a');
      await put('b');
      await put('c');
      // Sesión nueva: con la memoria vacía, ver «a» la marca como la más reciente.
      manager.store.emptyMemoryCache();
      expect(await isCached('a'), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await manager.trimToSize();

      expect(await isCached('a'), isTrue);
      expect(await isCached('b'), isFalse);
      expect(await isCached('c'), isTrue);
    },
  );

  test('si todo cabe no borra nada', () async {
    await put('a');
    await put('b');

    await manager.trimToSize();

    expect(await isCached('a'), isTrue);
    expect(await isCached('b'), isTrue);
  });

  test('lo guardado sigue ahí tras reiniciar, sin descargar nada', () async {
    await put('a');
    await manager.dispose();

    final restarted = RegiImageCacheManager(
      config: Config('regidex_images_test', maxNrOfCacheObjects: 1500),
      maxBytes: 250,
    );
    addTearDown(restarted.dispose);

    expect(await restarted.getFileFromCache('a'), isNotNull);
  });

  test(
    'emptyCache vacía todo (la base de «Borrar caché de imágenes»)',
    () async {
      await put('a');
      await put('b');

      await manager.emptyCache();

      expect(await isCached('a'), isFalse);
      expect(await isCached('b'), isFalse);
    },
  );
}

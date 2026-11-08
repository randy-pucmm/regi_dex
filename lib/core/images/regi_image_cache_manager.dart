import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'image_cache_policy.dart';

/// Caché de imágenes en disco: LRU de 1500 archivos (lo hace la librería) y
/// 150 MB (lo hace [trimToSize], porque la librería solo cuenta archivos).
///
/// Tras descargar algo nuevo recorta una vez pasado [trimDelay], para que una
/// ráfaga de imágenes de una lista provoque un solo recorte.
class RegiImageCacheManager extends CacheManager with ImageCacheManager {
  RegiImageCacheManager({
    Config? config,
    this._maxBytes = ImageCacheLimits.maxBytes,
    this._trimDelay = const Duration(seconds: 5),
  }) : super(
         config ??
             Config(_cacheKey, maxNrOfCacheObjects: ImageCacheLimits.maxFiles),
       );

  static const _cacheKey = 'regidex_images';

  final int _maxBytes;
  final Duration _trimDelay;
  Timer? _trimTimer;

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    return super
        .getFileStream(
          url,
          key: key,
          headers: headers,
          withProgress: withProgress,
        )
        .map((response) {
          if (response is FileInfo && response.source == FileSource.Online) {
            _scheduleTrim();
          }
          return response;
        });
  }

  /// Expulsa los archivos menos usados hasta que la caché cabe en el límite.
  Future<void> trimToSize() async {
    final repo = config.repo;
    await repo.open();
    final objects = await repo.getAllObjects();

    final entries = [
      for (final object in objects)
        CachedImageEntry(
          key: object.key,
          bytes: object.length ?? await _lengthOnDisk(object),
          touched: object.touched ?? DateTime.fromMillisecondsSinceEpoch(0),
        ),
    ];
    final evicted = keysToEvict(entries, maxBytes: _maxBytes).toSet();

    for (final object in objects) {
      if (evicted.contains(object.key)) await store.removeCachedFile(object);
    }
  }

  void _scheduleTrim() {
    _trimTimer ??= Timer(_trimDelay, () {
      _trimTimer = null;
      unawaited(trimToSize());
    });
  }

  /// Algunas descargas no traen el tamaño en la cabecera: se mide el archivo.
  Future<int> _lengthOnDisk(CacheObject object) async {
    final file = await store.fileSystem.createFile(object.relativePath);
    return await file.exists() ? file.length() : 0;
  }

  @override
  Future<void> dispose() {
    _trimTimer?.cancel();
    return super.dispose();
  }
}

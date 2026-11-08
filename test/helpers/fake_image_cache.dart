import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/images/regi_image_cache_manager.dart';

/// Caché de imágenes cuyo resultado controla la prueba; sin él, la descarga
/// queda pendiente.
class FakeImageCache extends Fake implements RegiImageCacheManager {
  FakeImageCache([this._response]);

  final Stream<FileResponse> Function()? _response;

  Stream<FileResponse> _download() =>
      _response?.call() ?? StreamController<FileResponse>().stream;

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => _download();

  @override
  Stream<FileResponse> getImageFile(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
    int? maxHeight,
    int? maxWidth,
  }) => _download();
}

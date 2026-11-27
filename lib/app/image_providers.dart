import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/images/pinned_images.dart';
import '../core/images/regi_image_cache_manager.dart';

final pinnedImagesProvider = Provider<PinnedImages>(
  (ref) => PinnedImages(
    () async =>
        Directory('${(await getApplicationSupportDirectory()).path}/pinned'),
  ),
);

/// Caché de imágenes de toda la app. Al crearse recorta lo que haya quedado
/// por encima del límite de la sesión anterior.
final imageCacheManagerProvider = Provider<RegiImageCacheManager>((ref) {
  final manager = RegiImageCacheManager(
    pinned: ref.watch(pinnedImagesProvider),
  );
  unawaited(manager.trimToSize());
  ref.onDispose(manager.dispose);
  return manager;
});

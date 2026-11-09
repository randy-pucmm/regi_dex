import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/images/regi_image_cache_manager.dart';

/// Caché de imágenes de toda la app. Al crearse recorta lo que haya quedado
/// por encima del límite de la sesión anterior.
final imageCacheManagerProvider = Provider<RegiImageCacheManager>((ref) {
  final manager = RegiImageCacheManager();
  unawaited(manager.trimToSize());
  ref.onDispose(manager.dispose);
  return manager;
});

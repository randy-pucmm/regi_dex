import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connectivity/service_status.dart';
import 'image_providers.dart';
import 'providers.dart';

/// Mantiene fijadas las imágenes de los favoritos; al volver el servicio baja
/// las pendientes.
final favoritePinsProvider = Provider<void>((ref) {
  void pin() {
    final favorites = ref.read(favoritePokemonProvider);
    if (favorites == null) return;
    final urls = {
      for (final pokemon in favorites) ...[
        ?pokemon.spriteUrl,
        ?pokemon.artworkUrl,
      ],
    };
    unawaited(
      ref
          .read(pinnedImagesProvider)
          .keep(
            urls,
            (url) => ref.read(imageCacheManagerProvider).getSingleFile(url),
          )
          // Sin carpeta de la app no hay dónde fijar; la caché sigue sirviendo.
          .catchError((_) {}),
    );
  }

  ref.listen(favoritePokemonProvider, (_, _) => pin(), fireImmediately: true);
  ref.listen(serviceStatusProvider, (previous, next) {
    final wasOnline = previous?.value?.status == ServiceStatus.online;
    if (next.value?.status == ServiceStatus.online && !wasOnline) pin();
  });
});

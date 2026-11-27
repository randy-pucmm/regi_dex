import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/image_providers.dart';
import '../../../app/providers.dart';
import '../../pokemon/presentation/catalog_page.dart' show PokemonList;

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritePokemonProvider);
    if (favorites == null) return const SizedBox.shrink();
    if (favorites.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aún no tienes favoritos. Toca el corazón de un Pokémon para '
            'guardarlo.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return PokemonList(
      pokemon: favorites,
      cacheManager: ref.watch(imageCacheManagerProvider),
    );
  }
}

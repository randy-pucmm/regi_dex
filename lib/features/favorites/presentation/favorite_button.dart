import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../ui/components/reduced_motion.dart';

class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.pokemonId, this.color});

  final int pokemonId;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite =
        ref.watch(favoriteIdsProvider).value?.contains(pokemonId) ?? false;
    return IconButton(
      tooltip: isFavorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
      color: color,
      onPressed: () {
        final favorites = ref.read(appDatabaseProvider).favoriteDao;
        isFavorite
            ? favorites.removeFavorite(pokemonId)
            : favorites.addFavorite(pokemonId);
      },
      icon: AnimatedSwitcher(
        duration: reducedMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          key: ValueKey(isFavorite),
        ),
      ),
    );
  }
}

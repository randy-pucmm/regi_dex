import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/image_providers.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../ui/components/pokemon_image.dart';
import '../../../ui/themes/regi_theme.dart';
import '../domain/evolution_chain.dart';

/// Árbol evolutivo del Pokémon: cada especie con lo que hace falta para
/// llegar a ella. Tocar una abre su detalle.
class PokemonEvolutionsSection extends ConsumerWidget {
  const PokemonEvolutionsSection({super.key, required this.pokemonId});

  final int pokemonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regi = RegiTheme.of(context);
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: regi.onShellMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          'Evoluciones',
          style: text.titleSmall?.copyWith(color: regi.onShell),
        ),
        switch (ref.watch(pokemonEvolutionsProvider(pokemonId))) {
          AsyncData(value: final chain?) when !chain.evolves => Text(
            'No evoluciona.',
            style: muted,
          ),
          AsyncData(value: final chain?) => Column(
            spacing: 8,
            children: [
              for (final (node, depth) in chain.flattened)
                _NodeTile(
                  node: node,
                  depth: depth,
                  isCurrent: node.species.id == chain.currentSpeciesId,
                ),
            ],
          ),
          AsyncData() => Text(
            'Las evoluciones se descargan con conexión.',
            style: muted,
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ],
    );
  }
}

class _NodeTile extends ConsumerWidget {
  const _NodeTile({
    required this.node,
    required this.depth,
    required this.isCurrent,
  });

  final EvolutionNode node;
  final int depth;
  final bool isCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regi = RegiTheme.of(context);
    final text = Theme.of(context).textTheme;
    final species = node.species;
    final requirement = node.requirement;

    return Padding(
      padding: EdgeInsets.only(left: depth * 20.0),
      child: Semantics(
        button: !isCurrent,
        selected: isCurrent,
        label:
            '${species.displayName}'
            '${requirement.isEmpty ? '' : ', evoluciona: $requirement'}',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isCurrent
              ? null
              : () => context.push(AppRoutes.pokemon(species.id)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCurrent ? regi.accent : regi.onShellMuted,
                width: isCurrent ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                spacing: 12,
                children: [
                  PokemonImage(
                    url: species.spriteUrl,
                    size: 56,
                    cacheManager: ref.watch(imageCacheManagerProvider),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          species.displayName,
                          style: text.titleSmall?.copyWith(color: regi.onShell),
                        ),
                        if (requirement.isNotEmpty)
                          Text(
                            requirement,
                            style: text.bodySmall?.copyWith(
                              color: regi.onShellMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

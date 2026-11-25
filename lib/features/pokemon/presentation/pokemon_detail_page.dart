import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/image_providers.dart';
import '../../../app/providers.dart';
import '../../../ui/components/pokemon_image.dart';
import '../../../ui/components/stat_bar.dart';
import '../../../ui/components/type_chip.dart';
import '../../../ui/tokens/regi_colors.dart';
import '../domain/pokemon_detail.dart';

class PokemonDetailPage extends ConsumerWidget {
  const PokemonDetailPage({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(pokemonDetailProvider(id));
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Volver',
            color: RegiInk.onShell,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        Expanded(
          child: switch (detail) {
            AsyncData(value: final value?) => _Detail(detail: value),
            AsyncData() => const _Notice(
              'Este Pokémon no está en el catálogo.',
            ),
            AsyncError() => const _Notice('No se pudo leer el Pokémon.'),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ],
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.detail});

  final PokemonDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pokemon = detail.pokemon;
    final text = Theme.of(context).textTheme;
    final name = _capitalize(pokemon.name);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Center(
          child: PokemonImage(
            url: pokemon.artworkUrl ?? pokemon.spriteUrl,
            size: 220,
            label: name,
            cacheManager: ref.watch(imageCacheManagerProvider),
            plateColor: pokemon.types.isEmpty
                ? null
                : RegiTypeColors.of(pokemon.types.first.name),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'N.º ${pokemon.id.toString().padLeft(4, '0')}',
          textAlign: TextAlign.center,
          style: text.labelMedium?.copyWith(color: RegiInk.onShellMuted),
        ),
        Text(
          name,
          textAlign: TextAlign.center,
          style: text.headlineMedium?.copyWith(color: RegiInk.onShell),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          children: [
            for (final type in pokemon.types)
              TypeChip(typeKey: type.name, label: type.nameEs ?? type.name),
          ],
        ),
        const SizedBox(height: 20),
        _Stats(stats: detail.stats),
        const SizedBox(height: 20),
        _Abilities(abilities: detail.abilities),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.stats});

  final Map<int, int> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const _Notice('Las estadísticas se descargan con conexión.');
    }
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: [
        for (final stat in RegiStat.values)
          SizedBox(
            width: 96,
            child: StatBar(stat: stat, value: stats[stat.index + 1] ?? 0),
          ),
      ],
    );
  }
}

class _Abilities extends StatelessWidget {
  const _Abilities({required this.abilities});

  final List<PokemonAbilityRef> abilities;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        for (final ability in abilities)
          Semantics(
            container: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_capitalize(ability.nameEs ?? ability.name)}'
                  '${ability.isHidden ? ' · Oculta' : ''}',
                  style: text.titleSmall?.copyWith(color: RegiInk.onShell),
                ),
                if (ability.shortEffect != null)
                  Text(
                    ability.shortEffect!,
                    style: text.bodySmall?.copyWith(
                      color: RegiInk.onShellMuted,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: RegiInk.onShellMuted),
      ),
    ),
  );
}

String _capitalize(String name) =>
    name.isEmpty ? name : '${name[0].toUpperCase()}${name.substring(1)}';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../../ui/components/hexagon_border.dart';
import '../../../ui/components/pokemon_image.dart';
import '../../../ui/components/type_chip.dart';
import '../../../ui/tokens/regi_colors.dart';
import '../domain/pokemon.dart';

class PokemonTile extends StatelessWidget {
  const PokemonTile({
    super.key,
    required this.pokemon,
    required this.cacheManager,
  });

  final Pokemon pokemon;
  final BaseCacheManager cacheManager;

  static const _depth = 18.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = _capitalize(pokemon.name);
    final types = [for (final type in pokemon.types) type.nameEs ?? type.name];
    final kinds = types.isEmpty
        ? ''
        : ', ${types.length == 1 ? 'tipo' : 'tipos'} ${types.join(' y ')}';

    return Semantics(
      label: '$name, número ${pokemon.id}$kinds',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const ShapeDecoration(
          color: RegiInk.shell,
          shape: HexagonBorder(
            pointAxis: Axis.horizontal,
            depth: _depth,
            side: BorderSide(color: RegiInk.onShellMuted, width: 1.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_depth + 4, 8, _depth + 4, 8),
          child: Row(
            spacing: 12,
            children: [
              PokemonImage(
                url: pokemon.spriteUrl,
                size: 56,
                cacheManager: cacheManager,
                plateColor: pokemon.types.isEmpty
                    ? null
                    : RegiTypeColors.of(pokemon.types.first.name),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 8,
                      children: [
                        Text(
                          name,
                          style: text.titleMedium?.copyWith(
                            color: RegiInk.onShell,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'N.º ${pokemon.id.toString().padLeft(4, '0')}',
                          style: text.labelSmall?.copyWith(
                            color: RegiInk.onShellMuted,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final type in pokemon.types)
                          TypeChip(
                            typeKey: type.name,
                            label: type.nameEs ?? type.name,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _capitalize(String name) =>
      name.isEmpty ? name : '${name[0].toUpperCase()}${name.substring(1)}';
}

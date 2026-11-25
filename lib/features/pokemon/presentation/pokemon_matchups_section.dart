import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../ui/components/type_chip.dart';
import '../../../ui/themes/regi_theme.dart';
import '../domain/pokemon.dart';

/// Daño que recibe el Pokémon de cada tipo, agrupado por multiplicador.
class PokemonMatchupsSection extends ConsumerWidget {
  const PokemonMatchupsSection({super.key, required this.types});

  final List<PokemonTypeRef> types;

  static final _labels = {
    4.0: '×4',
    2.0: '×2',
    0.5: '×½',
    0.25: '×¼',
    0.0: '×0',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regi = RegiTheme.of(context);
    final text = Theme.of(context).textTheme;
    final chart = ref.watch(typeChartProvider).value;
    final groups = chart?.matchups([for (final t in types) t.id]) ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          'Daño recibido',
          style: text.titleSmall?.copyWith(color: regi.onShell),
        ),
        if (chart == null || chart.isEmpty)
          Text(
            'Las debilidades se calculan al descargar el catálogo.',
            style: text.bodySmall?.copyWith(color: regi.onShellMuted),
          )
        else
          for (final MapEntry(:key, :value) in groups.entries)
            Semantics(
              container: true,
              label:
                  'Daño ${_labels[key] ?? '×$key'} de '
                  '${value.map((t) => t.nameEs ?? t.name).join(', ')}',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      _labels[key] ?? '×$key',
                      style: text.titleSmall?.copyWith(color: regi.onShell),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final type in value)
                          TypeChip(
                            typeKey: type.name,
                            label: type.nameEs ?? type.name,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/components/hex_choice.dart';
import '../../../ui/components/regi_dialog.dart';
import '../../../ui/components/regi_filter_chip.dart';
import '../../../ui/components/type_chip.dart';
import '../../../ui/tokens/regi_colors.dart';
import '../domain/catalog_filters.dart';
import '../domain/pokemon_query.dart';
import 'catalog_search.dart';

/// Abre el panel de filtros y orden bajo la cabecera de la carcasa.
Future<void> showCatalogFilters(BuildContext context) => showDialog<void>(
  context: context,
  barrierColor: Colors.transparent,
  builder: (context) => const CatalogFilterDialog(),
);

/// Filtros por tipo, generación, grupo huevo y habilidad, y orden (RF-FIL-01 a
/// RF-FIL-06). Los cambios se aplican y se guardan al instante: se ve cómo
/// cambia la lista detrás. Dentro de una categoría se pueden elegir varios
/// valores (basta uno); las categorías se combinan.
class CatalogFilterDialog extends ConsumerStatefulWidget {
  const CatalogFilterDialog({super.key});

  @override
  ConsumerState<CatalogFilterDialog> createState() =>
      _CatalogFilterDialogState();
}

class _CatalogFilterDialogState extends ConsumerState<CatalogFilterDialog> {
  /// Alto de la cabecera de la carcasa, sin contar la barra de estado.
  static const _headerHeight = 136.0;

  /// Cuántas habilidades se muestran a la vez al buscar.
  static const _abilityLimit = 30;

  final _abilitySearch = TextEditingController();

  @override
  void dispose() {
    _abilitySearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(catalogQueryProvider);
    final controller = ref.read(catalogQueryProvider.notifier);
    final options =
        ref.watch(filterOptionsProvider).value ?? FilterOptions.empty;
    final top = MediaQuery.paddingOf(context).top + _headerHeight;

    return RegiDialog(
      title: 'Filtros y orden',
      alignment: Alignment.topCenter,
      insetPadding: EdgeInsets.fromLTRB(20, top, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel('Ordenar por'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (sort, label) in const [
                (PokemonSort.number, 'Número'),
                (PokemonSort.name, 'Nombre'),
                (PokemonSort.baseTotal, 'Total base'),
              ])
                SizedBox(
                  width: 150,
                  child: HexChoice(
                    label: label,
                    selected: query.sort == sort,
                    onPressed: () => controller.setSort(sort),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: HexChoice(
                  label: 'Ascendente',
                  filled: true,
                  selected: !query.descending,
                  onPressed: () => controller.setDescending(false),
                ),
              ),
              Expanded(
                child: HexChoice(
                  label: 'Descendente',
                  filled: true,
                  selected: query.descending,
                  onPressed: () => controller.setDescending(true),
                ),
              ),
            ],
          ),
          if (options.isEmpty) ...[
            const SizedBox(height: 22),
            Text(
              'Los filtros se activan al descargar el catálogo por primera vez.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: RegiInk.onShellMuted),
            ),
          ] else ...[
            const SizedBox(height: 22),
            const _SectionLabel('Tipo'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final type in options.types)
                  TypeChip(
                    typeKey: type.key,
                    label: type.label,
                    selected: query.types.contains(type.id),
                    onTap: () =>
                        controller.toggle(FilterCategory.types, type.id),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionLabel('Generación'),
            const SizedBox(height: 10),
            _ChipWrap(
              options: options.generations,
              selected: query.generations,
              onToggle: (id) =>
                  controller.toggle(FilterCategory.generations, id),
            ),
            const SizedBox(height: 22),
            const _SectionLabel('Grupo huevo'),
            const SizedBox(height: 10),
            _ChipWrap(
              options: options.eggGroups,
              selected: query.eggGroups,
              onToggle: (id) => controller.toggle(FilterCategory.eggGroups, id),
            ),
            const SizedBox(height: 22),
            const _SectionLabel('Habilidad'),
            const SizedBox(height: 10),
            _AbilityPicker(
              options: options.abilities,
              selected: query.abilities,
              search: _abilitySearch,
              limit: _abilityLimit,
              onToggle: (id) => controller.toggle(FilterCategory.abilities, id),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: HexChoice(
                  label: 'Limpiar filtros',
                  onPressed: query.hasFilters ? controller.clearFilters : () {},
                ),
              ),
              Expanded(
                child: HexChoice(
                  label: 'Listo',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final List<FilterOption> options;
  final Set<int> selected;
  final void Function(int id) onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          RegiFilterChip(
            label: option.label,
            selected: selected.contains(option.id),
            onTap: () => onToggle(option.id),
          ),
      ],
    );
  }
}

/// Habilidades: son demasiadas para listarlas todas, así que se muestran las
/// elegidas y las que coinciden con lo que se escribe.
class _AbilityPicker extends StatefulWidget {
  const _AbilityPicker({
    required this.options,
    required this.selected,
    required this.search,
    required this.limit,
    required this.onToggle,
  });

  final List<FilterOption> options;
  final Set<int> selected;
  final TextEditingController search;
  final int limit;
  final void Function(int id) onToggle;

  @override
  State<_AbilityPicker> createState() => _AbilityPickerState();
}

class _AbilityPickerState extends State<_AbilityPicker> {
  @override
  Widget build(BuildContext context) {
    final regi = RegiInk.onShell;
    final text = widget.search.text.trim().toLowerCase();
    final chosen = [
      for (final option in widget.options)
        if (widget.selected.contains(option.id)) option,
    ];
    final matches = text.isEmpty
        ? const <FilterOption>[]
        : [
            for (final option in widget.options)
              if (!widget.selected.contains(option.id) &&
                  option.label.toLowerCase().contains(text))
                option,
          ];
    final shown = matches.take(widget.limit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        TextField(
          controller: widget.search,
          onChanged: (_) => setState(() {}),
          autocorrect: false,
          enableSuggestions: false,
          style: TextStyle(color: regi),
          cursorColor: regi,
          decoration: InputDecoration(
            labelText: 'Buscar habilidad',
            labelStyle: const TextStyle(color: RegiInk.onShellMuted),
            prefixIcon: const Icon(Icons.search, color: RegiInk.onShell),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: RegiInk.onShellMuted),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: RegiInk.onShell, width: 2),
            ),
          ),
        ),
        if (chosen.isNotEmpty || shown.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in [...chosen, ...shown])
                RegiFilterChip(
                  label: option.label,
                  selected: widget.selected.contains(option.id),
                  onTap: () => widget.onToggle(option.id),
                ),
            ],
          ),
        if (text.isNotEmpty && matches.isEmpty)
          Text(
            'Ninguna habilidad coincide.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: RegiInk.onShellMuted),
          ),
        if (matches.length > widget.limit)
          Text(
            'Hay ${matches.length} coincidencias; escribe más para acotar.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: RegiInk.onShellMuted),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: RegiInk.onShellMuted, letterSpacing: 2),
      ),
    );
  }
}

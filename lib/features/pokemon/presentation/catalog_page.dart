import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/image_providers.dart';
import '../../../app/providers.dart';
import '../../../ui/components/hub_buttons.dart';
import '../../../ui/themes/regi_theme.dart';
import '../../../ui/tokens/regi_colors.dart';
import '../domain/catalog_filters.dart';
import '../domain/pokemon.dart';
import '../domain/pokemon_query.dart';
import 'catalog_filter_dialog.dart';
import 'catalog_search.dart';
import 'catalog_search_field.dart';
import 'catalog_state.dart';
import 'pokemon_tile.dart';

class CatalogPage extends ConsumerWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void retry() => ref.read(refreshCatalogProvider)().ignore();

    final state = ref.watch(catalogStateProvider);
    final query = ref.watch(catalogQueryProvider);
    // La barra de búsqueda y filtros se queda mientras haya algo activo, aunque
    // la lista se esté recargando, para no perder lo que se está escribiendo.
    final showTools =
        state is CatalogLoaded || state is CatalogNoResults || !query.isDefault;
    final availability = ref.watch(catalogAvailabilityProvider).value;

    return Column(
      children: [
        if (showTools) const _Toolbar(key: ValueKey('catalog-toolbar')),
        if (showTools && query.hasFilters) _ActiveFilters(query: query),
        if (showTools && (availability?.isPartial ?? false))
          _AvailabilityNotice(availability: availability!),
        Expanded(
          child: switch (state) {
            CatalogLoaded(:final pokemon) => _PokemonList(
              pokemon: pokemon,
              cacheManager: ref.watch(imageCacheManagerProvider),
            ),
            CatalogNoResults() => _noResults(state, ref),
            CatalogLoading() => const _Message(
              title: 'Descargando el catálogo…',
              body: 'La primera vez tarda unos segundos.',
            ),
            CatalogEmpty() => _Message(
              title: 'Aún no hay catálogo',
              body:
                  'Conéctate a Internet una vez para descargarlo. '
                  'Después funciona sin conexión.',
              actionLabel: 'Reintentar',
              onAction: retry,
            ),
            CatalogError() => _Message(
              title: 'No se pudo descargar el catálogo',
              body:
                  'PokéAPI no respondió. La app lo reintenta sola; también '
                  'puedes hacerlo ahora.',
              actionLabel: 'Reintentar',
              onAction: retry,
            ),
          },
        ),
      ],
    );
  }

  /// Mensaje de «sin resultados» según haya búsqueda, filtros o ambos.
  Widget _noResults(CatalogNoResults state, WidgetRef ref) {
    final hasSearch = state.search.isNotEmpty;
    if (state.searching) {
      return _Message(
        title: hasSearch ? 'Buscando…' : 'Descargando el catálogo…',
        body: hasSearch
            ? 'Consultando PokéAPI por «${state.search}».'
            : 'Los resultados aparecen a medida que llegan.',
      );
    }
    final String body;
    if (state.filtered) {
      body = hasSearch
          ? 'Ningún Pokémon con «${state.search}» cumple los filtros elegidos.'
          : 'Ningún Pokémon cumple los filtros elegidos.';
    } else if (state.offline) {
      body =
          'No hay ningún Pokémon descargado con «${state.search}». Sin '
          'conexión solo se busca en lo ya descargado.';
    } else {
      body =
          'No hay ningún Pokémon con «${state.search}». Prueba con otro '
          'nombre o con su número nacional.';
    }
    return _Message(
      title: 'Sin resultados',
      body: body,
      actionLabel: state.filtered ? 'Limpiar filtros' : null,
      onAction: state.filtered
          ? ref.read(catalogQueryProvider.notifier).clearFilters
          : null,
    );
  }
}

/// Campo de búsqueda y botón de filtros y orden.
class _Toolbar extends ConsumerWidget {
  const _Toolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regi = RegiTheme.of(context);
    final count = ref.watch(
      catalogQueryProvider.select((q) => q.activeFilterCount),
    );
    final ordered = ref.watch(
      catalogQueryProvider.select(
        (q) => q.sort != PokemonSort.number || q.descending,
      ),
    );
    final active = count + (ordered ? 1 : 0);
    final label = switch (active) {
      0 => 'Filtros y orden',
      1 => 'Filtros y orden, 1 activo',
      _ => 'Filtros y orden, $active activos',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Row(
            spacing: 8,
            children: [
              const Expanded(
                child: CatalogSearchField(key: ValueKey('catalog-search')),
              ),
              Semantics(
                button: true,
                label: label,
                excludeSemantics: true,
                onTap: () => showCatalogFilters(context),
                child: IconButton(
                  tooltip: 'Filtros y orden',
                  constraints: const BoxConstraints(
                    minWidth: 56,
                    minHeight: 56,
                  ),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: regi.frame, width: 1.5),
                    ),
                  ),
                  onPressed: () => showCatalogFilters(context),
                  icon: Badge(
                    isLabelVisible: active > 0,
                    label: Text('$active'),
                    child: Icon(Icons.tune, color: regi.onScreen),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un chip por cada filtro activo, con su ✕ para quitarlo, y «Limpiar filtros».
class _ActiveFilters extends ConsumerWidget {
  const _ActiveFilters({required this.query});

  final PokemonQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options =
        ref.watch(filterOptionsProvider).value ?? FilterOptions.empty;
    final controller = ref.read(catalogQueryProvider.notifier);
    final entries = <({FilterCategory category, FilterOption option})>[
      for (final (category, ids, all) in [
        (FilterCategory.types, query.types, options.types),
        (FilterCategory.generations, query.generations, options.generations),
        (FilterCategory.eggGroups, query.eggGroups, options.eggGroups),
        (FilterCategory.abilities, query.abilities, options.abilities),
      ])
        for (final option in all)
          if (ids.contains(option.id)) (category: category, option: option),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final entry in entries)
                InputChip(
                  label: Text(entry.option.label),
                  onDeleted: () =>
                      controller.toggle(entry.category, entry.option.id),
                  deleteButtonTooltipMessage: 'Quitar ${entry.option.label}',
                ),
              TextButton(
                onPressed: controller.clearFilters,
                child: const Text('Limpiar filtros'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «N de 1025 disponibles sin conexión» cuando el catálogo local es parcial.
class _AvailabilityNotice extends StatelessWidget {
  const _AvailabilityNotice({required this.availability});

  final CatalogAvailability availability;

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    final text =
        '${availability.available} de ${availability.total} disponibles '
        'sin conexión';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          label: text,
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Icon(Icons.cloud_off_outlined, size: 18, color: regi.onScreen),
              Flexible(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: regi.onScreen),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PokemonList extends StatelessWidget {
  const _PokemonList({required this.pokemon, required this.cacheManager});

  final List<Pokemon> pokemon;
  final BaseCacheManager cacheManager;

  static const _tileWidth = 420.0;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / _tileWidth).floor().clamp(1, 3);
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: (pokemon.length / columns).ceil(),
          itemBuilder: (context, row) => Padding(
            padding: const EdgeInsets.only(bottom: _gap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: _gap,
              children: [
                for (var i = row * columns; i < (row + 1) * columns; i++)
                  Expanded(
                    child: i < pokemon.length
                        ? PokemonTile(
                            pokemon: pokemon[i],
                            cacheManager: cacheManager,
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;

  /// Botón opcional bajo el mensaje; solo se muestra con texto y acción.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: text.titleLarge,
                ),
              ),
              Text(body, textAlign: TextAlign.center, style: text.bodyMedium),
              if (actionLabel != null && onAction != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: 200,
                    child: HexButton(
                      label: actionLabel!,
                      color: RegiInk.onShell,
                      onPressed: onAction,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

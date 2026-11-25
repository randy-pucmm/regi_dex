// Panel de filtros y orden, filtros activos y aviso de catálogo parcial (RD-27).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/image_providers.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/core/connectivity/service_status.dart';
import 'package:regi_dex/core/sync/sync_status.dart';
import 'package:regi_dex/features/pokemon/domain/catalog_filters.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_query.dart';
import 'package:regi_dex/features/pokemon/presentation/catalog_filter_dialog.dart';
import 'package:regi_dex/features/pokemon/presentation/catalog_page.dart';
import 'package:regi_dex/features/pokemon/presentation/pokemon_tile.dart';
import 'package:regi_dex/ui/components/type_chip.dart';
import 'package:regi_dex/ui/themes/regi_themes.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

import '../../../helpers/fake_image_cache.dart';
import '../../../helpers/ui_test_helpers.dart';
import '../fake_pokemon_repository.dart';

const _options = FilterOptions(
  types: [
    FilterOption(id: 5, key: 'ground', label: 'Tierra'),
    FilterOption(id: 6, key: 'rock', label: 'Roca'),
    FilterOption(id: 10, key: 'fire', label: 'Fuego'),
  ],
  generations: [
    FilterOption(id: 1, key: 'generation-i', label: 'Gen. I · Kanto'),
    FilterOption(id: 3, key: 'generation-iii', label: 'Gen. III · Hoenn'),
  ],
  eggGroups: [
    FilterOption(id: 3, key: 'mineral', label: 'Mineral'),
    FilterOption(id: 5, key: 'undiscovered', label: 'Desconocido'),
  ],
  abilities: [
    FilterOption(id: 5, key: 'sturdy', label: 'Robustez'),
    FilterOption(id: 9, key: 'static', label: 'Elec. estática'),
    FilterOption(id: 69, key: 'rock-head', label: 'Cabeza roca'),
  ],
);

/// Pokémon del catálogo falso, con lo mínimo para filtrar en la prueba.
const _geodude = Pokemon(
  id: 74,
  name: 'geodude',
  baseStatTotal: 300,
  types: [
    PokemonTypeRef(id: 6, name: 'rock'),
    PokemonTypeRef(id: 5, name: 'ground'),
  ],
);
const _pikachu = Pokemon(
  id: 25,
  name: 'pikachu',
  baseStatTotal: 320,
  types: [PokemonTypeRef(id: 13, name: 'electric')],
);
const _regirock = Pokemon(
  id: 377,
  name: 'regirock',
  baseStatTotal: 580,
  types: [PokemonTypeRef(id: 6, name: 'rock')],
);

class _Repo extends FakePokemonRepository {
  /// Aplica la consulta como lo haría la base: solo el tipo y el orden.
  @override
  Stream<List<Pokemon>> watchPokemon(PokemonQuery query) {
    queries.add(query);
    var list = [_pikachu, _geodude, _regirock];
    if (query.types.isNotEmpty) {
      list = [
        for (final p in list)
          if (p.types.any((t) => query.types.contains(t.id))) p,
      ];
    }
    if (query.sort == PokemonSort.baseTotal) {
      list.sort((a, b) => a.baseStatTotal.compareTo(b.baseStatTotal));
    }
    if (query.descending) list = list.reversed.toList();
    return Stream.value(list);
  }
}

Future<_Repo> _open(
  WidgetTester tester, {
  PokemonQuery stored = const PokemonQuery(),
  CatalogAvailability availability = const CatalogAvailability(available: 3),
  FilterOptions options = _options,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  useScreen(tester, size, textScale: textScale);
  final repo = _Repo()
    ..storedQuery = stored
    ..filterOptions = options
    ..availability = availability;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pokemonRepositoryProvider.overrideWithValue(repo),
        syncStatusProvider.overrideWith(
          (ref) => Stream.value(SyncStatus.inactiva),
        ),
        serviceStatusProvider.overrideWith(
          (ref) => Stream.value(
            const ConnectivitySnapshot(status: ServiceStatus.offline),
          ),
        ),
        imageCacheManagerProvider.overrideWithValue(FakeImageCache()),
      ],
      child: MaterialApp(
        theme: RegiThemes.build(RegiVariant.regirock, Brightness.light),
        home: const Scaffold(body: CatalogPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _openFilters(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Filtros y orden'));
  await tester.pumpAndSettle();
}

/// Cierra el panel con «Listo», que puede quedar más abajo del área visible.
Future<void> _closeFilters(WidgetTester tester) async {
  await tester.ensureVisible(find.text('LISTO'));
  await tester.tap(find.text('LISTO'));
  await tester.pumpAndSettle();
}

/// Lo que hay dentro del panel, sin contar la lista de detrás.
Finder _inPanel(Finder finder) =>
    find.descendant(of: find.byType(CatalogFilterDialog), matching: finder);

void main() {
  group('botón de filtros', () {
    testWidgets('aparece junto al buscador, sin insignia al inicio', (
      tester,
    ) async {
      await _open(tester);

      expect(find.byTooltip('Filtros y orden'), findsOneWidget);
      expect(find.byType(Badge), findsOneWidget);
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    });

    testWidgets('la insignia cuenta las categorías con filtro y el orden', (
      tester,
    ) async {
      await _open(
        tester,
        stored: const PokemonQuery(
          types: {6},
          eggGroups: {3},
          sort: PokemonSort.name,
        ),
      );

      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isTrue);
      expect((badge.label! as Text).data, '3');
    });

    testWidgets('abre el panel de filtros y orden', (tester) async {
      await _open(tester);

      await _openFilters(tester);

      expect(find.text('FILTROS Y ORDEN'), findsOneWidget);
      expect(find.text('ORDENAR POR'), findsOneWidget);
      expect(find.text('TIPO'), findsOneWidget);
      expect(find.text('GENERACIÓN'), findsOneWidget);
      expect(find.text('GRUPO HUEVO'), findsOneWidget);
      expect(find.text('HABILIDAD'), findsOneWidget);
    });

    testWidgets('«Listo» cierra el panel', (tester) async {
      await _open(tester);
      await _openFilters(tester);

      await _closeFilters(tester);

      expect(find.byType(CatalogFilterDialog), findsNothing);
    });
  });

  group('panel: tipo, generación y grupo huevo', () {
    testWidgets('elegir un tipo filtra la lista de detrás y se guarda', (
      tester,
    ) async {
      final repo = await _open(tester);
      expect(find.byType(PokemonTile), findsNWidgets(3));

      await _openFilters(tester);
      await tester.tap(find.widgetWithText(TypeChip, 'ROCA'));
      await tester.pumpAndSettle();

      expect(repo.queries.last.types, {6});
      expect(repo.savedQueries.last.types, {6});
      await _closeFilters(tester);
      expect(find.byType(PokemonTile), findsNWidgets(2));
    });

    testWidgets('el tipo elegido lleva «✓» y volver a tocarlo lo quita', (
      tester,
    ) async {
      final repo = await _open(tester);
      await _openFilters(tester);
      final rock = find.widgetWithText(TypeChip, 'ROCA');

      await tester.tap(rock);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: rock, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );

      await tester.tap(rock);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: rock, matching: find.byIcon(Icons.check)),
        findsNothing,
      );
      expect(repo.queries.last.types, isEmpty);
    });

    testWidgets('varios tipos a la vez y generación y grupo huevo', (
      tester,
    ) async {
      final repo = await _open(tester);
      await _openFilters(tester);

      await tester.tap(find.widgetWithText(TypeChip, 'ROCA'));
      await tester.tap(find.widgetWithText(TypeChip, 'TIERRA'));
      await tester.tap(find.text('Gen. I · Kanto'));
      await tester.ensureVisible(find.text('Mineral'));
      await tester.tap(find.text('Mineral'));
      await tester.pumpAndSettle();

      final query = repo.queries.last;
      expect(query.types, {5, 6});
      expect(query.generations, {1});
      expect(query.eggGroups, {3});
    });

    testWidgets('sin referencia descargada explica que los filtros esperan', (
      tester,
    ) async {
      await _open(tester, options: FilterOptions.empty);
      await _openFilters(tester);

      expect(find.textContaining('se activan al descargar'), findsOneWidget);
      expect(_inPanel(find.byType(TypeChip)), findsNothing);
      // El orden sí funciona sin referencia.
      expect(find.text('NOMBRE'), findsOneWidget);
    });
  });

  group('panel: orden', () {
    testWidgets('por defecto: número ascendente', (tester) async {
      await _open(tester);
      await _openFilters(tester);

      expect(find.text('NÚMERO'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(InkWell, 'NÚMERO'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.widgetWithText(InkWell, 'ASCENDENTE'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
    });

    testWidgets('elegir total base y descendente reordena la lista', (
      tester,
    ) async {
      final repo = await _open(tester);

      await _openFilters(tester);
      await tester.tap(find.text('TOTAL BASE'));
      await tester.tap(find.text('DESCENDENTE'));
      await tester.pumpAndSettle();

      expect(repo.queries.last.sort, PokemonSort.baseTotal);
      expect(repo.queries.last.descending, isTrue);
      await _closeFilters(tester);
      final first = tester.widget<PokemonTile>(find.byType(PokemonTile).first);
      expect(first.pokemon.name, 'regirock');
    });
  });

  group('panel: habilidad', () {
    testWidgets('no lista las ~300 habilidades: pide escribir', (tester) async {
      await _open(tester);
      await _openFilters(tester);
      await tester.ensureVisible(find.text('Buscar habilidad'));

      expect(find.text('Buscar habilidad'), findsOneWidget);
      expect(find.text('Robustez'), findsNothing);
      expect(find.text('Cabeza roca'), findsNothing);
    });

    testWidgets('escribir muestra las coincidencias y se pueden elegir', (
      tester,
    ) async {
      final repo = await _open(tester);
      await _openFilters(tester);
      final field = find.widgetWithText(TextField, 'Buscar habilidad');
      await tester.ensureVisible(field);

      await tester.enterText(field, 'roca');
      await tester.pumpAndSettle();
      expect(find.text('Cabeza roca'), findsOneWidget);
      expect(find.text('Robustez'), findsNothing);

      await tester.tap(find.text('Cabeza roca'));
      await tester.pumpAndSettle();
      expect(repo.queries.last.abilities, {69});
    });

    testWidgets('las elegidas siguen visibles al cambiar el texto', (
      tester,
    ) async {
      await _open(tester, stored: const PokemonQuery(abilities: {5}));
      await _openFilters(tester);
      final field = find.widgetWithText(TextField, 'Buscar habilidad');
      await tester.ensureVisible(field);

      expect(_inPanel(find.text('Robustez')), findsOneWidget);
      await tester.enterText(field, 'zzz');
      await tester.pumpAndSettle();

      expect(_inPanel(find.text('Robustez')), findsOneWidget);
      expect(find.text('Ninguna habilidad coincide.'), findsOneWidget);
    });
  });

  group('filtros activos sobre la lista', () {
    testWidgets('un chip por valor con su ✕ y «Limpiar filtros»', (
      tester,
    ) async {
      await _open(
        tester,
        stored: const PokemonQuery(types: {6}, eggGroups: {3}),
      );

      expect(find.widgetWithText(InputChip, 'Roca'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Mineral'), findsOneWidget);
      expect(find.text('Limpiar filtros'), findsOneWidget);
    });

    testWidgets('sin filtros no hay fila de chips', (tester) async {
      await _open(tester);

      expect(find.byType(InputChip), findsNothing);
      expect(find.text('Limpiar filtros'), findsNothing);
    });

    testWidgets('la ✕ de un chip quita solo ese valor', (tester) async {
      final repo = await _open(
        tester,
        stored: const PokemonQuery(types: {6}, eggGroups: {3}),
      );

      await tester.tap(find.byTooltip('Quitar Roca'));
      await tester.pumpAndSettle();

      expect(repo.queries.last.types, isEmpty);
      expect(repo.queries.last.eggGroups, {3});
      expect(find.widgetWithText(InputChip, 'Roca'), findsNothing);
    });

    testWidgets('«Limpiar filtros» los quita todos y conserva el orden', (
      tester,
    ) async {
      final repo = await _open(
        tester,
        stored: const PokemonQuery(
          types: {6},
          eggGroups: {3},
          sort: PokemonSort.name,
        ),
      );

      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();

      expect(repo.queries.last, const PokemonQuery(sort: PokemonSort.name));
      expect(find.byType(InputChip), findsNothing);
    });
  });

  group('persistencia entre sesiones (RF-FIL-04)', () {
    testWidgets('arranca con los filtros, el orden y la búsqueda guardados', (
      tester,
    ) async {
      final repo = await _open(
        tester,
        stored: const PokemonQuery(
          search: 'reg',
          types: {6},
          sort: PokemonSort.baseTotal,
          descending: true,
        ),
      );

      expect(
        repo.queries.last,
        const PokemonQuery(
          search: 'reg',
          types: {6},
          sort: PokemonSort.baseTotal,
          descending: true,
        ),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'reg',
      );
      expect(find.widgetWithText(InputChip, 'Roca'), findsOneWidget);
    });

    testWidgets('la lista no se pide antes de leer lo guardado', (
      tester,
    ) async {
      final repo = await _open(tester, stored: const PokemonQuery(types: {6}));

      expect(repo.queries.first.types, {6});
    });
  });

  group('sin resultados con filtros', () {
    testWidgets('lo dice y ofrece limpiar los filtros', (tester) async {
      final repo = await _open(tester, stored: const PokemonQuery(types: {10}));
      expect(repo.queries.last.types, {10});

      // Fuego no coincide con nada del catálogo falso, que solo filtra tipos.
      expect(find.text('Sin resultados'), findsOneWidget);
      expect(
        find.text('Ningún Pokémon cumple los filtros elegidos.'),
        findsOneWidget,
      );
      expect(find.byType(PokemonTile), findsNothing);

      await tester.tap(find.text('LIMPIAR FILTROS'));
      await tester.pumpAndSettle();

      expect(find.byType(PokemonTile), findsNWidgets(3));
    });
  });

  group('aviso de catálogo parcial (RF-FIL-05)', () {
    testWidgets('dice «N de T disponibles sin conexión»', (tester) async {
      await _open(
        tester,
        availability: const CatalogAvailability(available: 312, total: 1025),
      );

      expect(find.text('312 de 1025 disponibles sin conexión'), findsOneWidget);
    });

    testWidgets('con el catálogo completo no aparece', (tester) async {
      await _open(
        tester,
        availability: const CatalogAvailability(available: 1025, total: 1025),
      );

      expect(find.textContaining('disponibles sin conexión'), findsNothing);
    });

    testWidgets('con el total desconocido no aparece', (tester) async {
      await _open(
        tester,
        availability: const CatalogAvailability(available: 312),
      );

      expect(find.textContaining('disponibles sin conexión'), findsNothing);
    });

    testWidgets('se queda con filtros y búsquedas activos', (tester) async {
      await _open(
        tester,
        stored: const PokemonQuery(types: {10}),
        availability: const CatalogAvailability(available: 3, total: 1025),
      );

      expect(find.text('3 de 1025 disponibles sin conexión'), findsOneWidget);
    });

    testWidgets('se anuncia completo a los lectores de pantalla', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _open(
        tester,
        availability: const CatalogAvailability(available: 312, total: 1025),
      );

      expect(
        find.bySemanticsLabel('312 de 1025 disponibles sin conexión'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('tamaño y accesibilidad', () {
    testWidgets('el panel cabe en 320×568 con el texto al 200 %', (
      tester,
    ) async {
      await _open(
        tester,
        size: const Size(320, 568),
        textScale: 2,
        availability: const CatalogAvailability(available: 3, total: 1025),
        stored: const PokemonQuery(types: {6}, eggGroups: {3}),
      );
      expect(tester.takeException(), isNull);

      await _openFilters(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('el botón de filtros mide al menos 48 dp', (tester) async {
      await _open(tester);

      final size = tester.getSize(find.byTooltip('Filtros y orden'));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('el botón de filtros se anuncia con cuántos hay activos', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _open(
        tester,
        stored: const PokemonQuery(types: {6}, eggGroups: {3}),
      );

      expect(
        find.bySemanticsLabel('Filtros y orden, 2 activos'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}

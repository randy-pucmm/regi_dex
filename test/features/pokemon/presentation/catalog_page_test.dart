import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/image_providers.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/core/connectivity/service_status.dart';
import 'package:regi_dex/core/sync/sync_status.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_query.dart';
import 'package:regi_dex/features/pokemon/presentation/catalog_page.dart';
import 'package:regi_dex/features/pokemon/presentation/pokemon_tile.dart';
import 'package:regi_dex/ui/themes/regi_themes.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

import '../../../helpers/fake_image_cache.dart';
import '../../../helpers/ui_test_helpers.dart';
import '../fake_pokemon_repository.dart';

class _Repo extends FakePokemonRepository {
  _Repo(this._pokemon, {this.onWatch});

  final Stream<List<Pokemon>> _pokemon;

  /// Si se da, decide qué devuelve cada consulta en lugar de [_pokemon].
  final Stream<List<Pokemon>> Function(PokemonQuery query)? onWatch;

  /// Si no es null, `searchRemote` espera a que se complete.
  Completer<int>? searchGate;

  @override
  Stream<List<Pokemon>> watchPokemon(PokemonQuery query) {
    queries.add(query);
    return onWatch?.call(query) ?? _pokemon;
  }

  @override
  Future<int> searchRemote(String search) async {
    remoteSearches.add(search);
    return searchGate == null ? 0 : searchGate!.future;
  }
}

List<Pokemon> _pokedex(int count) => [
  for (var id = 1; id <= count; id++)
    Pokemon(id: id, name: 'pokemon$id', baseStatTotal: 300, types: const []),
];

Future<_Repo> _open(
  WidgetTester tester, {
  Stream<List<Pokemon>>? pokemon,
  SyncStatus sync = SyncStatus.inactiva,
  ServiceStatus service = ServiceStatus.online,
  Stream<List<Pokemon>> Function(PokemonQuery query)? onWatch,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  useScreen(tester, size, textScale: textScale);
  final repo = _Repo(pokemon ?? Stream.value(const []), onWatch: onWatch);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pokemonRepositoryProvider.overrideWithValue(repo),
        syncStatusProvider.overrideWith((ref) => Stream.value(sync)),
        serviceStatusProvider.overrideWith(
          (ref) => Stream.value(ConnectivitySnapshot(status: service)),
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

void main() {
  group('con catálogo', () {
    testWidgets('muestra cada Pokémon en su tarjeta', (tester) async {
      await _open(tester, pokemon: Stream.value(_pokedex(3)));

      expect(find.byType(PokemonTile), findsNWidgets(3));
      expect(find.text('Pokemon2'), findsOneWidget);
    });

    testWidgets('es una lista virtualizada: solo construye lo visible', (
      tester,
    ) async {
      await _open(tester, pokemon: Stream.value(_pokedex(1025)));

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(PokemonTile).evaluate().length, lessThan(20));

      await tester.drag(find.byType(ListView), const Offset(0, -200000));
      await tester.pumpAndSettle();

      expect(find.text('Pokemon1025'), findsOneWidget);
      expect(find.text('Pokemon1'), findsNothing);
    });

    testWidgets('crece a medida que llegan los lotes de la sync', (
      tester,
    ) async {
      final batches = StreamController<List<Pokemon>>();
      addTearDown(() => unawaited(batches.close()));
      await _open(
        tester,
        pokemon: batches.stream,
        sync: SyncStatus.sincronizando,
      );
      expect(find.text('Descargando el catálogo…'), findsOneWidget);

      batches.add(_pokedex(2));
      await tester.pumpAndSettle();
      expect(find.byType(PokemonTile), findsNWidgets(2));

      batches.add(_pokedex(5));
      await tester.pumpAndSettle();
      expect(find.byType(PokemonTile), findsNWidgets(5));
    });

    testWidgets('en teléfono va una columna', (tester) async {
      await _open(tester, pokemon: Stream.value(_pokedex(6)));

      final first = tester.getTopLeft(find.byType(PokemonTile).at(0));
      final second = tester.getTopLeft(find.byType(PokemonTile).at(1));
      expect(second.dx, first.dx);
      expect(second.dy, greaterThan(first.dy));
    });

    testWidgets('en tablet van varias columnas', (tester) async {
      await _open(
        tester,
        pokemon: Stream.value(_pokedex(6)),
        size: const Size(1000, 800),
      );

      final first = tester.getTopLeft(find.byType(PokemonTile).at(0));
      final second = tester.getTopLeft(find.byType(PokemonTile).at(1));
      expect(second.dy, first.dy);
      expect(second.dx, greaterThan(first.dx));
    });

    testWidgets('no desborda en 320×568 con el texto al 200 %', (tester) async {
      await _open(
        tester,
        pokemon: Stream.value(_pokedex(3)),
        size: const Size(320, 568),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('sin catálogo', () {
    testWidgets('descargando avisa de que tarda unos segundos', (tester) async {
      await _open(tester, sync: SyncStatus.sincronizando);

      expect(find.text('Descargando el catálogo…'), findsOneWidget);
      expect(find.text('REINTENTAR'), findsNothing);
    });

    testWidgets('sin red pide conectarse una vez y deja reintentar', (
      tester,
    ) async {
      final repo = await _open(tester, service: ServiceStatus.offline);
      expect(find.text('Aún no hay catálogo'), findsOneWidget);

      await tester.tap(find.text('REINTENTAR'));
      await tester.pump();

      expect(repo.refreshes, 1);
    });

    testWidgets('con la descarga fallida muestra el error y deja reintentar', (
      tester,
    ) async {
      final repo = await _open(tester, sync: SyncStatus.fallida);
      expect(find.text('No se pudo descargar el catálogo'), findsOneWidget);

      await tester.tap(find.text('REINTENTAR'));
      await tester.pump();

      expect(repo.refreshes, 1);
    });

    testWidgets('si el reintento también falla no revienta la pantalla', (
      tester,
    ) async {
      final repo = await _open(tester, sync: SyncStatus.fallida);
      repo.refreshError = Exception('sin respuesta');

      await tester.tap(find.text('REINTENTAR'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('No se pudo descargar el catálogo'), findsOneWidget);
    });

    testWidgets('el mensaje y el botón caben en 320×568 al 200 %', (
      tester,
    ) async {
      await _open(
        tester,
        sync: SyncStatus.fallida,
        size: const Size(320, 568),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('REINTENTAR'), findsOneWidget);
    });
  });

  group('búsqueda', () {
    /// Una Pokédex de 3 que filtra por el texto buscado, como la base real.
    Stream<List<Pokemon>> filtered(PokemonQuery query) => Stream.value([
      for (final p in _pokedex(3))
        if (p.name.contains(query.search.trim())) p,
    ]);

    Future<_Repo> openSearch(
      WidgetTester tester, {
      ServiceStatus service = ServiceStatus.online,
      Size size = const Size(390, 844),
      double textScale = 1,
    }) => _open(
      tester,
      onWatch: filtered,
      service: service,
      size: size,
      textScale: textScale,
    );

    /// Escribe [text] y deja pasar el debounce.
    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
    }

    testWidgets('con catálogo aparece el campo de búsqueda', (tester) async {
      await openSearch(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.bySemanticsLabel('Buscar por nombre o número'), findsOne);
      expect(find.byType(PokemonTile), findsNWidgets(3));
    });

    testWidgets('sin catálogo todavía no hay campo', (tester) async {
      await _open(tester, sync: SyncStatus.sincronizando);

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('no consulta hasta pasados 350 ms', (tester) async {
      final repo = await openSearch(tester);
      repo.queries.clear();

      await tester.enterText(find.byType(TextField), 'pokemon2');
      await tester.pump(const Duration(milliseconds: 349));
      expect(repo.queries, isEmpty);
      expect(find.byType(PokemonTile), findsNWidgets(3));

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(repo.queries, [const PokemonQuery(search: 'pokemon2')]);
      expect(find.byType(PokemonTile), findsOneWidget);
    });

    testWidgets('escribir varias letras seguidas hace una sola consulta', (
      tester,
    ) async {
      final repo = await openSearch(tester);
      repo.queries.clear();

      for (final text in ['p', 'po', 'pok']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(repo.queries, [const PokemonQuery(search: 'pok')]);
    });

    testWidgets('sin coincidencias avisa y conserva el campo y el texto', (
      tester,
    ) async {
      await openSearch(tester);

      await type(tester, 'zzz');

      expect(find.text('Sin resultados'), findsOneWidget);
      expect(find.textContaining('«zzz»'), findsOneWidget);
      expect(find.byType(PokemonTile), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'zzz');
    });

    testWidgets('sin conexión avisa de que solo se busca en lo descargado', (
      tester,
    ) async {
      final repo = await openSearch(tester, service: ServiceStatus.offline);

      await type(tester, 'zzz');

      expect(find.text('Sin resultados'), findsOneWidget);
      expect(find.textContaining('Sin conexión'), findsOneWidget);
      expect(repo.remoteSearches, isEmpty);
    });

    testWidgets('con conexión consulta a PokéAPI y muestra «Buscando…»', (
      tester,
    ) async {
      final repo = await openSearch(tester);
      repo.searchGate = Completer<int>();

      await type(tester, 'zzz');

      expect(repo.remoteSearches, ['zzz']);
      expect(find.text('Buscando…'), findsOneWidget);
      expect(find.text('Sin resultados'), findsNothing);

      repo.searchGate!.complete(0);
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);
    });

    testWidgets('el botón de borrar limpia al instante y vuelve la lista', (
      tester,
    ) async {
      final repo = await openSearch(tester);
      expect(find.byTooltip('Borrar búsqueda'), findsNothing);
      await type(tester, 'zzz');
      expect(find.text('Sin resultados'), findsOneWidget);

      await tester.tap(find.byTooltip('Borrar búsqueda'));
      await tester.pumpAndSettle();

      expect(repo.queries.last, const PokemonQuery());
      expect(find.byType(PokemonTile), findsNWidgets(3));
      expect(find.byTooltip('Borrar búsqueda'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
    });

    testWidgets('cabe en 320×568 con el texto al 200 %', (tester) async {
      await openSearch(tester, size: const Size(320, 568), textScale: 2);
      await type(tester, 'zzz');

      expect(tester.takeException(), isNull);
    });
  });
}

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
  _Repo(this._pokemon);

  final Stream<List<Pokemon>> _pokemon;

  @override
  Stream<List<Pokemon>> watchPokemon(PokemonQuery query) => _pokemon;
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
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  useScreen(tester, size, textScale: textScale);
  final repo = _Repo(pokemon ?? Stream.value(const []));
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
}

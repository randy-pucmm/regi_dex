import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/features/pokemon/data/catalog_local_source.dart';
import 'package:regi_dex/features/pokemon/data/integrity_checker.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_mapper.dart';

import '../core/database/database_test_helpers.dart';
import '../features/pokemon/data/catalog_test_data.dart';
import '../features/pokemon/fake_pokemon_repository.dart';

class _FakeChecker extends Fake implements IntegrityChecker {
  final opened = <int>[];

  @override
  Future<IntegrityReport> verifyPokemon(int pokemonId) async {
    opened.add(pokemonId);
    return IntegrityReport.nothing;
  }
}

void main() {
  late AppDatabase db;
  late FakePokemonRepository repository;
  late _FakeChecker checker;
  late ProviderContainer container;

  setUp(() async {
    db = createTestDatabase();
    repository = FakePokemonRepository();
    checker = _FakeChecker();
    final local = CatalogLocalSource(db);
    await local.saveReference(mapReferenceData(syntheticReference()));
    await local.savePokemon(
      mapPokemonPage({
        'pokemon': [syntheticPokemon(25)],
      }, clock.now()),
    );
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        pokemonRepositoryProvider.overrideWithValue(repository),
        integrityCheckerProvider.overrideWithValue(checker),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> setDetailAge(Duration age) =>
      (db.update(db.pokemons)..where((p) => p.id.equals(25))).write(
        PokemonsCompanion(detailSyncedAt: Value(clock.now().subtract(age))),
      );

  test('con el detalle vigente lo compara con el remoto (OF-20)', () async {
    await setDetailAge(const Duration(hours: 1));

    final ok = await container.read(pokemonDetailRefreshProvider(25).future);

    expect(ok, isTrue);
    expect(checker.opened, [25]);
  });

  test(
    'si el detalle venció y se descargó, no repite la comparación',
    () async {
      await setDetailAge(const Duration(days: 4));

      final ok = await container.read(pokemonDetailRefreshProvider(25).future);

      expect(ok, isTrue);
      expect(repository.detailRequests, [25]);
      expect(checker.opened, isEmpty);
    },
  );

  test('si la descarga falla devuelve false y no verifica', () async {
    await setDetailAge(const Duration(hours: 1));
    repository.detailError = const NetworkFailure();

    final ok = await container.read(pokemonDetailRefreshProvider(25).future);

    expect(ok, isFalse);
    expect(checker.opened, isEmpty);
  });
}

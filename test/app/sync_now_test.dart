import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/app/sync_now.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/error/failure.dart';

import '../core/connectivity/connectivity_fakes.dart';
import '../core/database/database_test_helpers.dart';
import '../features/pokemon/fake_pokemon_repository.dart';

/// Repositorio falso que avisa en qué momento se le pidió sincronizar.
class _SpyRepository extends FakePokemonRepository {
  _SpyRepository(this.onRefresh);

  final void Function() onRefresh;

  @override
  Future<void> refresh() {
    onRefresh();
    return super.refresh();
  }
}

void main() {
  late AppDatabase db;
  late FakeHealthChecker health;
  late FakePokemonRepository repository;

  setUp(() {
    db = createTestDatabase();
    health = FakeHealthChecker();
    repository = FakePokemonRepository();
  });
  tearDown(() => db.close());

  ProviderContainer containerWith(FakePokemonRepository repo) {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        networkSourceProvider.overrideWithValue(FakeNetworkSource()),
        healthCheckerProvider.overrideWithValue(health),
        pokemonRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Crea el monitor (que hace su primer health-check) y espera a que termine.
  Future<void> startMonitor(ProviderContainer container) async {
    container.read(connectivityMonitorProvider);
    await pumpEventQueue();
  }

  test('primero comprueba PokéAPI y después sincroniza el catálogo', () async {
    var checksWhenRefreshing = -1;
    final spy = _SpyRepository(() => checksWhenRefreshing = health.calls);
    final container = containerWith(spy);
    await startMonitor(container);
    final checksBefore = health.calls;

    await container.read(syncNowProvider)();

    expect(health.calls, checksBefore + 1);
    expect(spy.refreshes, 1);
    expect(
      checksWhenRefreshing,
      checksBefore + 1,
      reason: 'la comprobación ya se hizo cuando empezó la sync',
    );
  });

  test(
    'si el catálogo no se puede sincronizar, el fallo no se propaga',
    () async {
      repository.refreshError = const NetworkFailure();
      final container = containerWith(repository);
      await startMonitor(container);

      await expectLater(container.read(syncNowProvider)(), completes);

      expect(repository.refreshes, 1);
    },
  );

  test(
    'si el provider se desecha durante la comprobación no sincroniza',
    () async {
      health.delay = const Duration(milliseconds: 40);
      final container = containerWith(repository);
      final syncNow = container.read(syncNowProvider);

      final pending = syncNow();
      container.dispose();
      await pending;

      expect(repository.refreshes, 0);
    },
  );
}

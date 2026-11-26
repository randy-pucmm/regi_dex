import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/app/sync_retry.dart';
import 'package:regi_dex/core/connectivity/service_status.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/sync/sync_coordinator.dart';
import 'package:regi_dex/features/pokemon/data/catalog_sync.dart';

import '../core/database/database_test_helpers.dart';
import '../features/pokemon/fake_pokemon_repository.dart';

void main() {
  test('solo el catálogo y los detalles se reintentan solos', () {
    expect(isRetryable(CatalogSync.resourceKey), isTrue);
    expect(isRetryable('detail:25'), isTrue);
    expect(isRetryable('images'), isTrue);
    expect(isRetryable(CatalogSync.referenceKey), isFalse);
    expect(isRetryable('champions'), isFalse);
  });

  group('syncRetryProvider', () {
    late AppDatabase db;
    late StreamController<ConnectivitySnapshot> connectivity;
    late FakePokemonRepository repository;
    late ProviderContainer container;

    setUp(() {
      db = createTestDatabase();
      connectivity = StreamController<ConnectivitySnapshot>();
      repository = FakePokemonRepository();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          pokemonRepositoryProvider.overrideWithValue(repository),
          serviceStatusProvider.overrideWith((ref) => connectivity.stream),
        ],
      );
      container.listen(serviceStatusProvider, (_, _) {});
      container.listen(syncRetryProvider, (_, _) {});
    });
    tearDown(() async {
      container.dispose();
      await connectivity.close();
      await db.close();
    });

    Future<void> emit(ServiceStatus status) async {
      connectivity.add(ConnectivitySnapshot(status: status));
      await pumpEventQueue();
    }

    Future<void> markFailed({
      String key = CatalogSync.resourceKey,
      Duration retryIn = const Duration(seconds: -1),
    }) => db.syncMetadataDao.upsert(
      SyncMetadataEntriesCompanion.insert(
        resourceKey: key,
        status: SyncMetadataStatus.failed,
        attempts: const Value(1),
        nextRetryAt: Value(clock.now().add(retryIn)),
      ),
    );

    test('con servicio y un reintento vencido, relanza el catálogo', () async {
      await emit(ServiceStatus.online);

      await markFailed();
      await pumpEventQueue(times: 50);

      expect(repository.refreshes, 1);
    });

    test('sin servicio espera y reintenta al volver (PA-07)', () async {
      await emit(ServiceStatus.offline);
      await markFailed();
      await pumpEventQueue(times: 50);
      expect(repository.refreshes, 0);

      await emit(ServiceStatus.online);
      await pumpEventQueue(times: 50);

      expect(repository.refreshes, 1);
    });

    test('un reintento que aún no toca no se adelanta', () async {
      await emit(ServiceStatus.online);

      await markFailed(retryIn: const Duration(minutes: 5));
      await pumpEventQueue(times: 50);

      expect(repository.refreshes, 0);
    });

    test('la referencia fallida no dispara un reintento propio', () async {
      await emit(ServiceStatus.online);

      await markFailed(key: CatalogSync.referenceKey);
      await pumpEventQueue(times: 50);

      expect(repository.refreshes, 0);
    });
  });
}

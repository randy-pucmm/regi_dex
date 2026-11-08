import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/catalog_auto_sync.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/core/connectivity/service_status.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/core/sync/sync_coordinator.dart';
import 'package:regi_dex/features/pokemon/data/catalog_sync.dart';

import '../core/database/database_test_helpers.dart';
import '../features/pokemon/fake_pokemon_repository.dart';

final _now = DateTime(2026, 11, 7, 12);

SyncMetadataRow _entry({
  String status = SyncMetadataStatus.completed,
  DateTime? lastSuccessAt,
  int cursorOffset = 0,
}) => SyncMetadataRow(
  resourceKey: CatalogSync.resourceKey,
  status: status,
  lastSuccessAt: lastSuccessAt,
  attempts: 0,
  cursorOffset: cursorOffset,
);

void main() {
  group('catalogNeedsSync', () {
    test('sin fila hay que sincronizar', () {
      expect(catalogNeedsSync(null, _now), isTrue);
    });

    test('completado y reciente no hace falta', () {
      final fresh = _entry(
        lastSuccessAt: _now.subtract(const Duration(days: 2)),
      );
      expect(catalogNeedsSync(fresh, _now), isFalse);
    });

    test('a los 7 días ya está vencido', () {
      final old = _entry(lastSuccessAt: _now.subtract(const Duration(days: 7)));
      expect(catalogNeedsSync(old, _now), isTrue);
    });

    test('una pasada a medias (cursor > 0) hay que reanudarla', () {
      final partial = _entry(
        lastSuccessAt: _now.subtract(const Duration(hours: 1)),
        cursorOffset: 400,
      );
      expect(catalogNeedsSync(partial, _now), isTrue);
    });

    test('fallida o en curso se reintenta', () {
      final recent = _now.subtract(const Duration(hours: 1));
      expect(
        catalogNeedsSync(
          _entry(status: SyncMetadataStatus.failed, lastSuccessAt: recent),
          _now,
        ),
        isTrue,
      );
      expect(
        catalogNeedsSync(
          _entry(status: SyncMetadataStatus.syncing, lastSuccessAt: recent),
          _now,
        ),
        isTrue,
      );
    });

    test('completada sin fecha de éxito se trata como vencida', () {
      expect(catalogNeedsSync(_entry(), _now), isTrue);
    });
  });

  group('catalogAutoSyncProvider', () {
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
      // Con oyente, como lo observa RegiDexApp: sin él Riverpod pausa las
      // suscripciones del provider.
      container.listen(catalogAutoSyncProvider, (_, _) {});
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

    Future<void> markCompleted({required Duration ago, int cursor = 0}) =>
        db.syncMetadataDao.upsert(
          SyncMetadataEntriesCompanion.insert(
            resourceKey: CatalogSync.resourceKey,
            status: SyncMetadataStatus.completed,
            lastSuccessAt: Value(clock.now().subtract(ago)),
            cursorOffset: Value(cursor),
          ),
        );

    test('al estar online sin catálogo lo sincroniza una vez', () async {
      await emit(ServiceStatus.online);

      expect(repository.refreshes, 1);
    });

    test('con el catálogo vigente no sincroniza', () async {
      await markCompleted(ago: const Duration(days: 1));

      await emit(ServiceStatus.online);

      expect(repository.refreshes, 0);
    });

    test('con el catálogo vencido sincroniza', () async {
      await markCompleted(ago: const Duration(days: 8));

      await emit(ServiceStatus.online);

      expect(repository.refreshes, 1);
    });

    test('una pasada interrumpida se reanuda al volver la conexión', () async {
      await markCompleted(ago: const Duration(hours: 1), cursor: 400);

      await emit(ServiceStatus.online);

      expect(repository.refreshes, 1);
    });

    test('sin conexión o verificando no sincroniza', () async {
      await emit(ServiceStatus.verificando);
      await emit(ServiceStatus.offline);
      await emit(ServiceStatus.servicioNoDisponible);

      expect(repository.refreshes, 0);
    });

    test('al pasar de offline a online sincroniza', () async {
      await emit(ServiceStatus.offline);
      expect(repository.refreshes, 0);

      await emit(ServiceStatus.online);

      expect(repository.refreshes, 1);
    });

    test('varias lecturas online seguidas disparan una sola vez', () async {
      await emit(ServiceStatus.online);
      await emit(ServiceStatus.online);
      await emit(ServiceStatus.online);

      expect(repository.refreshes, 1);
    });

    test('cada reconexión vuelve a evaluar si hace falta', () async {
      await emit(ServiceStatus.online);
      await emit(ServiceStatus.offline);
      await emit(ServiceStatus.online);

      expect(repository.refreshes, 2);
    });

    test('un fallo de la sincronización no se propaga a la app', () async {
      repository.refreshError = const NetworkFailure();

      await emit(ServiceStatus.online);

      expect(repository.refreshes, 1);
    });
  });
}

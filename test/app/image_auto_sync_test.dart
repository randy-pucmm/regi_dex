import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/image_auto_sync.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/core/connectivity/service_status.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/images/image_prefetcher.dart';
import 'package:regi_dex/core/sync/sync_coordinator.dart';
import 'package:regi_dex/features/pokemon/data/catalog_local_source.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_mapper.dart';

import '../core/database/database_test_helpers.dart';
import '../features/pokemon/data/catalog_test_data.dart';

final _at = DateTime(2026, 11, 26, 9);

SyncMetadataRow _row(
  String key, {
  String status = SyncMetadataStatus.completed,
  DateTime? lastSuccessAt,
}) => SyncMetadataRow(
  resourceKey: key,
  status: status,
  lastSuccessAt: lastSuccessAt,
  attempts: 0,
  cursorOffset: 0,
);

void main() {
  group('shouldStartImageSync', () {
    final catalog = _row('catalog', lastSuccessAt: _at);

    bool should({
      SyncMetadataRow? images,
      SyncMetadataRow? catalogRow,
      bool running = false,
      bool afterReconnect = false,
    }) => shouldStartImageSync(
      images: images,
      catalog: catalogRow ?? catalog,
      running: running,
      afterReconnect: afterReconnect,
    );

    test('primera corrida con el catálogo completo: arranca', () {
      expect(should(), isTrue);
    });

    test('sin catálogo completo espera', () {
      expect(should(catalogRow: _row('catalog')), isFalse);
    });

    test('con una pasada corriendo no duplica', () {
      expect(should(running: true), isFalse);
    });

    test('imágenes al día: no hace nada', () {
      final images = _row(
        'images',
        lastSuccessAt: _at.add(const Duration(minutes: 1)),
      );

      expect(should(images: images), isFalse);
    });

    test('una pasada fallida la reintenta el planificador, no esto', () {
      final failed = _row('images', status: SyncMetadataStatus.failed);

      expect(should(images: failed), isFalse);
      expect(should(images: failed, afterReconnect: true), isTrue);
    });

    test('una pasada que quedó «en curso» tras cerrar la app se retoma', () {
      final stale = _row('images', status: SyncMetadataStatus.syncing);

      expect(should(images: stale), isTrue);
    });
  });

  group('imageAutoSyncProvider', () {
    late AppDatabase db;
    late StreamController<ConnectivitySnapshot> connectivity;
    late ProviderContainer container;
    late List<String> downloaded;

    setUp(() async {
      db = createTestDatabase();
      downloaded = [];
      connectivity = StreamController<ConnectivitySnapshot>();
      final local = CatalogLocalSource(db);
      await local.saveReference(mapReferenceData(syntheticReference()));
      await local.savePokemon(
        mapPokemonPage({
          'pokemon': [for (var id = 1; id <= 3; id++) syntheticPokemon(id)],
        }, _at),
      );
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          serviceStatusProvider.overrideWith((ref) => connectivity.stream),
          imagePrefetcherProvider.overrideWithValue(
            ImagePrefetcher(
              isCached: (_) async => false,
              download: (url) async => downloaded.add(url),
            ),
          ),
        ],
      );
      container.listen(serviceStatusProvider, (_, _) {});
      container.listen(imageAutoSyncProvider, (_, _) {});
    });
    tearDown(() async {
      container.dispose();
      await connectivity.close();
      await db.close();
    });

    Future<void> emit(ServiceStatus status) async {
      connectivity.add(ConnectivitySnapshot(status: status));
      await pumpEventQueue(times: 50);
    }

    Future<void> completeCatalog() => db.syncMetadataDao.upsert(
      SyncMetadataEntriesCompanion.insert(
        resourceKey: 'catalog',
        status: SyncMetadataStatus.completed,
        lastSuccessAt: Value(_at),
      ),
    );

    test('con el catálogo completo y servicio descarga los sprites', () async {
      await completeCatalog();
      await emit(ServiceStatus.online);

      expect(downloaded, hasLength(3));
      final entry = await db.syncMetadataDao.getEntry('images');
      expect(entry?.status, SyncMetadataStatus.completed);
    });

    test('no descarga hasta que el catálogo esté completo', () async {
      await emit(ServiceStatus.online);
      expect(downloaded, isEmpty);

      await completeCatalog();
      await pumpEventQueue(times: 50);

      expect(downloaded, hasLength(3));
    });

    test('sin servicio espera y descarga al volver', () async {
      await completeCatalog();
      await emit(ServiceStatus.offline);
      expect(downloaded, isEmpty);

      await emit(ServiceStatus.online);

      expect(downloaded, hasLength(3));
    });

    test(
      'ya descargadas, un nuevo estado online no vuelve a bajarlas',
      () async {
        await completeCatalog();
        await emit(ServiceStatus.online);
        await emit(ServiceStatus.offline);
        await emit(ServiceStatus.online);

        expect(downloaded, hasLength(3));
      },
    );
  });
}

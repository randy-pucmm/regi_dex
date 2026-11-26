import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/images/image_prefetcher.dart';
import 'package:regi_dex/core/sync/backoff_policy.dart';
import 'package:regi_dex/core/sync/sync_coordinator.dart';
import 'package:regi_dex/features/pokemon/data/catalog_local_source.dart';
import 'package:regi_dex/features/pokemon/data/image_sync.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_mapper.dart';

import '../../../core/database/database_test_helpers.dart';
import 'catalog_test_data.dart';

final _now = DateTime(2026, 11, 26, 9);

SyncMetadataRow _row(
  String key, {
  String status = SyncMetadataStatus.completed,
  DateTime? lastSuccessAt,
  int cursorOffset = 0,
}) => SyncMetadataRow(
  resourceKey: key,
  status: status,
  lastSuccessAt: lastSuccessAt,
  attempts: 0,
  cursorOffset: cursorOffset,
);

void main() {
  group('imagesNeedSync', () {
    final catalog = _row('catalog', lastSuccessAt: _now);

    test('sin catálogo completo no hace falta todavía', () {
      expect(imagesNeedSync(null, null), isFalse);
      expect(
        imagesNeedSync(null, _row('catalog', lastSuccessAt: null)),
        isFalse,
      );
      expect(
        imagesNeedSync(
          null,
          _row('catalog', lastSuccessAt: _now, cursorOffset: 200),
        ),
        isFalse,
      );
      expect(
        imagesNeedSync(
          null,
          _row(
            'catalog',
            status: SyncMetadataStatus.failed,
            lastSuccessAt: _now,
          ),
        ),
        isFalse,
      );
    });

    test('con el catálogo completo y sin imágenes, sí', () {
      expect(imagesNeedSync(null, catalog), isTrue);
    });

    test('las imágenes bajadas después del catálogo están al día', () {
      final images = _row(
        'images',
        lastSuccessAt: _now.add(const Duration(minutes: 3)),
      );

      expect(imagesNeedSync(images, catalog), isFalse);
    });

    test('un catálogo más nuevo que las imágenes las vuelve a pedir', () {
      final images = _row(
        'images',
        lastSuccessAt: _now.subtract(const Duration(days: 7)),
      );

      expect(imagesNeedSync(images, catalog), isTrue);
    });
  });

  group('ImageSync', () {
    late AppDatabase db;
    late SyncCoordinator coordinator;
    late List<String> downloaded;
    late Set<String> failing;
    late ImageSync sync;

    setUp(() async {
      db = createTestDatabase();
      downloaded = [];
      failing = {};
      coordinator = SyncCoordinator(
        metadata: db.syncMetadataDao,
        backoff: BackoffPolicy(jitter: 0),
        log: (_) {},
      );
      final local = CatalogLocalSource(db);
      await local.saveReference(mapReferenceData(syntheticReference()));
      await local.savePokemon(
        mapPokemonPage({
          'pokemon': [for (var id = 1; id <= 5; id++) syntheticPokemon(id)],
        }, _now),
      );
      sync = ImageSync(
        catalog: db.catalogDao,
        prefetcher: ImagePrefetcher(
          isCached: (_) async => false,
          download: (url) async {
            if (failing.contains(url)) throw StateError('sin red');
            downloaded.add(url);
          },
        ),
        coordinator: coordinator,
      );
    });
    tearDown(() async {
      coordinator.dispose();
      await db.close();
    });

    test('spriteUrls devuelve los sprites de la lista por número', () async {
      expect(await db.catalogDao.spriteUrls(), [
        for (var id = 1; id <= 5; id++) 'https://img.test/$id.png',
      ]);
    });

    test('baja todos los sprites y queda completada', () async {
      await sync.run();

      expect(downloaded, hasLength(5));
      final entry = await db.syncMetadataDao.getEntry(ImageSync.resourceKey);
      expect(entry?.status, SyncMetadataStatus.completed);
      expect(entry?.lastSuccessAt, isNotNull);
    });

    test('si falta alguna, falla y queda lista para reintentar', () async {
      failing.add('https://img.test/3.png');

      await expectLater(sync.run(), throwsA(isA<ImageSyncIncomplete>()));

      final entry = await db.syncMetadataDao.getEntry(ImageSync.resourceKey);
      expect(entry?.status, SyncMetadataStatus.failed);
      expect(entry?.attempts, 1);
      expect(entry?.nextRetryAt, isNotNull);
      expect(entry?.lastSuccessAt, isNull);
    });

    test('tras el reintento exitoso se marca completada', () async {
      failing.add('https://img.test/3.png');
      await expectLater(sync.run(), throwsA(isA<ImageSyncIncomplete>()));

      failing.clear();
      await sync.run();

      final entry = await db.syncMetadataDao.getEntry(ImageSync.resourceKey);
      expect(entry?.status, SyncMetadataStatus.completed);
      expect(entry?.attempts, 0);
    });

    test('mientras corre, la sync se muestra como sincronizando', () async {
      final statuses = <String>[];
      final subscription = coordinator.statuses.listen(
        (s) => statuses.add(s.name),
      );

      await sync.run();
      await pumpEventQueue();
      await subscription.cancel();

      expect(statuses, containsAllInOrder(['sincronizando', 'completada']));
    });
  });
}

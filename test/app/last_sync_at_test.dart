import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/app/shell_status.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/sync/sync_coordinator.dart';

import '../core/database/database_test_helpers.dart';

final _catalogAt = DateTime(2026, 11, 6, 9, 15);
final _newerAt = DateTime(2026, 11, 6, 11, 40);

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = createTestDatabase();
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    // Con oyente: sin él Riverpod pausa las suscripciones del provider.
    container.listen(lastSyncAtProvider, (_, _) {});
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> completed(String key, DateTime at) => db.syncMetadataDao.upsert(
    SyncMetadataEntriesCompanion.insert(
      resourceKey: key,
      status: SyncMetadataStatus.completed,
      lastSuccessAt: Value(at),
    ),
  );

  Future<DateTime?> lastSync() async {
    await pumpEventQueue();
    return container.read(lastSyncAtProvider).value;
  }

  test('sin sincronizaciones no hay hora', () async {
    expect(await lastSync(), isNull);
  });

  test('el recurso visible por defecto es el catálogo', () {
    expect(container.read(visibleResourceProvider), 'catalog');
  });

  test('devuelve la última sync correcta del catálogo', () async {
    await completed('catalog', _catalogAt);

    expect(await lastSync(), _catalogAt);
  });

  test('una sync más reciente de otro recurso no cuenta', () async {
    await completed('catalog', _catalogAt);
    await completed('reference', _newerAt);
    await completed('detail:1', _newerAt);

    expect(await lastSync(), _catalogAt);
  });

  test('sin sync del catálogo no toma la hora de otro recurso', () async {
    await completed('reference', _newerAt);

    expect(await lastSync(), isNull);
  });

  test('un intento fallido no cambia la hora del último éxito', () async {
    await completed('catalog', _catalogAt);
    await db.syncMetadataDao.upsert(
      SyncMetadataEntriesCompanion.insert(
        resourceKey: 'catalog',
        status: SyncMetadataStatus.failed,
        lastAttemptAt: Value(_newerAt),
      ),
    );

    expect(await lastSync(), _catalogAt);
  });

  test('se actualiza cuando el catálogo termina otra sync', () async {
    await completed('catalog', _catalogAt);
    expect(await lastSync(), _catalogAt);

    await completed('catalog', _newerAt);

    expect(await lastSync(), _newerAt);
  });

  test('cambiar el recurso visible cambia la hora que se muestra', () async {
    await completed('catalog', _catalogAt);
    await completed('champions', _newerAt);
    final other = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        visibleResourceProvider.overrideWithValue('champions'),
      ],
    );
    addTearDown(other.dispose);
    other.listen(lastSyncAtProvider, (_, _) {});
    await pumpEventQueue();

    expect(other.read(lastSyncAtProvider).value, _newerAt);
    expect(await lastSync(), _catalogAt);
  });
}

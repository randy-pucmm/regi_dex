import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/core/connectivity/budgeted_health_checker.dart';
import 'package:regi_dex/core/sync/sync_coordinator.dart';
import 'package:regi_dex/core/sync/sync_status.dart';

import '../core/database/database_test_helpers.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    final db = createTestDatabase();
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
  });

  test('el presupuesto escribe en el api_call_log de la base', () async {
    final permit = await container.read(apiBudgetProvider).tryAcquire('A');

    expect(permit, isNotNull);
    expect(
      await rowCount(container.read(appDatabaseProvider), 'api_call_log'),
      1,
    );
  });

  test('el health-check del monitor pasa por el presupuesto', () {
    expect(container.read(healthCheckerProvider), isA<BudgetedHealthChecker>());
  });

  test('el coordinador guarda en sync_metadata de la base', () async {
    await container.read(syncCoordinatorProvider).run('reference', () async {});

    final row = await container
        .read(appDatabaseProvider)
        .syncMetadataDao
        .getEntry('reference');
    expect(row!.status, SyncMetadataStatus.completed);
  });

  test('syncStatusProvider publica el estado del coordinador', () async {
    container.listen(syncStatusProvider, (_, _) {});
    await pumpEventQueue();
    expect(
      container.read(syncStatusProvider).requireValue,
      SyncStatus.inactiva,
    );

    await container.read(syncCoordinatorProvider).run('reference', () async {});
    await pumpEventQueue();

    expect(
      container.read(syncStatusProvider).requireValue,
      SyncStatus.completada,
    );
  });
}

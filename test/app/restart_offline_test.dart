// Reiniciar la app sin red (PA-03, PA-04): el indicador dice «Sin conexión»,
// el origen local y la hora de la última sync, y los datos siguen ahí.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/app.dart';
import 'package:regi_dex/app/catalog_auto_sync.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/app/shell_status.dart';
import 'package:regi_dex/core/connectivity/service_status.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/sync/sync_coordinator.dart';
import 'package:regi_dex/features/pokemon/data/catalog_sync.dart';
import 'package:regi_dex/ui/components/status_led.dart';
import 'package:regi_dex/ui/tokens/led_state.dart';

import '../core/connectivity/connectivity_fakes.dart';
import '../core/database/database_test_helpers.dart';
import '../core/sync/fake_time.dart';
import '../features/pokemon/data/fake_pokemon_remote.dart';
import '../helpers/ui_test_helpers.dart';

/// Hora de la última sync de la sesión anterior.
final _lastSync = DateTime(2026, 11, 6, 9, 15);

const _offlineLabel =
    'Estado de conexión: Sin conexión. Datos locales · última sync 09:15';

/// Destinos de Inicio que abren una pantalla (Ajustes abre una ventana).
const _screens = ['Catálogo', 'Favoritos', 'Equipos', 'Trivia'];

void main() {
  group('reinicio sin red tras una sesión en línea', () {
    late AppDatabase db;
    late FakeHealthChecker health;
    late ProviderContainer container;

    /// Primera sesión: con red, descarga 5 Pokémon y cierra la app.
    Future<void> firstSession() async {
      final time = FakeTime()..now = _lastSync;
      final online = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          networkSourceProvider.overrideWithValue(FakeNetworkSource()),
          healthCheckerProvider.overrideWithValue(FakeHealthChecker()),
          pokemonRemoteSourceProvider.overrideWithValue(
            FakePokemonRemote(total: 5),
          ),
        ],
      );
      await time.run(() => online.read(refreshCatalogProvider)());
      online.dispose();
    }

    setUp(() async {
      db = createTestDatabase();
      health = FakeHealthChecker();
      await firstSession();

      // Segunda sesión: el dispositivo no tiene red.
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          networkSourceProvider.overrideWithValue(
            FakeNetworkSource(NetworkKind.none),
          ),
          healthCheckerProvider.overrideWithValue(health),
        ],
      );
      // Con oyentes, como los observa RegiDexApp.
      container.listen(shellStatusProvider, (_, _) {});
      container.listen(catalogAutoSyncProvider, (_, _) {});
      await pumpEventQueue();
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('el LED dice sin conexión, datos locales y la hora de la sync', () {
      final status = container.read(shellStatusProvider);

      expect(status.led, LedState.offline);
      expect(status.title, 'Sin conexión');
      expect(status.subtitle, 'Datos locales · última sync 09:15');
      expect(status.updatedLabel, 'ACT. 09:15');
      expect(status.semanticsLabel, _offlineLabel);
    });

    test('«Sincronizar ahora» queda deshabilitado', () {
      expect(container.read(shellStatusProvider).canSyncNow, isFalse);
    });

    test('no sale a la red: ni health-check ni llamadas registradas', () async {
      final logged = await db.apiCallLogDao.countSince(DateTime(2000));

      expect(health.calls, 0);
      // El remoto falso de la primera sesión no gasta presupuesto, así que
      // cualquier llamada registrada sería de la segunda sesión.
      expect(logged, 0);
    });

    test('el catálogo descargado sigue disponible', () async {
      final pokemon = await container.read(watchPokemonProvider)().first;

      expect(pokemon.map((p) => p.id), [1, 2, 3, 4, 5]);
      expect(pokemon.first.types.single.name, 'type-2');
    });

    test(
      'la hora guardada sobrevive aunque la sesión nueva no sincronice',
      () async {
        final entry = await db.syncMetadataDao.getEntry(
          CatalogSync.resourceKey,
        );

        expect(entry!.status, SyncMetadataStatus.completed);
        expect(entry.lastSuccessAt, _lastSync);
      },
    );
  });

  group('en las cinco pantallas', () {
    late AppDatabase db;

    /// Pantalla con red caída y una sync anterior a las 09:15.
    Future<void> pumpOffline(WidgetTester tester) async {
      useScreen(tester, const Size(390, 844));
      reduceMotion(tester);
      db = createTestDatabase();
      addTearDown(db.close);
      await seedReference(db);
      await upsertBulbasaur(db);
      await db.syncMetadataDao.upsert(
        SyncMetadataEntriesCompanion.insert(
          resourceKey: CatalogSync.resourceKey,
          status: SyncMetadataStatus.completed,
          lastSuccessAt: Value(_lastSync),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            networkSourceProvider.overrideWithValue(
              FakeNetworkSource(NetworkKind.none),
            ),
            healthCheckerProvider.overrideWithValue(FakeHealthChecker()),
          ],
          child: const RegiDexApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    void expectOfflineIndicator(String where) {
      expect(find.byType(StatusLed), findsOneWidget, reason: where);
      expect(
        find.bySemanticsLabel(_offlineLabel),
        findsOneWidget,
        reason: where,
      );
      expect(find.text('ACT. 09:15'), findsOneWidget, reason: where);
    }

    testWidgets('Inicio, Catálogo, Favoritos, Equipos y Trivia lo muestran', (
      tester,
    ) async {
      await pumpOffline(tester);
      expectOfflineIndicator('Inicio');

      for (final label in _screens) {
        await tester.tap(find.text(label.toUpperCase()));
        await tester.pumpAndSettle();
        expectOfflineIndicator(label);

        await tester.tap(find.text('Inicio'));
        await tester.pumpAndSettle();
      }

      // Ajustes es una ventana sobre Inicio: la cabecera no desaparece.
      await tester.tap(find.text('AJUSTES'));
      await tester.pumpAndSettle();
      expectOfflineIndicator('Ajustes');
      expect(tester.takeException(), isNull);

      // Se desmonta todo para que Drift cierre sus flujos antes de terminar.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('el detalle del LED explica que los datos son locales', (
      tester,
    ) async {
      await pumpOffline(tester);

      await tester.tap(find.byType(StatusLed));
      await tester.pumpAndSettle();

      expect(find.text('SIN CONEXIÓN'), findsOneWidget);
      expect(find.text('Datos locales · última sync 09:15'), findsWidgets);
      expect(find.text('Locales · última sync 09:15'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}

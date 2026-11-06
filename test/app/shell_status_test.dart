import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/app/shell_status.dart';
import 'package:regi_dex/core/connectivity/service_status.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/core/sync/sync_status.dart';
import 'package:regi_dex/ui/components/indicator_glyph.dart';
import 'package:regi_dex/ui/tokens/led_state.dart';

final _now = DateTime(2026, 11, 6, 15);
final _lastSync = DateTime(2026, 11, 6, 9, 15);

const _online = ConnectivitySnapshot(
  status: ServiceStatus.online,
  networkKind: NetworkKind.wifi,
);
const _offline = ConnectivitySnapshot(status: ServiceStatus.offline);
const _down = ConnectivitySnapshot(
  status: ServiceStatus.servicioNoDisponible,
  networkKind: NetworkKind.wifi,
  lastFailure: TimeoutFailure(),
);

ShellStatus _status({
  ConnectivitySnapshot connectivity = _online,
  SyncStatus sync = SyncStatus.inactiva,
  DateTime? lastSync,
}) => buildShellStatus(
  connectivity: connectivity,
  sync: sync,
  lastSyncAt: lastSync,
  now: _now,
);

IndicatorSpec _indicator(ShellStatus status, String label) =>
    status.indicators.singleWhere((i) => i.label == label);

String _row(ShellStatus status, String label) =>
    status.rows.singleWhere((r) => r.label == label).value;

void main() {
  group('en línea', () {
    final status = _status(lastSync: _lastSync);

    test('LED verde, y dice el origen y la hora de los datos', () {
      expect(status.led, LedState.online);
      expect(status.title, 'En línea');
      expect(status.subtitle, 'Datos remotos · actualizado 09:15');
      expect(status.updatedLabel, 'ACT. 09:15');
      expect(status.isSyncing, isFalse);
      expect(status.canSyncNow, isTrue);
    });

    test('los tres indicadores van llenos y verdes', () {
      for (final label in ['RED', 'API', 'DATOS']) {
        final indicator = _indicator(status, label);
        expect(indicator.glyph, IndicatorGlyph.solid, reason: label);
        expect(indicator.tone, LedState.online, reason: label);
      }
    });

    test('el detalle trae red, API y datos, sin reintento', () {
      expect(_row(status, 'Red'), 'Activa (Wi-Fi)');
      expect(_row(status, 'PokéAPI'), 'Disponible');
      expect(_row(status, 'Datos'), 'Remotos · actualizado 09:15');
      expect(status.rows.map((r) => r.label), isNot(contains('Reintento')));
    });

    test('la etiqueta del lector de pantalla junta estado y vigencia', () {
      expect(
        status.semanticsLabel,
        'Estado de conexión: En línea. Datos remotos · actualizado 09:15',
      );
    });

    test(
      'sin ninguna sincronización previa lo dice en vez de inventar hora',
      () {
        final first = _status();

        expect(first.subtitle, 'Datos remotos · aún sin actualizar');
        expect(first.updatedLabel, 'ACT. --:--');
        expect(_row(first, 'Datos'), 'Remotos · aún sin actualizar');
      },
    );
  });

  group('sin conexión', () {
    final status = _status(connectivity: _offline, lastSync: _lastSync);

    test('LED apagado con datos locales y la hora de la última sync', () {
      expect(status.led, LedState.offline);
      expect(status.title, 'Sin conexión');
      expect(status.subtitle, 'Datos locales · última sync 09:15');
      expect(status.canSyncNow, isFalse);
    });

    test('RED y API van vacíos; DATOS lleno y neutro porque son locales', () {
      expect(_indicator(status, 'RED').glyph, IndicatorGlyph.hollow);
      expect(_indicator(status, 'RED').tone, LedState.offline);
      expect(_indicator(status, 'API').glyph, IndicatorGlyph.hollow);
      expect(_indicator(status, 'DATOS').glyph, IndicatorGlyph.solid);
      expect(_indicator(status, 'DATOS').tone, isNull);
    });

    test('el detalle dice que no hay red y que los datos son locales', () {
      expect(_row(status, 'Red'), 'Sin conexión');
      expect(_row(status, 'PokéAPI'), 'Sin conexión');
      expect(_row(status, 'Datos'), 'Locales · última sync 09:15');
    });

    test('sin sincronización previa no inventa una hora', () {
      final first = _status(connectivity: _offline);

      expect(first.subtitle, 'Datos locales · sin sincronizar');
      expect(_row(first, 'Datos'), 'Locales · sin sincronizar');
    });
  });

  group('servicio no disponible', () {
    final status = _status(connectivity: _down, lastSync: _lastSync);

    test('LED de fallo: hay red pero PokéAPI no responde', () {
      expect(status.led, LedState.down);
      expect(status.title, 'Servicio no disponible');
      expect(status.subtitle, 'Red activa, API sin respuesta · datos locales');
      expect(status.canSyncNow, isTrue);
    });

    test('la red sigue en verde y solo la API muestra el fallo', () {
      expect(_indicator(status, 'RED').glyph, IndicatorGlyph.solid);
      expect(_indicator(status, 'RED').tone, LedState.online);
      expect(_indicator(status, 'API').glyph, IndicatorGlyph.target);
      expect(_indicator(status, 'API').tone, LedState.down);
      expect(_indicator(status, 'DATOS').tone, isNull);
    });

    test('el detalle explica el fallo en lenguaje de persona', () {
      final cases = <Failure?, String>{
        null: 'Sin respuesta',
        const TimeoutFailure(): 'Sin respuesta (timeout)',
        const NetworkFailure(): 'No se pudo conectar',
        const ServiceUnavailableFailure('x', statusCode: 503):
            'Error del servidor (HTTP 503)',
        const ServiceUnavailableFailure('x'): 'Servicio no disponible',
        const RateLimitFailure('x', retryAfter: Duration(seconds: 5)):
            'Límite de llamadas superado',
        const BudgetExhaustedFailure('x', retryAfter: Duration(seconds: 5)):
            'Cupo de llamadas agotado',
        const GraphQLFailure('x'): 'Respuesta no válida',
        const ValidationFailure('x'): 'Respuesta no válida',
      };
      for (final MapEntry(key: failure, value: text) in cases.entries) {
        final status = _status(
          connectivity: ConnectivitySnapshot(
            status: ServiceStatus.servicioNoDisponible,
            networkKind: NetworkKind.wifi,
            lastFailure: failure,
          ),
        );
        expect(_row(status, 'PokéAPI'), text, reason: '$failure');
      }
    });

    test('muestra cuánto falta para el próximo reintento', () {
      String retry(Duration wait) => _row(
        _status(
          connectivity: ConnectivitySnapshot(
            status: ServiceStatus.servicioNoDisponible,
            networkKind: NetworkKind.wifi,
            nextRetryAt: _now.add(wait),
          ),
        ),
        'Reintento',
      );

      expect(retry(const Duration(seconds: 30)), 'en 30 s');
      expect(retry(const Duration(seconds: 59)), 'en 59 s');
      expect(retry(const Duration(seconds: 61)), 'en 2 min');
      expect(retry(const Duration(minutes: 5)), 'en 5 min');
      expect(retry(const Duration(seconds: -4)), 'en 0 s');
    });
  });

  group('sincronizando', () {
    final status = _status(sync: SyncStatus.sincronizando);

    test('LED de sincronización y se puede seguir navegando', () {
      expect(status.led, LedState.sync);
      expect(status.title, 'Sincronizando');
      expect(status.subtitle, 'En línea · puedes seguir navegando');
      expect(status.isSyncing, isTrue);
      expect(status.canSyncNow, isFalse);
    });

    test('API y DATOS giran; la red sigue en verde', () {
      expect(_indicator(status, 'RED').glyph, IndicatorGlyph.solid);
      expect(_indicator(status, 'API').glyph, IndicatorGlyph.syncing);
      expect(_indicator(status, 'API').tone, LedState.sync);
      expect(_indicator(status, 'DATOS').glyph, IndicatorGlyph.syncing);
      expect(_row(status, 'Datos'), 'Actualizando…');
    });

    test('solo cambia el LED si el servicio está en línea', () {
      expect(
        _status(connectivity: _down, sync: SyncStatus.sincronizando).led,
        LedState.down,
      );
      expect(
        _status(connectivity: _offline, sync: SyncStatus.sincronizando).led,
        LedState.offline,
      );
    });

    test('otros estados de la sync no alteran el LED en línea', () {
      for (final sync in [
        SyncStatus.inactiva,
        SyncStatus.completada,
        SyncStatus.fallida,
        SyncStatus.esperandoReintento,
      ]) {
        expect(_status(sync: sync).led, LedState.online, reason: '$sync');
      }
    });
  });

  group('arranque, antes de un estado estable', () {
    final status = _status(connectivity: const ConnectivitySnapshot());

    test('se muestra «Verificando» con el aspecto de sincronización', () {
      expect(status.led, LedState.sync);
      expect(status.title, 'Verificando');
      expect(status.subtitle, 'Comprobando la conexión · datos locales');
      expect(status.isSyncing, isTrue);
      expect(status.canSyncNow, isFalse);
      expect(_indicator(status, 'API').semantics, 'API: verificando');
    });
  });

  group('sin parpadeos', () {
    test('verificar con un estado estable no cambia lo que se ve (IND-06)', () {
      final stable = _status(connectivity: _online);
      final verifying = _status(
        connectivity: const ConnectivitySnapshot(
          status: ServiceStatus.online,
          networkKind: NetworkKind.wifi,
          isVerifying: true,
        ),
      );

      expect(verifying.led, stable.led);
      expect(verifying.title, stable.title);
    });
  });

  group('red', () {
    String network(NetworkKind kind) => _row(
      _status(
        connectivity: ConnectivitySnapshot(
          status: ServiceStatus.online,
          networkKind: kind,
        ),
      ),
      'Red',
    );

    test('nombra el tipo de conexión', () {
      expect(network(NetworkKind.wifi), 'Activa (Wi-Fi)');
      expect(network(NetworkKind.mobile), 'Activa (datos móviles)');
      expect(network(NetworkKind.ethernet), 'Activa (Ethernet)');
      expect(network(NetworkKind.other), 'Activa (otra red)');
      expect(network(NetworkKind.none), 'Activa');
    });
  });

  group('indicadores', () {
    test(
      'van siempre en el orden RED, API, DATOS y se anuncian por separado',
      () {
        for (final status in [
          _status(),
          _status(connectivity: _offline),
          _status(connectivity: _down),
          _status(sync: SyncStatus.sincronizando),
        ]) {
          expect(status.indicators.map((i) => i.label), [
            'RED',
            'API',
            'DATOS',
          ]);
          for (final indicator in status.indicators) {
            expect(indicator.semantics, startsWith('${_name(indicator)}: '));
          }
        }
      },
    );
  });

  test('la hora se muestra en la zona del dispositivo', () {
    final utc = DateTime.utc(2026, 11, 6, 14, 5);
    final local = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');

    expect(
      _status(lastSync: utc).updatedLabel,
      'ACT. ${two(local.hour)}:${two(local.minute)}',
    );
  });

  group('shellStatusProvider', () {
    ProviderContainer container({
      required Stream<ConnectivitySnapshot> connectivity,
      Stream<SyncStatus>? sync,
      Stream<DateTime?>? lastSync,
    }) {
      final container = ProviderContainer(
        overrides: [
          serviceStatusProvider.overrideWith((ref) => connectivity),
          syncStatusProvider.overrideWith(
            (ref) => sync ?? Stream.value(SyncStatus.inactiva),
          ),
          lastSyncAtProvider.overrideWith(
            (ref) => lastSync ?? Stream.value(null),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('mientras no llega nada muestra «Verificando»', () {
      final c = container(connectivity: const Stream.empty());

      expect(c.read(shellStatusProvider).title, 'Verificando');
    });

    test(
      'combina lo que publican la conectividad, la sync y la última sync',
      () async {
        final c = container(
          connectivity: Stream.value(_offline),
          lastSync: Stream.value(_lastSync),
        );
        c.listen(shellStatusProvider, (_, _) {});
        await pumpEventQueue();

        final status = c.read(shellStatusProvider);
        expect(status.led, LedState.offline);
        expect(status.subtitle, 'Datos locales · última sync 09:15');
      },
    );
  });
}

String _name(IndicatorSpec indicator) => switch (indicator.label) {
  'RED' => 'Red',
  'API' => 'API',
  _ => 'Datos',
};

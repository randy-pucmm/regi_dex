import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/integrity_auto_sync.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/core/connectivity/service_status.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/features/pokemon/data/integrity_checker.dart';

import '../core/database/database_test_helpers.dart';

/// Verificador falso: cuenta las pasadas y las aperturas de detalle.
class _FakeChecker extends Fake implements IntegrityChecker {
  var verifications = 0;
  final opened = <int>[];

  @override
  Future<IntegrityReport> verify() async {
    verifications++;
    return IntegrityReport.nothing;
  }

  @override
  Future<IntegrityReport> verifyPokemon(int pokemonId) async {
    opened.add(pokemonId);
    return IntegrityReport.nothing;
  }
}

void main() {
  late AppDatabase db;
  late StreamController<ConnectivitySnapshot> connectivity;
  late _FakeChecker checker;
  late ProviderContainer container;

  const interval = Duration(minutes: 30);

  void emit(FakeAsync async, ServiceStatus status) {
    connectivity.add(ConnectivitySnapshot(status: status));
    async.flushMicrotasks();
  }

  /// Crea el contenedor dentro de [async] para que los temporizadores sean falsos.
  void start(FakeAsync async) {
    db = createTestDatabase();
    connectivity = StreamController<ConnectivitySnapshot>();
    checker = _FakeChecker();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        serviceStatusProvider.overrideWith((ref) => connectivity.stream),
        integrityCheckerProvider.overrideWithValue(checker),
      ],
    );
    container.listen(serviceStatusProvider, (_, _) {});
    container.listen(integrityAutoSyncProvider, (_, _) {});
    async.flushMicrotasks();
  }

  void stop() {
    container.dispose();
    unawaited(connectivity.close());
  }

  test('al pasar a online verifica una vez (inicio o reconexión)', () {
    fakeAsync((async) {
      start(async);
      emit(async, ServiceStatus.online);
      emit(async, ServiceStatus.online);

      expect(checker.verifications, 1);
      stop();
    });
  });

  test('cada 30 minutos mientras siga online', () {
    fakeAsync((async) {
      start(async);
      emit(async, ServiceStatus.online);

      async.elapse(interval - const Duration(seconds: 1));
      expect(checker.verifications, 1);
      async.elapse(const Duration(seconds: 1));
      expect(checker.verifications, 2);
      async.elapse(interval);
      expect(checker.verifications, 3);
      stop();
    });
  });

  test('sin servicio no verifica ni sigue el temporizador', () {
    fakeAsync((async) {
      start(async);
      emit(async, ServiceStatus.online);
      emit(async, ServiceStatus.offline);

      async.elapse(interval * 3);

      expect(checker.verifications, 1);
      stop();
    });
  });

  test('al reconectar vuelve a verificar y reinicia el periodo', () {
    fakeAsync((async) {
      start(async);
      emit(async, ServiceStatus.online);
      emit(async, ServiceStatus.servicioNoDisponible);
      async.elapse(const Duration(minutes: 10));

      emit(async, ServiceStatus.online);
      expect(checker.verifications, 2);

      async.elapse(interval);
      expect(checker.verifications, 3);
      stop();
    });
  });

  test('con el catálogo descargándose omite la pasada', () {
    fakeAsync((async) {
      start(async);
      final gate = Completer<void>();
      unawaited(
        container
            .read(syncCoordinatorProvider)
            .run<void>('catalog', () => gate.future),
      );
      async.flushMicrotasks();

      emit(async, ServiceStatus.online);

      expect(checker.verifications, 0);
      gate.complete();
      async.flushMicrotasks();
      stop();
    });
  });
}

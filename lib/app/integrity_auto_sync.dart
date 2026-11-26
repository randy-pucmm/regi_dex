import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connectivity/service_status.dart';
import '../features/pokemon/data/catalog_sync.dart';
import 'providers.dart';

/// Cada cuánto se verifica la integridad mientras la app está abierta (OF-20).
final integrityIntervalProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 30),
);

/// Verifica la integridad del catálogo (OF-19..21) cuando el servicio pasa a
/// «online» (esto cubre el inicio y la reconexión) y luego cada
/// [integrityIntervalProvider] mientras siga online. Se omite una pasada si el
/// catálogo se está descargando, porque sus datos acaban de salir del remoto.
/// Se lanza sin esperar y nunca falla. Mientras la app esté abierta basta con
/// observarlo.
final integrityAutoSyncProvider = Provider<void>((ref) {
  Timer? periodic;

  void verify() {
    if (!ref.mounted) return;
    final catalogRunning = ref
        .read(syncCoordinatorProvider)
        .isRunning(CatalogSync.resourceKey);
    if (!catalogRunning) unawaited(ref.read(integrityCheckerProvider).verify());
  }

  ref.listen(serviceStatusProvider, (previous, next) {
    final wasOnline = previous?.value?.status == ServiceStatus.online;
    final isOnline = next.value?.status == ServiceStatus.online;
    if (isOnline && !wasOnline) {
      verify();
      periodic?.cancel();
      periodic = Timer.periodic(
        ref.read(integrityIntervalProvider),
        (_) => verify(),
      );
    } else if (!isOnline && wasOnline) {
      periodic?.cancel();
      periodic = null;
    }
  }, fireImmediately: true);

  ref.onDispose(() => periodic?.cancel());
});

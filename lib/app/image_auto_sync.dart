import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connectivity/service_status.dart';
import '../core/database/app_database.dart';
import '../core/sync/sync_coordinator.dart';
import '../features/pokemon/data/catalog_sync.dart';
import '../features/pokemon/data/image_sync.dart';
import 'providers.dart';

/// Indica si hay que lanzar ahora la descarga de imágenes. [images] y [catalog]
/// son las filas de `sync_metadata`. Una pasada fallida no se relanza aquí
/// (la reintenta el planificador con backoff) salvo que [afterReconnect] diga
/// que volvió el servicio; una pasada marcada en curso solo cuenta si ya no
/// corre ([running] false), es decir, si la app se cerró a la mitad.
bool shouldStartImageSync({
  required SyncMetadataRow? images,
  required SyncMetadataRow? catalog,
  required bool running,
  required bool afterReconnect,
}) {
  if (running || !imagesNeedSync(images, catalog)) return false;
  return images?.status != SyncMetadataStatus.failed || afterReconnect;
}

/// Descarga los sprites en segundo plano en cuanto el catálogo está completo y
/// hay servicio: en la primera corrida baja todos y solo entonces la sync se
/// presenta como completa. Se lanza sin esperar, así que no bloquea nada.
/// Mientras la app esté abierta basta con observarlo.
final imageAutoSyncProvider = Provider<void>((ref) {
  var rows = const <SyncMetadataRow>[];

  SyncMetadataRow? entry(String key) {
    for (final row in rows) {
      if (row.resourceKey == key) return row;
    }
    return null;
  }

  void evaluate({bool afterReconnect = false}) {
    final online =
        ref.read(serviceStatusProvider).value?.status == ServiceStatus.online;
    if (!online) return;
    final start = shouldStartImageSync(
      images: entry(ImageSync.resourceKey),
      catalog: entry(CatalogSync.resourceKey),
      running: ref
          .read(syncCoordinatorProvider)
          .isRunning(ImageSync.resourceKey),
      afterReconnect: afterReconnect,
    );
    if (start) unawaited(_run(ref));
  }

  final subscription = ref.watch(syncMetadataStreamProvider).listen((latest) {
    rows = latest;
    evaluate();
  });
  ref.onDispose(subscription.cancel);

  ref.listen(serviceStatusProvider, (previous, next) {
    final wasOnline = previous?.value?.status == ServiceStatus.online;
    final isOnline = next.value?.status == ServiceStatus.online;
    if (isOnline && !wasOnline) evaluate(afterReconnect: true);
  });
});

Future<void> _run(Ref ref) async {
  try {
    if (ref.mounted) await ref.read(imageSyncProvider).run();
  } catch (_) {
    // El fallo ya queda en sync_metadata y lo reintenta syncRetryProvider.
  }
}

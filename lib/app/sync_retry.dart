import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connectivity/service_status.dart';
import '../core/sync/sync_retry_scheduler.dart';
import '../features/pokemon/data/catalog_sync.dart';
import '../features/pokemon/data/detail_sync.dart';
import 'providers.dart';

/// Claves de `sync_metadata` que se reintentan solas. La referencia no está:
/// la vuelve a pedir el catálogo al reintentarse.
bool isRetryable(String resourceKey) =>
    resourceKey == CatalogSync.resourceKey ||
    resourceKey.startsWith(DetailSync.keyPrefix);

/// Reintenta solas las sincronizaciones fallidas, con el backoff y el
/// `Retry-After` que dejó el coordinador en `sync_metadata` (OF-15). Se
/// retoman al volver el servicio. Mientras la app esté abierta basta con
/// observarlo.
final syncRetryProvider = Provider<void>((ref) {
  final scheduler = SyncRetryScheduler(
    rows: ref.watch(appDatabaseProvider).syncMetadataDao.watchAll(),
    isOnline: () =>
        ref.read(serviceStatusProvider).value?.status == ServiceStatus.online,
    retry: (key) => _retry(ref, key),
    handles: isRetryable,
  )..start();
  ref.onDispose(scheduler.dispose);

  ref.listen(serviceStatusProvider, (previous, next) {
    final wasOnline = previous?.value?.status == ServiceStatus.online;
    final isOnline = next.value?.status == ServiceStatus.online;
    if (isOnline && !wasOnline) scheduler.onServiceOnline();
  });
});

Future<void> _retry(Ref ref, String key) async {
  if (!ref.mounted) return;
  if (key == CatalogSync.resourceKey) {
    await ref.read(refreshCatalogProvider)();
  } else if (key.startsWith(DetailSync.keyPrefix)) {
    final id = int.tryParse(key.substring(DetailSync.keyPrefix.length));
    if (id != null) await ref.read(detailSyncProvider).sync(id, force: true);
  }
}

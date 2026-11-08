import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connectivity/service_status.dart';
import '../core/database/app_database.dart';
import '../core/sync/sync_coordinator.dart';
import '../features/pokemon/data/catalog_sync.dart';
import 'providers.dart';

/// Indica si el catálogo hay que sincronizarlo: nunca se completó una pasada,
/// la última quedó a medias o fallida, o ya pasaron más de
/// [CatalogSync.catalogMaxAge] desde la última exitosa (PS-03).
/// [entry] es la fila `catalog` de `sync_metadata`, o null si no existe.
bool catalogNeedsSync(SyncMetadataRow? entry, DateTime now) {
  if (entry == null) return true;
  final lastSuccess = entry.lastSuccessAt;
  return entry.status != SyncMetadataStatus.completed ||
      entry.cursorOffset > 0 ||
      lastSuccess == null ||
      now.difference(lastSuccess) >= CatalogSync.catalogMaxAge;
}

/// Sincroniza el catálogo al arrancar y cada vez que el servicio pasa a
/// «online» (PS-04), si hace falta. Se lanza sin esperar, así que no bloquea
/// el arranque (OF-03). Mientras la app esté abierta basta con observarlo.
final catalogAutoSyncProvider = Provider<void>((ref) {
  ref.listen(serviceStatusProvider, (previous, next) {
    final wasOnline = previous?.value?.status == ServiceStatus.online;
    final isOnline = next.value?.status == ServiceStatus.online;
    if (isOnline && !wasOnline) unawaited(_syncIfNeeded(ref));
  }, fireImmediately: true);
});

Future<void> _syncIfNeeded(Ref ref) async {
  try {
    final entry = await ref
        .read(appDatabaseProvider)
        .syncMetadataDao
        .getEntry(CatalogSync.resourceKey);
    if (!ref.mounted || !catalogNeedsSync(entry, clock.now())) return;
    await ref.read(refreshCatalogProvider)();
  } catch (_) {
    // Un fallo ya queda en sync_metadata (intentos y próximo reintento) y la
    // interfaz sigue sirviendo la base local; el reintento llega con RD-28.
  }
}

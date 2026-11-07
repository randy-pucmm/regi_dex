import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sync_tables.dart';

part 'sync_metadata_dao.g.dart';

/// Acceso al estado de sincronización por recurso.
@DriftAccessor(tables: [SyncMetadataEntries])
class SyncMetadataDao extends DatabaseAccessor<AppDatabase>
    with _$SyncMetadataDaoMixin {
  SyncMetadataDao(super.attachedDatabase);

  /// Estado de [resourceKey], o null si nunca se sincronizó.
  Future<SyncMetadataRow?> getEntry(String resourceKey) => (select(
    syncMetadataEntries,
  )..where((e) => e.resourceKey.equals(resourceKey))).getSingleOrNull();

  /// Estado de [resourceKey] como flujo.
  Stream<SyncMetadataRow?> watchEntry(String resourceKey) => (select(
    syncMetadataEntries,
  )..where((e) => e.resourceKey.equals(resourceKey))).watchSingleOrNull();

  /// Estado de todos los recursos.
  Stream<List<SyncMetadataRow>> watchAll() =>
      select(syncMetadataEntries).watch();

  /// Inserta o actualiza el estado de un recurso por su `resourceKey`.
  Future<void> upsert(SyncMetadataEntriesCompanion entry) =>
      into(syncMetadataEntries).insertOnConflictUpdate(entry);

  /// Guarda [offset] como cursor confirmado de [resourceKey] sin tocar el resto
  /// de la fila. Devuelve false si el recurso aún no tiene fila (la crea el
  /// `SyncCoordinator` al empezar), en cuyo caso no cambia nada.
  Future<bool> advanceCursor(String resourceKey, int offset) async {
    final updated =
        await (update(syncMetadataEntries)
              ..where((e) => e.resourceKey.equals(resourceKey)))
            .write(SyncMetadataEntriesCompanion(cursorOffset: Value(offset)));
    return updated > 0;
  }
}

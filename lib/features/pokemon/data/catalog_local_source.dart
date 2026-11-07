import 'package:clock/clock.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_coordinator.dart';
import 'pokemon_mapper.dart';

/// Escritura y lectura del catálogo en Drift para la sincronización.
class CatalogLocalSource {
  CatalogLocalSource(this._db);

  final AppDatabase _db;

  /// Indica si la referencia se sincronizó con éxito hace menos de [maxAge].
  Future<bool> isReferenceFresh(String resourceKey, Duration maxAge) async {
    final entry = await _db.syncMetadataDao.getEntry(resourceKey);
    final lastSuccess = entry?.lastSuccessAt;
    return entry?.status == SyncMetadataStatus.completed &&
        lastSuccess != null &&
        clock.now().difference(lastSuccess) < maxAge;
  }

  /// Cursor confirmado de [resourceKey]: el offset desde el cual reanudar.
  /// Es 0 si nunca se sincronizó o si la última pasada terminó completa.
  Future<int> readCursor(String resourceKey) async =>
      (await _db.syncMetadataDao.getEntry(resourceKey))?.cursorOffset ?? 0;

  /// Guarda los datos de referencia en una sola transacción.
  Future<void> saveReference(ReferenceRecords records) =>
      _db.referenceDao.upsertReferenceData(
        generations: records.generations,
        types: records.types,
        eggGroups: records.eggGroups,
        abilities: records.abilities,
        moves: records.moves,
        versionGroups: records.versionGroups,
        typeEfficacies: records.typeEfficacies,
      );

  /// Guarda un lote de Pokémon y mueve el cursor de [resourceKey] a
  /// [nextOffset] en **una sola transacción** (PS-07): si algo falla no queda
  /// nada del lote y el cursor sigue donde estaba. Lanza [StateError] si el
  /// recurso no tiene fila en `sync_metadata`, porque la crea el coordinador.
  Future<void> saveBatch(
    String resourceKey,
    List<PokemonRecord> records, {
    required int nextOffset,
  }) {
    return _db.transaction(() async {
      for (final record in records) {
        await _db.catalogDao.upsertSpecies(record.species);
        await _db.catalogDao.replaceSpeciesEggGroups(
          record.species.id.value,
          record.eggGroupIds,
        );
        await _db.catalogDao.upsertPokemon(
          record.pokemon,
          types: record.types,
          stats: record.stats,
          abilities: record.abilities,
        );
      }
      final moved = await _db.syncMetadataDao.advanceCursor(
        resourceKey,
        nextOffset,
      );
      if (!moved) {
        throw StateError('Sin fila en sync_metadata para $resourceKey');
      }
    });
  }
}

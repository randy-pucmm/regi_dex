import 'package:clock/clock.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_coordinator.dart';
import 'content_hash.dart';
import 'pokemon_detail_mapper.dart';
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

  /// Pokémon del catálogo con ese id, o null si no está.
  Future<PokemonRow?> readPokemon(int id) => _db.catalogDao.getPokemon(id);

  /// `content_hash` recalculado desde las filas locales de [id] (OF-19), o null
  /// si el Pokémon no está en el catálogo. No usa el hash guardado, así que
  /// detecta también filas alteradas en el dispositivo.
  Future<String?> localContentHash(int id) async {
    final pokemon = await _db.catalogDao.getPokemon(id);
    if (pokemon == null) return null;
    final types = await _db.catalogDao.typesOf(id);
    final stats = await _db.catalogDao.statsOf(id);
    final abilities = await _db.catalogDao.abilitiesOf(id);
    return computeContentHash(
      name: pokemon.name,
      height: pokemon.height,
      weight: pokemon.weight,
      types: [for (final t in types) (slot: t.slot, typeId: t.typeId)],
      abilities: [
        for (final a in abilities)
          (slot: a.slot, abilityId: a.abilityId, isHidden: a.isHidden),
      ],
      stats: [for (final s in stats) (statId: s.statId, baseStat: s.baseStat)],
    );
  }

  /// Guarda el detalle completo de un Pokémon en **una sola transacción**
  /// (PS-07, todo o nada): si algo falla no queda nada del detalle. Reemplaza
  /// tipos, stats, habilidades, movimientos, variantes y cadena evolutiva, y
  /// completa los textos en español de la especie y de las habilidades.
  Future<void> saveDetail(PokemonDetailRecord record) {
    return _db.transaction(() async {
      final dao = _db.catalogDao;
      await dao.upsertSpecies(record.species);
      await dao.replaceSpeciesEggGroups(
        record.species.id.value,
        record.eggGroupIds,
      );
      await dao.upsertAbilities(record.abilityRows);
      await dao.upsertPokemon(
        record.pokemon,
        types: record.types,
        stats: record.stats,
        abilities: record.abilities,
      );
      await dao.replacePokemonMoves(record.pokemon.id.value, record.moves);
      await dao.replaceSpeciesForms(record.species.id.value, record.forms);
      final chainId = record.evolutionChainId;
      if (chainId != null) {
        await dao.replaceEvolutionChain(chainId, record.evolutions);
      }
    });
  }

  /// Guarda [records] en una sola transacción sin tocar ningún cursor: es para
  /// Pokémon sueltos, como los resultados de una búsqueda remota. Es idempotente
  /// (upsert por clave primaria) y el siguiente paso del catálogo los reescribe.
  Future<void> savePokemon(List<PokemonRecord> records) =>
      _db.transaction(() => _upsertAll(records));

  Future<void> _upsertAll(List<PokemonRecord> records) async {
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
  }

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
      await _upsertAll(records);
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

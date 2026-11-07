import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import 'content_hash.dart';
import 'dto/pokemon_light_dto.dart';
import 'dto/reference_data_dto.dart';

// Funciones puras de DTO a filas. Solo reciben y devuelven datos simples, así
// que se pueden ejecutar dentro de `Isolate.run` sin cerrar sobre la BD.

/// Datos de referencia listos para `ReferenceDao.upsertReferenceData`.
class ReferenceRecords {
  const ReferenceRecords({
    required this.generations,
    required this.types,
    required this.eggGroups,
    required this.abilities,
    required this.moves,
    required this.versionGroups,
    required this.typeEfficacies,
    required this.totalPokemon,
  });

  final List<GenerationsCompanion> generations;
  final List<TypesCompanion> types;
  final List<EggGroupsCompanion> eggGroups;
  final List<AbilitiesCompanion> abilities;
  final List<MovesCompanion> moves;
  final List<VersionGroupsCompanion> versionGroups;
  final List<TypeEfficaciesCompanion> typeEfficacies;

  /// Total de Pokémon por defecto que informa la API.
  final int totalPokemon;
}

/// Un Pokémon del catálogo con su especie y relaciones, listo para guardarse.
class PokemonRecord {
  const PokemonRecord({
    required this.species,
    required this.eggGroupIds,
    required this.pokemon,
    required this.types,
    required this.stats,
    required this.abilities,
  });

  final SpeciesCompanion species;
  final List<int> eggGroupIds;
  final PokemonsCompanion pokemon;
  final List<({int slot, int typeId})> types;
  final List<({int statId, int baseStat})> stats;
  final List<({int slot, int abilityId, bool isHidden})> abilities;
}

/// Valida y convierte el `data` de GetReferenceData a filas.
/// Lanza `ValidationFailure` si la respuesta no cumple el formato.
ReferenceRecords mapReferenceData(Map<String, dynamic> data) {
  final dto = ReferenceDataDto.fromData(data);
  return ReferenceRecords(
    generations: [
      for (final g in dto.generations)
        GenerationsCompanion.insert(
          id: Value(g.id),
          name: g.name,
          region: Value(g.region),
        ),
    ],
    types: [
      for (final t in dto.types)
        TypesCompanion.insert(
          id: Value(t.id),
          name: t.name,
          nameEs: Value(t.nameEs),
        ),
    ],
    eggGroups: [
      for (final g in dto.eggGroups)
        EggGroupsCompanion.insert(
          id: Value(g.id),
          name: g.name,
          nameEs: Value(g.nameEs),
        ),
    ],
    abilities: [
      for (final a in dto.abilities)
        AbilitiesCompanion.insert(id: Value(a.id), name: a.name),
    ],
    moves: [
      for (final m in dto.moves)
        MovesCompanion.insert(
          id: Value(m.id),
          name: m.name,
          typeId: Value(m.typeId),
          power: Value(m.power),
          accuracy: Value(m.accuracy),
          pp: Value(m.pp),
          priority: Value(m.priority),
          damageClassId: Value(m.damageClassId),
        ),
    ],
    versionGroups: [
      for (final v in dto.versionGroups)
        VersionGroupsCompanion.insert(
          id: Value(v.id),
          name: v.name,
          generationId: Value(v.generationId),
        ),
    ],
    typeEfficacies: [
      for (final e in dto.typeEfficacies)
        TypeEfficaciesCompanion.insert(
          attackingTypeId: e.attackingTypeId,
          defendingTypeId: e.defendingTypeId,
          factor: e.factor,
        ),
    ],
    totalPokemon: dto.totalPokemon,
  );
}

/// Valida y convierte el `data` de GetPokemonPage a registros, con el
/// `content_hash` de cada uno. [syncedAt] se pasa de fuera porque el reloj
/// inyectable no cruza isolates. Si un elemento es inválido lanza
/// `ValidationFailure` y no devuelve ninguno.
List<PokemonRecord> mapPokemonPage(
  Map<String, dynamic> data,
  DateTime syncedAt,
) {
  return [
    for (final dto in PokemonLightDto.listFromData(data))
      _mapPokemon(dto, syncedAt),
  ];
}

PokemonRecord _mapPokemon(PokemonLightDto dto, DateTime syncedAt) {
  final types = [for (final t in dto.types) (slot: t.slot, typeId: t.typeId)];
  final stats = [
    for (final s in dto.stats) (statId: s.statId, baseStat: s.baseStat),
  ];
  final abilities = [
    for (final a in dto.abilities)
      (slot: a.slot, abilityId: a.abilityId, isHidden: a.isHidden),
  ];
  return PokemonRecord(
    species: SpeciesCompanion.insert(
      id: Value(dto.speciesId),
      name: dto.species.name,
      generationId: dto.species.generationId,
      evolutionChainId: Value(dto.species.evolutionChainId),
      isLegendary: Value(dto.species.isLegendary),
      isMythical: Value(dto.species.isMythical),
    ),
    eggGroupIds: dto.species.eggGroupIds,
    pokemon: PokemonsCompanion.insert(
      id: Value(dto.id),
      speciesId: dto.speciesId,
      name: dto.name,
      height: Value(dto.height),
      weight: Value(dto.weight),
      baseStatTotal: Value(dto.baseStatTotal),
      spriteUrl: Value(dto.spriteUrl),
      artworkUrl: Value(dto.artworkUrl),
      contentHash: Value(
        computeContentHash(
          name: dto.name,
          height: dto.height,
          weight: dto.weight,
          types: types,
          abilities: abilities,
          stats: stats,
        ),
      ),
      lightSyncedAt: syncedAt,
    ),
    types: types,
    stats: stats,
    abilities: abilities,
  );
}

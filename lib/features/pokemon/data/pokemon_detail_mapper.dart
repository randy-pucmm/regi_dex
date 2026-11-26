import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import 'content_hash.dart';
import 'dto/pokemon_detail_dto.dart';
import 'dto/pokemon_light_dto.dart';

// Funciones puras de DTO a filas para el detalle. Solo reciben y devuelven datos
// simples, así que se pueden ejecutar dentro de `Isolate.run`.

/// Detalle de un Pokémon listo para guardarse en una sola transacción.
class PokemonDetailRecord {
  const PokemonDetailRecord({
    required this.species,
    required this.eggGroupIds,
    required this.pokemon,
    required this.types,
    required this.stats,
    required this.abilities,
    required this.abilityRows,
    required this.moves,
    required this.forms,
    required this.evolutions,
    required this.contentHash,
    this.evolutionChainId,
  });

  final SpeciesCompanion species;
  final List<int> eggGroupIds;
  final PokemonsCompanion pokemon;
  final List<({int slot, int typeId})> types;
  final List<({int statId, int baseStat})> stats;
  final List<({int slot, int abilityId, bool isHidden})> abilities;

  /// Habilidades del Pokémon con su texto en español, para completar `ability`.
  final List<AbilitiesCompanion> abilityRows;
  final List<PokemonMovesCompanion> moves;
  final List<PokemonFormsCompanion> forms;

  /// Cadena evolutiva de la especie; vacía (y sin id) si no tiene.
  final int? evolutionChainId;
  final List<EvolutionsCompanion> evolutions;

  /// `content_hash` calculado con los datos remotos, para compararlo con el local.
  final String contentHash;
}

/// Valida y convierte el `data` de GetPokemonDetail. [syncedAt] se pasa de fuera
/// porque el reloj inyectable no cruza isolates. Lanza `ValidationFailure` si la
/// respuesta no cumple el formato y no devuelve nada.
PokemonDetailRecord mapPokemonDetail(
  Map<String, dynamic> data,
  DateTime syncedAt,
) {
  final dto = PokemonDetailDto.fromData(data);
  final types = [for (final t in dto.types) (slot: t.slot, typeId: t.typeId)];
  final stats = [
    for (final s in dto.stats) (statId: s.statId, baseStat: s.baseStat),
  ];
  final abilities = [
    for (final a in dto.abilities)
      (slot: a.slot, abilityId: a.abilityId, isHidden: a.isHidden),
  ];
  final hash = computeContentHash(
    name: dto.name,
    height: dto.height,
    weight: dto.weight,
    types: types,
    abilities: abilities,
    stats: stats,
  );
  final species = dto.species;

  return PokemonDetailRecord(
    species: SpeciesCompanion.insert(
      id: Value(species.id),
      name: species.name,
      generationId: species.generationId,
      evolutionChainId: Value(species.evolutionChainId),
      isLegendary: Value(species.isLegendary),
      isMythical: Value(species.isMythical),
      nameEs: Value(species.nameEs),
      genusEs: Value(species.genusEs),
    ),
    eggGroupIds: species.eggGroupIds,
    pokemon: PokemonsCompanion.insert(
      id: Value(dto.id),
      speciesId: species.id,
      name: dto.name,
      isDefault: Value(dto.isDefault),
      height: Value(dto.height),
      weight: Value(dto.weight),
      baseStatTotal: Value(dto.baseStatTotal),
      spriteUrl: Value(dto.spriteUrl),
      artworkUrl: Value(dto.artworkUrl),
      spriteShinyUrl: Value(dto.spriteShinyUrl),
      artworkShinyUrl: Value(dto.artworkShinyUrl),
      contentHash: Value(hash),
      // El detalle trae todos los campos del catálogo ligero.
      lightSyncedAt: syncedAt,
      detailSyncedAt: Value(syncedAt),
    ),
    types: types,
    stats: stats,
    abilities: abilities,
    abilityRows: [
      for (final a in dto.abilities)
        AbilitiesCompanion.insert(
          id: Value(a.abilityId),
          name: a.name,
          nameEs: Value(a.nameEs),
          shortEffect: Value(a.shortEffect),
        ),
    ],
    moves: _mapMoves(dto),
    forms: [
      for (final v in species.variants)
        PokemonFormsCompanion.insert(
          pokemonId: Value(v.id),
          speciesId: species.id,
          name: v.name,
          formName: Value(v.formName),
          isDefault: Value(v.isDefault),
          isMega: Value(v.isMega),
          type1Id: Value(_typeAt(v.types, 1)),
          type2Id: Value(_typeAt(v.types, 2)),
        ),
    ],
    evolutionChainId: species.evolutionChainId,
    evolutions: [
      if (species.evolutionChainId != null)
        for (final e in species.evolutions)
          EvolutionsCompanion.insert(
            chainId: species.evolutionChainId!,
            toSpeciesId: e.toSpeciesId,
            toSpeciesName: e.toSpeciesName,
            fromSpeciesId: Value(e.fromSpeciesId),
            trigger: Value(e.trigger),
            minLevel: Value(e.minLevel),
            minHappiness: Value(e.minHappiness),
            timeOfDay: Value(e.timeOfDay),
            item: Value(e.item),
          ),
    ],
    contentHash: hash,
  );
}

/// Movimientos sin repetir la clave primaria (la API puede repetir filas).
List<PokemonMovesCompanion> _mapMoves(PokemonDetailDto dto) {
  final seen = <String>{};
  return [
    for (final m in dto.moves)
      if (seen.add(
        '${m.moveId}:${m.versionGroupId}:${m.learnMethodId}:${m.level}',
      ))
        PokemonMovesCompanion.insert(
          pokemonId: dto.id,
          moveId: m.moveId,
          versionGroupId: m.versionGroupId,
          learnMethodId: m.learnMethodId,
          level: Value(m.level),
        ),
  ];
}

/// Id del tipo del slot [slot], o null si la variante no lo tiene.
int? _typeAt(List<PokemonTypeSlotDto> types, int slot) {
  for (final type in types) {
    if (type.slot == slot) return type.typeId;
  }
  return null;
}

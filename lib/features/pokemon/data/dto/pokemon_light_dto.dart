import 'json_reader.dart';

/// Pokémon del catálogo ligero (fragmento `PokemonLight`), usado por
/// GetPokemonPage, GetPokemonsByIds y SearchPokemonRemote.
class PokemonLightDto {
  const PokemonLightDto({
    required this.id,
    required this.name,
    required this.height,
    required this.weight,
    required this.speciesId,
    required this.species,
    required this.types,
    required this.abilities,
    required this.stats,
    this.spriteUrl,
    this.artworkUrl,
  });

  /// Valida y convierte un objeto `pokemon` de la respuesta.
  /// Lanza [ValidationFailure] si falta un campo o tiene otro tipo.
  factory PokemonLightDto.fromJson(Map<String, dynamic> json) {
    final reader = JsonReader(json, 'pokemon');
    final sprites = reader.objects('pokemonsprites');
    return PokemonLightDto(
      id: reader.integer('id'),
      name: reader.string('name'),
      height: reader.integerOrNull('height') ?? 0,
      weight: reader.integerOrNull('weight') ?? 0,
      speciesId: reader.integer('pokemon_species_id'),
      species: SpeciesLightDto._fromReader(reader.object('pokemonspecy')),
      types: [
        for (final type in reader.objects('pokemontypes'))
          PokemonTypeSlotDto(
            slot: type.integer('slot'),
            typeId: type.integer('type_id'),
          ),
      ],
      abilities: [
        for (final ability in reader.objects('pokemonabilities'))
          PokemonAbilitySlotDto(
            slot: ability.integer('slot'),
            abilityId: ability.integer('ability_id'),
            isHidden: ability.boolean('is_hidden'),
          ),
      ],
      stats: [
        for (final stat in reader.objects('pokemonstats'))
          PokemonStatDto(
            statId: stat.integer('stat_id'),
            baseStat: stat.integer('base_stat'),
          ),
      ],
      spriteUrl: sprites.isEmpty ? null : sprites.first.stringOrNull('front'),
      artworkUrl: sprites.isEmpty
          ? null
          : sprites.first.stringOrNull('artwork'),
    );
  }

  /// Lee la lista `pokemon` del `data` de una respuesta. Si algún elemento es
  /// inválido lanza [ValidationFailure] y no devuelve ninguno.
  static List<PokemonLightDto> listFromData(Map<String, dynamic> data) => [
    for (final item in JsonReader(data, 'data').objects('pokemon'))
      PokemonLightDto.fromJson(item.json),
  ];

  final int id;
  final String name;
  final int height;
  final int weight;
  final int speciesId;
  final SpeciesLightDto species;
  final List<PokemonTypeSlotDto> types;
  final List<PokemonAbilitySlotDto> abilities;
  final List<PokemonStatDto> stats;
  final String? spriteUrl;
  final String? artworkUrl;

  /// Suma de las estadísticas base.
  int get baseStatTotal => stats.fold(0, (sum, stat) => sum + stat.baseStat);
}

/// Datos de la especie incluidos en el catálogo ligero.
class SpeciesLightDto {
  const SpeciesLightDto({
    required this.name,
    required this.generationId,
    required this.eggGroupIds,
    this.evolutionChainId,
    this.isLegendary = false,
    this.isMythical = false,
  });

  factory SpeciesLightDto._fromReader(JsonReader reader) => SpeciesLightDto(
    name: reader.string('name'),
    generationId: reader.integer('generation_id'),
    evolutionChainId: reader.integerOrNull('evolution_chain_id'),
    isLegendary: reader.boolean('is_legendary'),
    isMythical: reader.boolean('is_mythical'),
    eggGroupIds: [
      for (final group in reader.objects('pokemonegggroups'))
        group.integer('egg_group_id'),
    ],
  );

  /// Nombre de la especie (puede diferir del de la forma, p. ej. `deoxys`).
  final String name;
  final int generationId;
  final int? evolutionChainId;
  final bool isLegendary;
  final bool isMythical;
  final List<int> eggGroupIds;
}

class PokemonTypeSlotDto {
  const PokemonTypeSlotDto({required this.slot, required this.typeId});

  final int slot;
  final int typeId;
}

class PokemonAbilitySlotDto {
  const PokemonAbilitySlotDto({
    required this.slot,
    required this.abilityId,
    required this.isHidden,
  });

  final int slot;
  final int abilityId;
  final bool isHidden;
}

class PokemonStatDto {
  const PokemonStatDto({required this.statId, required this.baseStat});

  final int statId;
  final int baseStat;
}

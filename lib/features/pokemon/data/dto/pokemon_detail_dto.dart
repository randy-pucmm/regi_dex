import '../../../../core/error/failure.dart';
import 'json_reader.dart';
import 'pokemon_light_dto.dart';

/// Detalle completo de un Pokémon (respuesta de GetPokemonDetail): identidad,
/// stats, habilidades, movimientos, sprites, especie, variantes y cadena
/// evolutiva, todo en una sola respuesta.
class PokemonDetailDto {
  const PokemonDetailDto({
    required this.id,
    required this.name,
    required this.height,
    required this.weight,
    required this.types,
    required this.stats,
    required this.abilities,
    required this.moves,
    required this.species,
    this.spriteUrl,
    this.spriteShinyUrl,
    this.artworkUrl,
    this.artworkShinyUrl,
  });

  /// Valida y convierte el `data` de GetPokemonDetail. Lanza [ValidationFailure]
  /// si el Pokémon no existe o si falta un campo o tiene otro tipo.
  factory PokemonDetailDto.fromData(Map<String, dynamic> data) {
    final items = JsonReader(data, 'data').objects('pokemon');
    if (items.isEmpty) {
      throw const ValidationFailure('data.pokemon: el Pokémon no existe');
    }
    final reader = items.first;
    final sprites = reader.objects('pokemonsprites');
    final sprite = sprites.isEmpty ? null : sprites.first;
    return PokemonDetailDto(
      id: reader.integer('id'),
      name: reader.string('name'),
      height: reader.integerOrNull('height') ?? 0,
      weight: reader.integerOrNull('weight') ?? 0,
      types: [
        for (final type in reader.objects('pokemontypes'))
          PokemonTypeSlotDto(
            slot: type.integer('slot'),
            typeId: type.integer('type_id'),
          ),
      ],
      stats: [
        for (final stat in reader.objects('pokemonstats'))
          PokemonStatDto(
            statId: stat.integer('stat_id'),
            baseStat: stat.integer('base_stat'),
          ),
      ],
      abilities: [
        for (final slot in reader.objects('pokemonabilities'))
          DetailAbilityDto._fromReader(slot),
      ],
      moves: [
        for (final move in reader.objects('pokemonmoves'))
          PokemonMoveDto(
            moveId: move.integer('move_id'),
            level: move.integerOrNull('level') ?? 0,
            learnMethodId: move.integer('move_learn_method_id'),
            versionGroupId: move.integer('version_group_id'),
          ),
      ],
      species: DetailSpeciesDto._fromReader(reader.object('pokemonspecy')),
      spriteUrl: sprite?.stringOrNull('front'),
      spriteShinyUrl: sprite?.stringOrNull('front_shiny'),
      artworkUrl: sprite?.stringOrNull('artwork'),
      artworkShinyUrl: sprite?.stringOrNull('artwork_shiny'),
    );
  }

  final int id;
  final String name;
  final int height;
  final int weight;
  final List<PokemonTypeSlotDto> types;
  final List<PokemonStatDto> stats;
  final List<DetailAbilityDto> abilities;
  final List<PokemonMoveDto> moves;
  final DetailSpeciesDto species;
  final String? spriteUrl;
  final String? spriteShinyUrl;
  final String? artworkUrl;
  final String? artworkShinyUrl;

  /// Suma de las estadísticas base.
  int get baseStatTotal => stats.fold(0, (sum, stat) => sum + stat.baseStat);
}

/// Habilidad de un slot con sus textos en español, si los hay.
class DetailAbilityDto {
  const DetailAbilityDto({
    required this.slot,
    required this.abilityId,
    required this.name,
    required this.isHidden,
    this.nameEs,
    this.shortEffect,
  });

  factory DetailAbilityDto._fromReader(JsonReader slot) {
    final ability = slot.object('ability');
    return DetailAbilityDto(
      slot: slot.integer('slot'),
      abilityId: ability.integer('id'),
      name: ability.string('name'),
      isHidden: slot.boolean('is_hidden'),
      nameEs: ability.localizedName('abilitynames', 'es'),
      // Si no hay efecto en español se usa el inglés.
      shortEffect:
          ability.localized('abilityeffecttexts', 'short_effect', 'es') ??
          ability.localized('abilityeffecttexts', 'short_effect', 'en'),
    );
  }

  final int slot;
  final int abilityId;
  final String name;
  final bool isHidden;
  final String? nameEs;
  final String? shortEffect;
}

class PokemonMoveDto {
  const PokemonMoveDto({
    required this.moveId,
    required this.level,
    required this.learnMethodId,
    required this.versionGroupId,
  });

  final int moveId;
  final int level;
  final int learnMethodId;
  final int versionGroupId;
}

/// Especie del detalle, con sus variantes y su cadena evolutiva.
class DetailSpeciesDto {
  const DetailSpeciesDto({
    required this.id,
    required this.name,
    required this.generationId,
    required this.isLegendary,
    required this.isMythical,
    required this.eggGroupIds,
    required this.variants,
    required this.evolutions,
    this.nameEs,
    this.genusEs,
    this.evolutionChainId,
  });

  factory DetailSpeciesDto._fromReader(JsonReader reader) {
    final chain = reader.objectOrNull('evolutionchain');
    return DetailSpeciesDto(
      id: reader.integer('id'),
      name: reader.string('name'),
      generationId: reader.integer('generation_id'),
      isLegendary: reader.boolean('is_legendary'),
      isMythical: reader.boolean('is_mythical'),
      eggGroupIds: [
        for (final group in reader.objects('pokemonegggroups'))
          group.integer('egg_group_id'),
      ],
      nameEs: reader.localizedName('pokemonspeciesnames', 'es'),
      genusEs: reader.localized('pokemonspeciesnames', 'genus', 'es'),
      variants: [
        for (final variant in reader.objects('pokemons'))
          DetailVariantDto._fromReader(variant),
      ],
      evolutionChainId: chain?.integer('id'),
      evolutions: chain == null
          ? const []
          : [
              for (final step in chain.objects('pokemonspecies'))
                ..._evolutionSteps(step),
            ],
    );
  }

  final int id;
  final String name;
  final int generationId;
  final bool isLegendary;
  final bool isMythical;
  final List<int> eggGroupIds;
  final String? nameEs;
  final String? genusEs;
  final List<DetailVariantDto> variants;
  final int? evolutionChainId;

  /// Pasos de la cadena en su orden. Una especie sin condiciones (la base)
  /// aparece una vez; con varias condiciones, una fila por condición.
  final List<EvolutionStepDto> evolutions;
}

/// Convierte una especie de la cadena en uno o más pasos (uno por condición).
List<EvolutionStepDto> _evolutionSteps(JsonReader species) {
  final toSpeciesId = species.integer('id');
  final toSpeciesName = species.string('name');
  final fromSpeciesId = species.integerOrNull('evolves_from_species_id');
  final conditions = species.objects('pokemonevolutions');
  if (conditions.isEmpty) {
    return [
      EvolutionStepDto(
        toSpeciesId: toSpeciesId,
        toSpeciesName: toSpeciesName,
        fromSpeciesId: fromSpeciesId,
      ),
    ];
  }
  return [
    for (final condition in conditions)
      EvolutionStepDto(
        toSpeciesId: toSpeciesId,
        toSpeciesName: toSpeciesName,
        fromSpeciesId: fromSpeciesId,
        trigger: condition
            .objectOrNull('evolutiontrigger')
            ?.stringOrNull('name'),
        minLevel: condition.integerOrNull('min_level'),
        minHappiness: condition.integerOrNull('min_happiness'),
        timeOfDay: _nonEmpty(condition.stringOrNull('time_of_day')),
        item: condition.objectOrNull('item')?.stringOrNull('name'),
      ),
  ];
}

class EvolutionStepDto {
  const EvolutionStepDto({
    required this.toSpeciesId,
    required this.toSpeciesName,
    this.fromSpeciesId,
    this.trigger,
    this.minLevel,
    this.minHappiness,
    this.timeOfDay,
    this.item,
  });

  final int toSpeciesId;
  final String toSpeciesName;
  final int? fromSpeciesId;
  final String? trigger;
  final int? minLevel;
  final int? minHappiness;
  final String? timeOfDay;
  final String? item;
}

/// Variante o forma de la especie (megaevolución, regional, etc.).
class DetailVariantDto {
  const DetailVariantDto({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.isMega,
    required this.types,
    this.formName,
  });

  factory DetailVariantDto._fromReader(JsonReader reader) {
    final forms = reader.objects('pokemonforms');
    return DetailVariantDto(
      id: reader.integer('id'),
      name: reader.string('name'),
      isDefault: reader.boolean('is_default'),
      isMega: forms.any((form) => form.boolean('is_mega')),
      formName: forms.isEmpty
          ? null
          : _nonEmpty(forms.first.stringOrNull('form_name')),
      types: [
        for (final type in reader.objects('pokemontypes'))
          PokemonTypeSlotDto(
            slot: type.integer('slot'),
            typeId: type.integer('type_id'),
          ),
      ],
    );
  }

  final int id;
  final String name;
  final bool isDefault;
  final bool isMega;
  final String? formName;
  final List<PokemonTypeSlotDto> types;
}

String? _nonEmpty(String? value) =>
    (value == null || value.isEmpty) ? null : value;

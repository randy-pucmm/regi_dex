import '../../../core/error/failure.dart';
import 'dto/json_reader.dart';

typedef AbilityText = ({int id, String? nameEs, String? shortEffect});
typedef EvolutionRecord = ({
  int speciesId,
  int fromSpeciesId,
  int ordinal,
  String? trigger,
  int? minLevel,
  int? minHappiness,
  String? timeOfDay,
  String? itemName,
});
typedef MoveLearn = ({int moveId, int versionGroupId, int methodId, int level});

/// Lo que trae GetPokemonDetail y la base aún no tenía.
class PokemonDetailRecord {
  const PokemonDetailRecord({
    required this.pokemonId,
    required this.speciesId,
    required this.abilities,
    required this.moves,
    required this.chainSpeciesIds,
    required this.evolutions,
    this.speciesNameEs,
    this.genusEs,
  });

  final int pokemonId;
  final int speciesId;
  final String? speciesNameEs;
  final String? genusEs;
  final List<AbilityText> abilities;
  final List<MoveLearn> moves;

  /// Especies de la cadena evolutiva, con o sin condición.
  final List<int> chainSpeciesIds;
  final List<EvolutionRecord> evolutions;
}

/// Valida el `data` de GetPokemonDetail. Lanza [ValidationFailure] si no
/// trae el Pokémon o le falta un campo.
PokemonDetailRecord mapPokemonDetail(Map<String, dynamic> data) {
  final pokemon = JsonReader(data, 'data').objects('pokemon');
  if (pokemon.isEmpty) {
    throw const ValidationFailure('data.pokemon: el Pokémon no existe');
  }
  final reader = pokemon.first;
  final species = reader.object('pokemonspecy');
  final names = species.objects('pokemonspeciesnames');
  final spanish = names
      .where((n) => n.object('language').string('name') == 'es')
      .firstOrNull;
  return PokemonDetailRecord(
    pokemonId: reader.integer('id'),
    speciesId: species.integer('id'),
    speciesNameEs: spanish?.string('name'),
    genusEs: spanish?.stringOrNull('genus'),
    abilities: [
      for (final slot in reader.objects('pokemonabilities'))
        _abilityText(slot.object('ability')),
    ],
    chainSpeciesIds: [
      for (final member in _chain(species)) member.integer('id'),
    ],
    evolutions: _evolutions(species),
    moves: [
      for (final move in reader.objects('pokemonmoves'))
        (
          moveId: move.integer('move_id'),
          versionGroupId: move.integer('version_group_id'),
          methodId: move.integer('move_learn_method_id'),
          level: move.integerOrNull('level') ?? 0,
        ),
    ],
  );
}

AbilityText _abilityText(JsonReader ability) {
  String? effectIn(String language) => ability
      .objects('abilityeffecttexts')
      .where((e) => e.object('language').string('name') == language)
      .map((e) => e.string('short_effect'))
      .firstOrNull;

  return (
    id: ability.integer('id'),
    nameEs: ability.localizedName('abilitynames', 'es'),
    shortEffect: effectIn('es') ?? effectIn('en'),
  );
}

JsonReader? _optionalObject(JsonReader reader, String key) =>
    reader.json[key] is Map<String, dynamic> ? reader.object(key) : null;

List<JsonReader> _chain(JsonReader species) =>
    _optionalObject(species, 'evolutionchain')?.objects('pokemonspecies') ??
    const [];

List<EvolutionRecord> _evolutions(JsonReader species) {
  final records = <EvolutionRecord>[];
  for (final member in _chain(species)) {
    final from = member.integerOrNull('evolves_from_species_id');
    if (from == null) continue;
    final steps = member.objects('pokemonevolutions');
    if (steps.isEmpty) {
      records.add((
        speciesId: member.integer('id'),
        fromSpeciesId: from,
        ordinal: 0,
        trigger: null,
        minLevel: null,
        minHappiness: null,
        timeOfDay: null,
        itemName: null,
      ));
    }
    for (final (index, step) in steps.indexed) {
      final timeOfDay = step.stringOrNull('time_of_day');
      records.add((
        speciesId: member.integer('id'),
        fromSpeciesId: from,
        ordinal: index,
        trigger: _optionalObject(step, 'evolutiontrigger')?.string('name'),
        minLevel: step.integerOrNull('min_level'),
        minHappiness: step.integerOrNull('min_happiness'),
        timeOfDay: timeOfDay == null || timeOfDay.isEmpty ? null : timeOfDay,
        itemName: _optionalObject(step, 'item')?.string('name'),
      ));
    }
  }
  return records;
}

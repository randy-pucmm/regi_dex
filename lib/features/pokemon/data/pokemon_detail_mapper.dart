import '../../../core/error/failure.dart';
import 'dto/json_reader.dart';

typedef AbilityText = ({int id, String? nameEs, String? shortEffect});
typedef MoveLearn = ({int moveId, int versionGroupId, int methodId, int level});

/// Lo que trae GetPokemonDetail y la base aún no tenía.
class PokemonDetailRecord {
  const PokemonDetailRecord({
    required this.pokemonId,
    required this.speciesId,
    required this.abilities,
    required this.moves,
    this.speciesNameEs,
    this.genusEs,
  });

  final int pokemonId;
  final int speciesId;
  final String? speciesNameEs;
  final String? genusEs;
  final List<AbilityText> abilities;
  final List<MoveLearn> moves;
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

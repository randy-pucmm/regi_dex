import 'dart:convert';
import 'dart:typed_data';

/// Un Pokémon del índice con la forma de `GET /api` (solo los campos que lee
/// la app más un `battleDataCsvs` de relleno que debe ignorarse).
Map<String, dynamic> championsPokemonJson({
  required String showdownId,
  String? name,
  String? showdownName,
  List<String> types = const ['Normal'],
  String abilities = 'Intimidate|Anger Point',
  String? hiddenAbility = '',
  List<String> moves = const ['Protect', 'Double-Edge'],
}) {
  final display = name ?? showdownId;
  return {
    'name': display,
    'battleName': display,
    'slug': showdownId,
    'showdownId': showdownId,
    'showdownName': showdownName ?? display,
    'metadataCsv': 'pokemon_champions_assets/metadata/$display.csv',
    'battleDataCsvs': [
      {'season': 'M7', 'format': 'Doubles', 'path': 'x.csv'},
    ],
    'learnableMoveNames': moves,
    'summary': {
      'dex': null,
      'sprite': 'pokemon_champions_assets/pokemon/$display.png',
      'types': types,
      'primary': {
        'abilities': abilities,
        'hidden_ability': hiddenAbility,
        'form_kind': 'Base',
      },
      'baseStats': {
        'hp': 183,
        'attack': 150,
        'defense': 115,
        'sp_attack': 100,
        'sp_defense': 105,
        'speed': 122,
      },
      'battleSummary': {'Current': <String, dynamic>{}},
    },
  };
}

/// Índice mínimo con [pokemon]; [dataVersion] cambia el contenido.
Map<String, dynamic> championsIndexJson({
  String dataVersion = '20261127113551736',
  List<Map<String, dynamic>>? pokemon,
}) => {
  'generatedAt': '2026-11-27T11:35:51.736Z',
  'dataVersion': dataVersion,
  'assetRoot': 'pokemon_champions_assets',
  'defaultSeason': 'Current',
  'seasons': ['Current', 'M7'],
  'pokemon':
      pokemon ??
      [
        championsPokemonJson(
          showdownId: 'garchomp',
          name: 'Garchomp',
          types: ['Dragon', 'Ground'],
          abilities: 'Sand Veil|Rough Skin',
          moves: ['Earthquake', 'Protect', 'Double-Edge'],
        ),
        championsPokemonJson(
          showdownId: 'raichualola',
          name: 'Raichu',
          showdownName: 'Raichu-Alola',
          types: ['Electric', 'Psychic'],
          abilities: 'Surge Surfer',
          hiddenAbility: null,
          moves: ['Protect'],
        ),
        championsPokemonJson(
          showdownId: 'mimikyu',
          name: 'Mimikyu',
          types: ['Ghost', 'Fairy'],
          abilities: 'Disguise',
          hiddenAbility: 'Disguise',
          moves: ['Shadow Claw'],
        ),
      ],
};

/// [championsIndexJson] como cuerpo de respuesta.
Uint8List championsIndexBytes({
  String dataVersion = '20261127113551736',
  List<Map<String, dynamic>>? pokemon,
}) => Uint8List.fromList(
  utf8.encode(
    jsonEncode(championsIndexJson(dataVersion: dataVersion, pokemon: pokemon)),
  ),
);

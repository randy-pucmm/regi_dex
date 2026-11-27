import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../core/error/failure.dart';
import 'dto/champions_index_dto.dart';

/// Índice de Champions ya validado y listo para guardar en Drift.
class ChampionsIndexRecord {
  const ChampionsIndexRecord({
    required this.dataVersion,
    required this.meta,
    required this.pokemon,
    required this.moves,
  });

  final String dataVersion;
  final ChampionsMetaCompanion meta;
  final List<ChampionsPokemonsCompanion> pokemon;
  final List<ChampionsLearnableMovesCompanion> moves;
}

/// Decodifica y valida el cuerpo de `GET /api` y lo traduce a filas de Drift.
/// Es pura y no captura nada, así que corre en un isolate (RNF-REN-03).
/// [body] es el JSON en UTF-8, [fetchedAt] la hora de la descarga y
/// [assetBaseUrl] la raíz del servicio, para volver absolutas las imágenes.
/// Lanza [ValidationFailure] si el contenido no cumple el contrato.
ChampionsIndexRecord mapChampionsIndex(
  Uint8List body,
  DateTime fetchedAt,
  String assetBaseUrl,
) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(body));
  } on FormatException catch (error) {
    throw ValidationFailure(
      'El índice de Champions no es JSON: ${error.message}',
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw const ValidationFailure('El índice de Champions no es un objeto');
  }
  final dto = ChampionsIndexDto.fromJson(decoded);
  final base = Uri.parse(assetBaseUrl);

  final pokemon = <ChampionsPokemonsCompanion>[];
  final moves = <ChampionsLearnableMovesCompanion>[];
  for (final item in dto.pokemon) {
    pokemon.add(
      ChampionsPokemonsCompanion.insert(
        showdownId: item.showdownId,
        name: item.name,
        showdownName: item.showdownName,
        types: item.types.join(','),
        abilities: item.abilities.join('|'),
        hiddenAbility: Value(item.hiddenAbility),
        hp: item.hp,
        attack: item.attack,
        defense: item.defense,
        spAttack: item.spAttack,
        spDefense: item.spDefense,
        speed: item.speed,
        spriteUrl: base.resolve(item.sprite).toString(),
      ),
    );
    for (final move in item.learnableMoves.toSet()) {
      moves.add(
        ChampionsLearnableMovesCompanion.insert(
          showdownId: item.showdownId,
          moveName: move,
        ),
      );
    }
  }
  return ChampionsIndexRecord(
    dataVersion: dto.dataVersion,
    meta: ChampionsMetaCompanion.insert(
      key: 'index',
      dataVersion: dto.dataVersion,
      generatedAt: dto.generatedAt,
      defaultSeason: dto.defaultSeason,
      fetchedAt: fetchedAt,
    ),
    pokemon: pokemon,
    moves: moves,
  );
}

/// Deja solo letras y dígitos en minúsculas: `Raichu-Alola`, `raichualola` y
/// `raichu-alola` dan la misma clave. Sirve para relacionar nombres de
/// Champions con los de PokéAPI.
String normalizeName(String name) =>
    name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

/// Casos en que el `showdownId` no coincide con el nombre de PokéAPI una vez
/// normalizado (clave: showdownId; valor: nombre de PokéAPI normalizado). Casi
/// todos son especies cuyo Pokémon predeterminado lleva sufijo.
const showdownAliases = {
  'aegislash': 'aegislashshield',
  'basculegion': 'basculegionmale',
  'basculegionf': 'basculegionfemale',
  'gourgeist': 'gourgeistaverage',
  'indeedee': 'indeedeemale',
  'indeedeef': 'indeedeefemale',
  'lycanroc': 'lycanrocmidday',
  'maushold': 'mausholdfamilyofthree',
  'mausholdfour': 'mausholdfamilyoffour',
  'meowstic': 'meowsticmale',
  'meowsticf': 'meowsticfemale',
  'mimikyu': 'mimikyudisguised',
  'morpeko': 'morpekofullbelly',
  'palafin': 'palafinzero',
  'pyroar': 'pyroarmale',
  'squawkabilly': 'squawkabillygreenplumage',
  'squawkabillyyellow': 'squawkabillyyellowplumage',
  'taurospaldeaaqua': 'taurospaldeaaquabreed',
  'taurospaldeablaze': 'taurospaldeablazebreed',
  'taurospaldeacombat': 'taurospaldeacombatbreed',
  'toxtricity': 'toxtricityamped',
};

/// Clave normalizada de PokéAPI para [showdownId].
String pokeApiKeyFor(String showdownId) =>
    showdownAliases[showdownId] ?? normalizeName(showdownId);

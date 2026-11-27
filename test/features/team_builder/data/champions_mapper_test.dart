import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/features/team_builder/data/champions_mapper.dart';

import 'champions_test_data.dart';

void main() {
  final fetchedAt = DateTime(2026, 11, 27, 12);
  const base = 'https://championsbattledata.com';

  group('mapChampionsIndex', () {
    test('traduce el índice a filas y deja solo lo que usa la app', () {
      final record = mapChampionsIndex(championsIndexBytes(), fetchedAt, base);

      expect(record.dataVersion, '20261127113551736');
      expect(record.meta.key.value, 'index');
      expect(record.meta.defaultSeason.value, 'Current');
      expect(
        record.meta.generatedAt.value,
        DateTime.utc(2026, 11, 27, 11, 35, 51, 736),
      );
      expect(record.meta.fetchedAt.value, fetchedAt);

      expect(record.pokemon.map((p) => p.showdownId.value), [
        'garchomp',
        'raichualola',
        'mimikyu',
      ]);
      final garchomp = record.pokemon.first;
      expect(garchomp.types.value, 'Dragon,Ground');
      expect(garchomp.abilities.value, 'Sand Veil|Rough Skin');
      expect(garchomp.hiddenAbility.value, isNull);
      expect(garchomp.hp.value, 183);
      expect(garchomp.spAttack.value, 100);
      expect(
        garchomp.spriteUrl.value,
        'https://championsbattledata.com/pokemon_champions_assets/pokemon/Garchomp.png',
      );
      expect(garchomp.pokeapiPokemonId.present, isFalse);

      // hidden_ability nula o vacía no cuenta; con valor, sí.
      expect(record.pokemon[1].hiddenAbility.value, isNull);
      expect(record.pokemon[2].hiddenAbility.value, 'Disguise');
    });

    test('guarda cada movimiento una sola vez por Pokémon', () {
      final record = mapChampionsIndex(
        championsIndexBytes(
          pokemon: [
            championsPokemonJson(
              showdownId: 'garchomp',
              moves: ['Protect', 'Protect', 'Earthquake'],
            ),
          ],
        ),
        fetchedAt,
        base,
      );

      expect(record.moves.map((m) => m.moveName.value), [
        'Protect',
        'Earthquake',
      ]);
    });

    test('un cuerpo que no es JSON lanza ValidationFailure', () {
      expect(
        () => mapChampionsIndex(
          Uint8List.fromList(utf8.encode('<html>502</html>')),
          fetchedAt,
          base,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('un JSON que no es un objeto lanza ValidationFailure', () {
      expect(
        () => mapChampionsIndex(
          Uint8List.fromList(utf8.encode('[1, 2]')),
          fetchedAt,
          base,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('un campo ausente descarta el índice entero y dice cuál falta', () {
      final json = championsIndexJson();
      (json['pokemon'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .last['summary']
          .remove('baseStats');

      expect(
        () => mapChampionsIndex(
          Uint8List.fromList(utf8.encode(jsonEncode(json))),
          fetchedAt,
          base,
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.message,
            'message',
            contains('baseStats'),
          ),
        ),
      );
    });

    test('sin dataVersion lanza ValidationFailure', () {
      final json = championsIndexJson()..remove('dataVersion');
      expect(
        () => mapChampionsIndex(
          Uint8List.fromList(utf8.encode(jsonEncode(json))),
          fetchedAt,
          base,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('una fecha ilegible lanza ValidationFailure', () {
      final json = championsIndexJson()..['generatedAt'] = 'ayer';
      expect(
        () => mapChampionsIndex(
          Uint8List.fromList(utf8.encode(jsonEncode(json))),
          fetchedAt,
          base,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('nombres', () {
    test('normalizeName ignora mayúsculas, guiones y espacios', () {
      expect(normalizeName('Raichu-Alola'), 'raichualola');
      expect(normalizeName('raichu-alola'), 'raichualola');
      expect(normalizeName('Double-Edge'), 'doubleedge');
      expect(normalizeName('Will-O-Wisp'), 'willowisp');
      expect(normalizeName('Mr. Mime'), 'mrmime');
    });

    test('pokeApiKeyFor usa el alias cuando el nombre no coincide', () {
      expect(pokeApiKeyFor('raichualola'), 'raichualola');
      expect(pokeApiKeyFor('mimikyu'), 'mimikyudisguised');
      expect(pokeApiKeyFor('basculegionf'), 'basculegionfemale');
      expect(pokeApiKeyFor('taurospaldeaaqua'), 'taurospaldeaaquabreed');
    });
  });
}

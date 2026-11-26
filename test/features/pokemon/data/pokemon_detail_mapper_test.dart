import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_detail_mapper.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_mapper.dart';

import 'catalog_test_data.dart';

final _syncedAt = DateTime(2026, 11, 20, 9);

void main() {
  group('mapPokemonDetail', () {
    test('convierte identidad, especie y relaciones', () {
      final record = mapPokemonDetail(syntheticDetail(7), _syncedAt);

      expect(record.pokemon.id.value, 7);
      expect(record.pokemon.speciesId.value, 7);
      expect(record.pokemon.spriteShinyUrl.value, 'https://img.test/s/7.png');
      expect(record.pokemon.artworkShinyUrl.value, 'https://img.test/as/7.png');
      expect(record.pokemon.femaleUrl.value, 'https://img.test/f/7.png');
      expect(record.pokemon.homeUrl.value, isNull);
      expect(record.pokemon.detailSyncedAt.value, _syncedAt);
      expect(record.pokemon.lightSyncedAt.value, _syncedAt);
      expect(record.species.nameEs.value, 'Especie 7');
      expect(record.species.genusEs.value, 'Pokémon 7');
      expect(record.species.evolutionChainId.value, 7);
      expect(record.eggGroupIds, [7 % syntheticEggGroupCount + 1]);
      expect(record.types, [(slot: 1, typeId: 8)]);
      expect(record.stats, hasLength(6));
      expect(record.abilities, [(slot: 1, abilityId: 8, isHidden: false)]);
    });

    test('toma el texto de la habilidad en español', () {
      final ability = mapPokemonDetail(
        syntheticDetail(7),
        _syncedAt,
      ).abilityRows.single;

      expect(ability.id.value, 8);
      expect(ability.nameEs.value, 'Habilidad 8');
      expect(ability.shortEffect.value, 'Efecto 8');
    });

    test('sin texto en español usa el efecto en inglés', () {
      final data = syntheticDetail(7);
      final ability = _firstPokemon(data)['pokemonabilities'][0]['ability'];
      (ability['abilityeffecttexts'] as List<dynamic>).removeAt(1);

      final row = mapPokemonDetail(data, _syncedAt).abilityRows.single;
      expect(row.shortEffect.value, 'Effect 8');
    });

    test('descarta los movimientos repetidos', () {
      final moves = mapPokemonDetail(syntheticDetail(7), _syncedAt).moves;

      expect(moves, hasLength(2));
      expect(moves.map((m) => m.learnMethodId.value), [1, 4]);
      expect(moves.first.level.value, 5);
    });

    test('mapea las variantes con sus tipos', () {
      final forms = mapPokemonDetail(syntheticDetail(7), _syncedAt).forms;

      expect(forms, hasLength(2));
      expect(forms[0].pokemonId.value, 7);
      expect(forms[0].formName.value, isNull);
      expect(forms[0].isDefault.value, isTrue);
      expect(forms[0].type1Id.value, 8);
      expect(forms[0].type2Id.value, isNull);
      expect(forms[1].pokemonId.value, 10007);
      expect(forms[1].formName.value, 'mega');
      expect(forms[1].isMega.value, isTrue);
      expect(forms[1].type1Id.value, 1);
      expect(forms[1].type2Id.value, 2);
    });

    test('mapea la cadena evolutiva en orden', () {
      final record = mapPokemonDetail(syntheticDetail(7), _syncedAt);

      expect(record.evolutionChainId, 7);
      final base = record.evolutions[0];
      expect(base.toSpeciesId.value, 7);
      expect(base.fromSpeciesId.value, isNull);
      expect(base.trigger.value, isNull);
      final next = record.evolutions[1];
      expect(next.toSpeciesId.value, 1007);
      expect(next.fromSpeciesId.value, 7);
      expect(next.trigger.value, 'level-up');
      expect(next.minLevel.value, 16);
      expect(next.timeOfDay.value, isNull);
      expect(next.item.value, isNull);
    });

    test('un Pokémon sin cadena no genera evoluciones', () {
      final data = syntheticDetail(7);
      _firstPokemon(data)['pokemonspecy'].remove('evolutionchain');

      final record = mapPokemonDetail(data, _syncedAt);
      expect(record.evolutionChainId, isNull);
      expect(record.evolutions, isEmpty);
    });

    test('el hash coincide con el del catálogo ligero', () {
      final light = mapPokemonPage({
        'pokemon': [syntheticPokemon(7)],
      }, _syncedAt).single;
      final detail = mapPokemonDetail(syntheticDetail(7), _syncedAt);

      expect(detail.contentHash, light.pokemon.contentHash.value);
    });

    test('un Pokémon inexistente lanza ValidationFailure', () {
      expect(
        () => mapPokemonDetail({'pokemon': <dynamic>[]}, _syncedAt),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('un campo ausente lanza ValidationFailure', () {
      final data = syntheticDetail(7);
      _firstPokemon(data).remove('pokemonmoves');

      expect(
        () => mapPokemonDetail(data, _syncedAt),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}

Map<String, dynamic> _firstPokemon(Map<String, dynamic> data) =>
    (data['pokemon'] as List<dynamic>).first as Map<String, dynamic>;

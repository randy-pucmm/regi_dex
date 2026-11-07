import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/features/pokemon/data/content_hash.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_mapper.dart';

import 'catalog_test_data.dart';

final _syncedAt = DateTime(2026, 11, 7, 9);

void main() {
  group('mapPokemonPage', () {
    test('convierte especie, Pokémon y relaciones', () {
      final records = mapPokemonPage(
        syntheticPage(offset: 0, limit: 3, total: 3),
        _syncedAt,
      );

      expect(records, hasLength(3));
      final second = records[1];
      expect(second.species.id.value, 2);
      expect(second.species.name.value, 'species-2');
      expect(second.species.generationId.value, 1);
      expect(second.eggGroupIds, [2 % syntheticEggGroupCount + 1]);
      expect(second.pokemon.id.value, 2);
      expect(second.pokemon.speciesId.value, 2);
      expect(second.pokemon.name.value, 'pokemon-2');
      expect(second.pokemon.baseStatTotal.value, 261);
      expect(second.pokemon.lightSyncedAt.value, _syncedAt);
      expect(second.types, [(slot: 1, typeId: 3)]);
      expect(second.stats, hasLength(6));
      expect(second.abilities, [(slot: 1, abilityId: 3, isHidden: false)]);
    });

    test('calcula el content_hash con los mismos datos que guarda', () {
      final record = mapPokemonPage(
        syntheticPage(offset: 4, limit: 1, total: 5),
        _syncedAt,
      ).single;

      expect(
        record.pokemon.contentHash.value,
        computeContentHash(
          name: 'pokemon-5',
          height: 5,
          weight: 50,
          types: record.types,
          abilities: record.abilities,
          stats: record.stats,
        ),
      );
    });

    test('un elemento inválido descarta toda la página', () {
      final data = syntheticPage(offset: 0, limit: 3, total: 3);
      ((data['pokemon'] as List<dynamic>)[2] as Map<String, dynamic>).remove(
        'name',
      );

      expect(
        () => mapPokemonPage(data, _syncedAt),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('el resultado cruza un isolate sin perder datos', () async {
      final data = syntheticPage(offset: 0, limit: 5, total: 5);

      final records = await Isolate.run(() => mapPokemonPage(data, _syncedAt));

      expect(records.map((r) => r.pokemon.id.value), [1, 2, 3, 4, 5]);
      expect(
        records.first.pokemon.contentHash.value,
        mapPokemonPage(data, _syncedAt).first.pokemon.contentHash.value,
      );
    });
  });

  group('mapReferenceData', () {
    test('convierte todas las listas y el total', () {
      final records = mapReferenceData(syntheticReference(total: 1025));

      expect(records.types, hasLength(syntheticTypeCount));
      expect(records.types.first.nameEs.value, 'Tipo 1');
      expect(records.generations.single.region.value, 'kanto');
      expect(records.eggGroups, hasLength(syntheticEggGroupCount));
      expect(records.abilities, hasLength(syntheticAbilityCount));
      expect(records.moves.single.power.value, 40);
      expect(records.versionGroups.single.generationId.value, 1);
      expect(records.typeEfficacies.single.factor.value, 200);
      expect(records.totalPokemon, 1025);
    });

    test('una respuesta inválida lanza ValidationFailure', () {
      expect(
        () => mapReferenceData({'type': 'x'}),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}

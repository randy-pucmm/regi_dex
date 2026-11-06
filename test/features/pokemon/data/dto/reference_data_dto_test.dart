import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/features/pokemon/data/dto/reference_data_dto.dart';

Map<String, dynamic> _reference() => {
  'type': [
    {
      'id': 1,
      'name': 'normal',
      'typenames': [
        {
          'name': 'Normal',
          'language': {'name': 'es'},
        },
        {
          'name': 'Normal',
          'language': {'name': 'en'},
        },
      ],
    },
    {
      'id': 2,
      'name': 'fighting',
      'typenames': [
        {
          'name': 'Fighting',
          'language': {'name': 'en'},
        },
      ],
    },
  ],
  'generation': [
    {
      'id': 1,
      'name': 'generation-i',
      'region': {'name': 'kanto'},
    },
    {'id': 10, 'name': 'generation-x', 'region': null},
  ],
  'egggroup': [
    {
      'id': 1,
      'name': 'monster',
      'egggroupnames': [
        {
          'name': 'Monstruo',
          'language': {'name': 'es'},
        },
      ],
    },
  ],
  'typeefficacy': [
    {'damage_type_id': 2, 'target_type_id': 1, 'damage_factor': 200},
  ],
  'versiongroup': [
    {'id': 1, 'name': 'red-blue', 'generation_id': 1},
  ],
  'ability': [
    {'id': 65, 'name': 'overgrow'},
  ],
  'move': [
    {
      'id': 1,
      'name': 'pound',
      'type_id': 1,
      'power': 40,
      'accuracy': 100,
      'pp': 35,
      'priority': 0,
      'move_damage_class_id': 2,
    },
    {
      'id': 10001,
      'name': 'shadow-rush',
      'type_id': 10002,
      'power': null,
      'accuracy': null,
      'pp': null,
      'priority': 0,
      'move_damage_class_id': null,
    },
  ],
  'pokemon_aggregate': {
    'aggregate': {'count': 1025},
  },
};

void main() {
  test('convierte la referencia completa', () {
    final dto = ReferenceDataDto.fromData(_reference());

    expect(dto.types.map((t) => t.id), [1, 2]);
    expect(dto.generations.map((g) => g.name), [
      'generation-i',
      'generation-x',
    ]);
    expect(dto.eggGroups.single.nameEs, 'Monstruo');
    expect(dto.typeEfficacies.single.factor, 200);
    expect(dto.typeEfficacies.single.attackingTypeId, 2);
    expect(dto.typeEfficacies.single.defendingTypeId, 1);
    expect(dto.versionGroups.single.generationId, 1);
    expect(dto.abilities.single.name, 'overgrow');
    expect(dto.moves, hasLength(2));
    expect(dto.totalPokemon, 1025);
  });

  test('toma el nombre en español de la traducción es', () {
    final dto = ReferenceDataDto.fromData(_reference());

    expect(dto.types[0].nameEs, 'Normal');
    expect(dto.types[1].nameEs, isNull); // sin traducción al español
  });

  test('una generación sin región queda con region null', () {
    final dto = ReferenceDataDto.fromData(_reference());

    expect(dto.generations[0].region, 'kanto');
    expect(dto.generations[1].region, isNull);
  });

  test(
    'los movimientos conservan tipos fuera de la tabla type y campos nulos',
    () {
      final dto = ReferenceDataDto.fromData(_reference());

      expect(dto.moves[1].typeId, 10002);
      expect(dto.moves[1].power, isNull);
      expect(dto.moves[1].priority, 0);
    },
  );

  group('datos inválidos → ValidationFailure', () {
    test('falta una colección', () {
      final json = _reference()..remove('typeefficacy');
      expect(
        () => ReferenceDataDto.fromData(json),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.message,
            'message',
            contains('data.typeefficacy'),
          ),
        ),
      );
    });

    test('falta el total de Pokémon', () {
      final json = _reference()..['pokemon_aggregate'] = <String, dynamic>{};
      expect(
        () => ReferenceDataDto.fromData(json),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('un id con otro tipo', () {
      final json = _reference();
      (json['ability'] as List<dynamic>)[0] = {'id': 'x', 'name': 'overgrow'};
      expect(
        () => ReferenceDataDto.fromData(json),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}

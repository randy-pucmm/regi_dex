import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/features/pokemon/data/dto/pokemon_light_dto.dart';

Map<String, dynamic> _bulbasaur() => {
  'id': 1,
  'name': 'bulbasaur',
  'height': 7,
  'weight': 69,
  'pokemon_species_id': 1,
  'pokemonspecy': {
    'generation_id': 1,
    'evolution_chain_id': 1,
    'is_legendary': false,
    'is_mythical': false,
    'pokemonegggroups': [
      {'egg_group_id': 1},
      {'egg_group_id': 7},
    ],
  },
  'pokemontypes': [
    {'slot': 1, 'type_id': 12},
    {'slot': 2, 'type_id': 4},
  ],
  'pokemonabilities': [
    {'ability_id': 65, 'is_hidden': false, 'slot': 1},
    {'ability_id': 34, 'is_hidden': true, 'slot': 3},
  ],
  'pokemonstats': [
    {'stat_id': 1, 'base_stat': 45},
    {'stat_id': 2, 'base_stat': 49},
    {'stat_id': 3, 'base_stat': 49},
    {'stat_id': 4, 'base_stat': 65},
    {'stat_id': 5, 'base_stat': 65},
    {'stat_id': 6, 'base_stat': 45},
  ],
  'pokemonsprites': [
    {
      'front': 'https://img.test/1.png',
      'artwork': 'https://img.test/art/1.png',
    },
  ],
};

void main() {
  test('convierte un Pokémon completo', () {
    final dto = PokemonLightDto.fromJson(_bulbasaur());

    expect(dto.id, 1);
    expect(dto.name, 'bulbasaur');
    expect(dto.height, 7);
    expect(dto.weight, 69);
    expect(dto.speciesId, 1);
    expect(dto.species.generationId, 1);
    expect(dto.species.evolutionChainId, 1);
    expect(dto.species.eggGroupIds, [1, 7]);
    expect(dto.types.map((t) => (t.slot, t.typeId)), [(1, 12), (2, 4)]);
    expect(dto.abilities.map((a) => (a.slot, a.abilityId, a.isHidden)), [
      (1, 65, false),
      (3, 34, true),
    ]);
    expect(dto.stats, hasLength(6));
    expect(dto.baseStatTotal, 318);
    expect(dto.spriteUrl, 'https://img.test/1.png');
    expect(dto.artworkUrl, 'https://img.test/art/1.png');
  });

  test('sin sprites las URLs quedan en null', () {
    final json = _bulbasaur()..['pokemonsprites'] = <dynamic>[];

    final dto = PokemonLightDto.fromJson(json);

    expect(dto.spriteUrl, isNull);
    expect(dto.artworkUrl, isNull);
  });

  test('acepta una especie sin cadena evolutiva', () {
    final json = _bulbasaur();
    json['pokemonspecy'] = <String, dynamic>{
      ...(json['pokemonspecy'] as Map<String, dynamic>),
      'evolution_chain_id': null,
    };

    expect(PokemonLightDto.fromJson(json).species.evolutionChainId, isNull);
  });

  group('datos inválidos → ValidationFailure', () {
    Matcher invalid(String fragment) => throwsA(
      isA<ValidationFailure>().having(
        (f) => f.message,
        'message',
        contains(fragment),
      ),
    );

    test('falta un campo obligatorio', () {
      final json = _bulbasaur()..remove('name');
      expect(() => PokemonLightDto.fromJson(json), invalid('pokemon.name'));
    });

    test('un campo tiene otro tipo', () {
      final json = _bulbasaur()..['id'] = '1';
      expect(() => PokemonLightDto.fromJson(json), invalid('pokemon.id'));
    });

    test('falla un campo anidado', () {
      final json = _bulbasaur();
      (json['pokemontypes'] as List<dynamic>)[1] = {'slot': 2};
      expect(
        () => PokemonLightDto.fromJson(json),
        invalid('pokemon.pokemontypes[1].type_id'),
      );
    });

    test('falta la especie', () {
      final json = _bulbasaur()..remove('pokemonspecy');
      expect(
        () => PokemonLightDto.fromJson(json),
        invalid('pokemon.pokemonspecy'),
      );
    });
  });

  group('listFromData', () {
    test('convierte la lista pokemon de la respuesta', () {
      final list = PokemonLightDto.listFromData({
        'pokemon': [_bulbasaur(), _bulbasaur()..['id'] = 2],
      });
      expect(list.map((p) => p.id), [1, 2]);
    });

    test('un elemento inválido descarta toda la lista', () {
      expect(
        () => PokemonLightDto.listFromData({
          'pokemon': [_bulbasaur(), _bulbasaur()..['height'] = 'x'],
        }),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('una respuesta sin la lista es inválida', () {
      expect(
        () => PokemonLightDto.listFromData({}),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}

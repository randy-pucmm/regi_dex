// Respuestas GraphQL sintéticas para probar el mapeo y la sync del catálogo.
// Los ids de tipo (1..18), grupo huevo (1..15) y habilidad (1..20) coinciden
// con los de [syntheticReference], así que las FK siempre se cumplen.

const syntheticTypeCount = 18;
const syntheticEggGroupCount = 15;
const syntheticAbilityCount = 20;

/// `data` de GetReferenceData con [total] Pokémon por defecto.
Map<String, dynamic> syntheticReference({int total = 450}) => {
  'type': [
    for (var i = 1; i <= syntheticTypeCount; i++)
      {
        'id': i,
        'name': 'type-$i',
        'typenames': [
          {
            'name': 'Tipo $i',
            'language': {'name': 'es'},
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
  ],
  'egggroup': [
    for (var i = 1; i <= syntheticEggGroupCount; i++)
      {'id': i, 'name': 'egg-$i', 'egggroupnames': <dynamic>[]},
  ],
  'typeefficacy': [
    {'damage_type_id': 1, 'target_type_id': 2, 'damage_factor': 200},
  ],
  'versiongroup': [
    {'id': 1, 'name': 'red-blue', 'generation_id': 1},
  ],
  'ability': [
    for (var i = 1; i <= syntheticAbilityCount; i++)
      {'id': i, 'name': 'ability-$i'},
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
  ],
  'pokemon_aggregate': {
    'aggregate': {'count': total},
  },
};

/// Un Pokémon del fragmento `PokemonLight` con datos derivados de [id].
Map<String, dynamic> syntheticPokemon(int id) => {
  'id': id,
  'name': 'pokemon-$id',
  'height': id,
  'weight': id * 10,
  'pokemon_species_id': id,
  'pokemonspecy': {
    'name': 'species-$id',
    'generation_id': 1,
    'evolution_chain_id': id,
    'is_legendary': false,
    'is_mythical': false,
    'pokemonegggroups': [
      {'egg_group_id': id % syntheticEggGroupCount + 1},
    ],
  },
  'pokemontypes': [
    {'slot': 1, 'type_id': id % syntheticTypeCount + 1},
  ],
  'pokemonabilities': [
    {
      'ability_id': id % syntheticAbilityCount + 1,
      'is_hidden': false,
      'slot': 1,
    },
  ],
  'pokemonstats': [
    for (var stat = 1; stat <= 6; stat++)
      {'stat_id': stat, 'base_stat': 40 + stat},
  ],
  'pokemonsprites': [
    {
      'front': 'https://img.test/$id.png',
      'artwork': 'https://img.test/a/$id.png',
    },
  ],
};

/// `data` de GetPokemonPage: los ids de `offset + 1` en adelante, hasta
/// [limit] elementos sin pasar de [total] (la última página sale corta).
Map<String, dynamic> syntheticPage({
  required int offset,
  required int limit,
  required int total,
}) {
  final last = offset + limit < total ? offset + limit : total;
  return {
    'pokemon': [
      for (var id = offset + 1; id <= last; id++) syntheticPokemon(id),
    ],
  };
}

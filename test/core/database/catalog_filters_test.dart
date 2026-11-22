// Filtros y orden del catálogo en SQL (RD-27): EXISTS sobre tablas puente.
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/database/daos/catalog_dao.dart';

import 'database_test_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await seedFilterCatalog(db);
  });
  tearDown(() => db.close());

  Future<List<PokemonWithTypes>> rows(CatalogCriteria criteria) =>
      db.catalogDao.watchPokemonWithTypes(criteria).first;

  Future<List<int>> ids(CatalogCriteria criteria) async => [
    for (final item in await rows(criteria)) item.pokemon.id,
  ];

  group('un filtro', () {
    test('sin filtros devuelve todo por número', () async {
      expect(await ids(const CatalogCriteria()), [
        6,
        25,
        74,
        76,
        152,
        377,
        378,
      ]);
    });

    test('por tipo', () async {
      expect(await ids(const CatalogCriteria(typeIds: {6})), [74, 76, 377]);
      expect(await ids(const CatalogCriteria(typeIds: {13})), [25]);
    });

    test('por tipo secundario también', () async {
      expect(await ids(const CatalogCriteria(typeIds: {3})), [6]);
      expect(await ids(const CatalogCriteria(typeIds: {5})), [74, 76]);
    });

    test('varios valores de una categoría son alternativas (O)', () async {
      expect(await ids(const CatalogCriteria(typeIds: {13, 15})), [25, 378]);
    });

    test('un Pokémon que cumple varios valores aparece una sola vez', () async {
      expect(await ids(const CatalogCriteria(typeIds: {6, 5})), [74, 76, 377]);
    });

    test('por generación', () async {
      expect(await ids(const CatalogCriteria(generationIds: {1})), [
        6,
        25,
        74,
        76,
      ]);
      expect(await ids(const CatalogCriteria(generationIds: {2})), [152]);
      expect(await ids(const CatalogCriteria(generationIds: {2, 3})), [
        152,
        377,
        378,
      ]);
    });

    test('por grupo huevo, incluso con dos grupos', () async {
      expect(await ids(const CatalogCriteria(eggGroupIds: {3})), [74, 76]);
      expect(await ids(const CatalogCriteria(eggGroupIds: {2})), [6]);
      expect(await ids(const CatalogCriteria(eggGroupIds: {1})), [6, 152]);
    });

    test('por habilidad', () async {
      expect(await ids(const CatalogCriteria(abilityIds: {5})), [74, 76, 377]);
      expect(await ids(const CatalogCriteria(abilityIds: {66})), [6, 152]);
    });

    test('un valor que nadie tiene deja la lista vacía', () async {
      expect(await ids(const CatalogCriteria(typeIds: {15, 3})), [6, 378]);
      expect(await ids(const CatalogCriteria(typeIds: {999})), isEmpty);
    });
  });

  group('filtros combinados', () {
    test('grupo huevo Mineral y tipo Roca (PA-18)', () async {
      expect(await ids(const CatalogCriteria(eggGroupIds: {3}, typeIds: {6})), [
        74,
        76,
      ]);
    });

    test(
      'las categorías se unen con Y: Roca y Undiscovered deja a Regirock',
      () async {
        expect(
          await ids(const CatalogCriteria(typeIds: {6}, eggGroupIds: {5})),
          [377],
        );
      },
    );

    test('tipo, generación, grupo huevo y habilidad a la vez', () async {
      expect(
        await ids(
          const CatalogCriteria(
            typeIds: {6},
            generationIds: {1},
            eggGroupIds: {3},
            abilityIds: {69},
          ),
        ),
        [74, 76],
      );
      expect(
        await ids(
          const CatalogCriteria(
            typeIds: {6},
            generationIds: {3},
            eggGroupIds: {3},
          ),
        ),
        isEmpty,
      );
    });

    test('con la búsqueda por nombre o número', () async {
      expect(await ids(const CatalogCriteria(typeIds: {6}, namePart: 'g')), [
        74,
        76,
        377,
      ]);
      expect(await ids(const CatalogCriteria(typeIds: {6}, namePart: 'reg')), [
        377,
      ]);
      expect(
        await ids(const CatalogCriteria(typeIds: {6}, number: 25)),
        isEmpty,
      );
    });

    test(
      'con los filtros siguen saliendo todos los tipos de cada Pokémon',
      () async {
        final result = await rows(const CatalogCriteria(typeIds: {5}));

        expect(
          [for (final item in result) item.types.map((t) => t.id).toList()],
          [
            [6, 5],
            [6, 5],
          ],
        );
      },
    );
  });

  group('orden', () {
    test('por número, descendente', () async {
      expect(await ids(const CatalogCriteria(descending: true)), [
        378,
        377,
        152,
        76,
        74,
        25,
        6,
      ]);
    });

    test('por nombre, sin distinguir mayúsculas', () async {
      await upsertFilterPokemon(
        db,
        10,
        'Zubat',
        generation: 1,
        types: [3],
        eggGroups: [4],
        abilities: [9],
        total: 245,
      );
      await upsertFilterPokemon(
        db,
        11,
        'ABRA',
        generation: 1,
        types: [3],
        eggGroups: [4],
        abilities: [9],
        total: 310,
      );

      final names = [
        for (final item in await rows(
          const CatalogCriteria(order: CatalogOrder.name),
        ))
          item.pokemon.name,
      ];
      expect(names, [
        'ABRA',
        'charizard',
        'chikorita',
        'geodude',
        'golem',
        'pikachu',
        'regice',
        'regirock',
        'Zubat',
      ]);

      final reversed = [
        for (final item in await rows(
          const CatalogCriteria(order: CatalogOrder.name, descending: true),
        ))
          item.pokemon.name,
      ];
      expect(reversed, names.reversed.toList());
    });

    test('por total base, y los empates por número', () async {
      expect(await ids(const CatalogCriteria(order: CatalogOrder.baseTotal)), [
        74,
        152,
        25,
        76,
        6,
        377,
        378,
      ]);
      expect(
        await ids(
          const CatalogCriteria(
            order: CatalogOrder.baseTotal,
            descending: true,
          ),
        ),
        [377, 378, 6, 76, 25, 152, 74],
      );
    });

    test('ordenar no parte las filas de un mismo Pokémon', () async {
      final result = await rows(
        const CatalogCriteria(order: CatalogOrder.baseTotal),
      );

      expect(result.map((i) => i.pokemon.id).toSet(), hasLength(result.length));
      expect(result.firstWhere((i) => i.pokemon.id == 74).types, hasLength(2));
    });

    test('el orden se combina con los filtros', () async {
      expect(
        await ids(
          const CatalogCriteria(
            typeIds: {6},
            order: CatalogOrder.baseTotal,
            descending: true,
          ),
        ),
        [377, 76, 74],
      );
    });
  });

  test(
    'el flujo vuelve a emitir cuando un Pokémon pasa a cumplir el filtro',
    () async {
      final stream = db.catalogDao.watchPokemonWithTypes(
        const CatalogCriteria(typeIds: {15}),
      );
      final emissions = expectLater(
        stream.map((items) => items.map((i) => i.pokemon.id).toList()),
        emitsInOrder([
          [378],
          [378, 400],
        ]),
      );

      await upsertFilterPokemon(
        db,
        400,
        'articuno',
        generation: 1,
        types: [15, 3],
        eggGroups: [5],
        abilities: [5],
        total: 580,
      );
      await emissions;
    },
  );
}

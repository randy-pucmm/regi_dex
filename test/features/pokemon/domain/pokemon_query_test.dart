import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_query.dart';

void main() {
  group('PokemonQuery', () {
    test('dos consultas con la misma búsqueda son iguales', () {
      expect(
        const PokemonQuery(search: 'pika'),
        const PokemonQuery(search: 'pika'),
      );
      expect(
        const PokemonQuery(search: 'pika').hashCode,
        const PokemonQuery(search: 'pika').hashCode,
      );
    });

    test('buscar algo distinto o nada las hace distintas', () {
      expect(const PokemonQuery(search: 'pika'), isNot(const PokemonQuery()));
      expect(
        const PokemonQuery(search: 'pika'),
        isNot(const PokemonQuery(search: 'raichu')),
      );
    });

    test('copyWith cambia solo la búsqueda indicada', () {
      expect(
        const PokemonQuery().copyWith(search: 'pika'),
        const PokemonQuery(search: 'pika'),
      );
      expect(
        const PokemonQuery(search: 'pika').copyWith(),
        const PokemonQuery(search: 'pika'),
      );
    });

    test('term es null sin búsqueda', () {
      expect(const PokemonQuery().term, isNull);
      expect(const PokemonQuery(search: '  ').term, isNull);
    });
  });

  group('filtros y orden', () {
    const rock = PokemonQuery(
      types: {6},
      eggGroups: {5},
      sort: PokemonSort.baseTotal,
      descending: true,
    );

    test('la consulta por defecto no tiene filtros y ordena por número', () {
      const query = PokemonQuery();

      expect(query.hasFilters, isFalse);
      expect(query.activeFilterCount, 0);
      expect(query.sort, PokemonSort.number);
      expect(query.descending, isFalse);
      expect(query.isDefault, isTrue);
    });

    test('cuenta las categorías activas, no los valores', () {
      expect(const PokemonQuery(types: {1, 2, 3}).activeFilterCount, 1);
      expect(rock.activeFilterCount, 2);
      expect(
        const PokemonQuery(
          types: {1},
          generations: {1},
          eggGroups: {1},
          abilities: {1},
        ).activeFilterCount,
        4,
      );
    });

    test('isDefault es falso con búsqueda, filtro u orden distinto', () {
      expect(const PokemonQuery(search: 'a').isDefault, isFalse);
      expect(const PokemonQuery(types: {1}).isDefault, isFalse);
      expect(const PokemonQuery(sort: PokemonSort.name).isDefault, isFalse);
      expect(const PokemonQuery(descending: true).isDefault, isFalse);
      expect(const PokemonQuery(search: '  ').isDefault, isTrue);
    });

    test('la igualdad compara los conjuntos sin importar el orden', () {
      expect(const PokemonQuery(types: {1, 2}), PokemonQuery(types: {2, 1}));
      expect(
        const PokemonQuery(types: {1, 2}).hashCode,
        PokemonQuery(types: {2, 1}).hashCode,
      );
      expect(
        const PokemonQuery(types: {1}),
        isNot(const PokemonQuery(types: {2})),
      );
      expect(
        const PokemonQuery(types: {1}),
        isNot(const PokemonQuery(generations: {1})),
      );
      expect(rock, isNot(rock.copyWith(descending: false)));
      expect(rock, isNot(rock.copyWith(sort: PokemonSort.name)));
    });

    test(
      'copyWith cambia solo lo indicado y deja los conjuntos inmutables',
      () {
        final next = rock.copyWith(abilities: {9});

        expect(next.types, {6});
        expect(next.eggGroups, {5});
        expect(next.abilities, {9});
        expect(next.sort, PokemonSort.baseTotal);
        expect(() => next.abilities.add(1), throwsUnsupportedError);
      },
    );

    test('copyWith puede vaciar un conjunto', () {
      expect(rock.copyWith(types: <int>{}).types, isEmpty);
    });

    test('withoutFilters conserva la búsqueda y el orden', () {
      final query = rock.copyWith(search: 'reg').withoutFilters();

      expect(query.hasFilters, isFalse);
      expect(query.search, 'reg');
      expect(query.sort, PokemonSort.baseTotal);
      expect(query.descending, isTrue);
    });
  });

  group('JSON (RF-FIL-04)', () {
    test('guarda y recupera todos los campos', () {
      const query = PokemonQuery(
        search: 'reg',
        types: {6, 5},
        generations: {3},
        eggGroups: {5},
        abilities: {69, 5},
        sort: PokemonSort.name,
        descending: true,
      );

      expect(PokemonQuery.decode(query.encode()), query);
    });

    test('la consulta por defecto también vuelve igual', () {
      expect(
        PokemonQuery.decode(const PokemonQuery().encode()),
        const PokemonQuery(),
      );
    });

    test('los ids se guardan ordenados, así el texto es estable', () {
      expect(
        PokemonQuery(types: {9, 2, 5}).encode(),
        PokemonQuery(types: {5, 9, 2}).encode(),
      );
    });

    test('sin valor guardado o con texto que no es JSON queda por defecto', () {
      expect(PokemonQuery.decode(null), const PokemonQuery());
      expect(PokemonQuery.decode(''), const PokemonQuery());
      expect(PokemonQuery.decode('no es json'), const PokemonQuery());
      expect(PokemonQuery.decode('[1, 2]'), const PokemonQuery());
    });

    test('un campo con otro tipo o un orden desconocido se ignora', () {
      final query = PokemonQuery.decode(
        '{"search": 5, "types": "x", "generations": [1, "a", 2.5, null], '
        '"sort": "peso", "descending": "si"}',
      );

      expect(query.search, '');
      expect(query.types, isEmpty);
      expect(query.generations, {1});
      expect(query.sort, PokemonSort.number);
      expect(query.descending, isFalse);
    });

    test('un campo dañado no impide leer los demás', () {
      final query = PokemonQuery.decode(
        '{"search": "reg", "types": 7, "sort": "baseTotal"}',
      );

      expect(query.search, 'reg');
      expect(query.sort, PokemonSort.baseTotal);
    });
  });

  group('SearchTerm.parse', () {
    test('«25», «#025» y «#0378» son números nacionales', () {
      expect(SearchTerm.parse('25'), const SearchNumber(25));
      expect(SearchTerm.parse('#025'), const SearchNumber(25));
      expect(SearchTerm.parse('#0378'), const SearchNumber(378));
      expect(SearchTerm.parse('377'), const SearchNumber(377));
    });

    test('«pika» es un nombre, sin importar mayúsculas ni espacios', () {
      expect(SearchTerm.parse('pika'), const SearchName('pika'));
      expect(SearchTerm.parse('  PiKa '), const SearchName('pika'));
    });

    test('quita solo el # inicial y los espacios que lo siguen', () {
      expect(SearchTerm.parse('# 25'), const SearchNumber(25));
      expect(SearchTerm.parse('#pika'), const SearchName('pika'));
    });

    test('mezclas de letras y dígitos son nombres', () {
      expect(SearchTerm.parse('porygon2'), const SearchName('porygon2'));
      expect(SearchTerm.parse('25a'), const SearchName('25a'));
    });

    test('sin contenido no hay término', () {
      expect(SearchTerm.parse(''), isNull);
      expect(SearchTerm.parse('   '), isNull);
      expect(SearchTerm.parse('#'), isNull);
    });

    test('un número desbordado se busca como nombre', () {
      const huge = '99999999999999999999999';
      expect(SearchTerm.parse(huge), const SearchName(huge));
    });
  });
}

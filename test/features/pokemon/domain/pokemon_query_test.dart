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

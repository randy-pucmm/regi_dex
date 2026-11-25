import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon.dart';
import 'package:regi_dex/features/pokemon/domain/type_chart.dart';

PokemonTypeRef _type(int id, String name) => PokemonTypeRef(id: id, name: name);

// 1 fuego, 2 planta, 3 volador, 4 hielo, 5 tierra, 6 siniestro.
final _chart = TypeChart(
  types: [
    _type(1, 'fire'),
    _type(2, 'grass'),
    _type(3, 'flying'),
    _type(4, 'ice'),
    _type(5, 'ground'),
    _type(6, 'dark'),
  ],
  percents: const {
    (1, 2): 200,
    (4, 2): 200,
    (4, 3): 200,
    (5, 3): 0,
    (2, 5): 200,
    (6, 6): 50,
    (6, 5): 50,
  },
);

void main() {
  test('multiplica los dos tipos del defensor', () {
    expect(_chart.multiplier(4, [2, 3]), 4);
    expect(_chart.multiplier(1, [2, 3]), 2);
  });

  test('un tipo sin dato cuenta como neutro', () {
    expect(_chart.multiplier(1, [5]), 1);
  });

  test('una inmunidad anula el resto', () {
    expect(_chart.multiplier(5, [3, 2]), 0);
  });

  test('dos resistencias dan ×¼', () {
    expect(_chart.multiplier(6, [6, 5]), 0.25);
  });

  test('agrupa de más a menos efectivo y omite los neutros', () {
    final groups = _chart.matchups([2, 3]);

    expect(groups.keys.toList(), [4, 2, 0]);
    expect([for (final t in groups[4]!) t.name], ['ice']);
    expect([for (final t in groups[2]!) t.name], ['fire']);
    expect([for (final t in groups[0]!) t.name], ['ground']);
    expect(
      groups.values.expand((g) => g).map((t) => t.name),
      isNot(contains('dark')),
    );
  });

  test('sin datos no hay grupos', () {
    expect(const TypeChart.empty().isEmpty, isTrue);
    expect(const TypeChart.empty().matchups([1]), isEmpty);
  });
}

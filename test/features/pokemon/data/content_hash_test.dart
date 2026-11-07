import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/features/pokemon/data/content_hash.dart';

typedef _Types = List<({int slot, int typeId})>;
typedef _Abilities = List<({int slot, int abilityId, bool isHidden})>;
typedef _Stats = List<({int statId, int baseStat})>;

String _hash({
  String name = 'bulbasaur',
  int height = 7,
  int weight = 69,
  _Types? types,
  _Abilities? abilities,
  _Stats? stats,
}) => computeContentHash(
  name: name,
  height: height,
  weight: weight,
  types: types ?? [(slot: 1, typeId: 12), (slot: 2, typeId: 4)],
  abilities:
      abilities ??
      [
        (slot: 1, abilityId: 65, isHidden: false),
        (slot: 3, abilityId: 34, isHidden: true),
      ],
  stats: stats ?? [(statId: 1, baseStat: 45), (statId: 2, baseStat: 49)],
);

void main() {
  test('es un SHA-1 hexadecimal de 40 caracteres y estable', () {
    final hash = _hash();

    expect(hash, matches(RegExp(r'^[0-9a-f]{40}$')));
    expect(_hash(), hash);
  });

  test('no depende del orden de tipos, habilidades ni stats', () {
    final reordered = _hash(
      types: [(slot: 2, typeId: 4), (slot: 1, typeId: 12)],
      abilities: [
        (slot: 3, abilityId: 34, isHidden: true),
        (slot: 1, abilityId: 65, isHidden: false),
      ],
      stats: [(statId: 2, baseStat: 49), (statId: 1, baseStat: 45)],
    );

    expect(reordered, _hash());
  });

  group('cambia si cambia un campo canónico', () {
    final base = _hash();

    test('nombre', () => expect(_hash(name: 'ivysaur'), isNot(base)));
    test('altura', () => expect(_hash(height: 8), isNot(base)));
    test('peso', () => expect(_hash(weight: 70), isNot(base)));
    test(
      'tipo',
      () => expect(
        _hash(types: [(slot: 1, typeId: 12), (slot: 2, typeId: 5)]),
        isNot(base),
      ),
    );
    test(
      'habilidad oculta',
      () => expect(
        _hash(
          abilities: [
            (slot: 1, abilityId: 65, isHidden: false),
            (slot: 3, abilityId: 34, isHidden: false),
          ],
        ),
        isNot(base),
      ),
    );
    test(
      'stat base',
      () => expect(
        _hash(stats: [(statId: 1, baseStat: 46), (statId: 2, baseStat: 49)]),
        isNot(base),
      ),
    );
  });
}

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/database/app_database.dart';

import 'database_test_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Future<void> loadReference() {
    return db.referenceDao.upsertReferenceData(
      generations: [
        GenerationsCompanion.insert(id: const Value(1), name: 'generation-i'),
      ],
      types: [
        TypesCompanion.insert(id: const Value(2), name: 'fighting'),
        TypesCompanion.insert(id: const Value(1), name: 'normal'),
      ],
      moves: [
        MovesCompanion.insert(
          id: const Value(1),
          name: 'pound',
          typeId: const Value(10002), // tipo fuera de la tabla `type`
          power: const Value(40),
        ),
      ],
      versionGroups: [
        VersionGroupsCompanion.insert(
          id: const Value(1),
          name: 'red-blue',
          generationId: const Value(1),
        ),
      ],
      typeEfficacies: [
        TypeEfficaciesCompanion.insert(
          attackingTypeId: 2,
          defendingTypeId: 1,
          factor: 200,
        ),
      ],
    );
  }

  test('cargar la referencia varias veces no duplica filas', () async {
    await loadReference();
    final tables = [
      'generation',
      'type',
      'move',
      'version_group',
      'type_efficacy',
    ];
    final first = {for (final t in tables) t: await rowCount(db, t)};

    await loadReference();
    await loadReference();

    expect({for (final t in tables) t: await rowCount(db, t)}, first);
    expect(first['type'], 2);
  });

  test('los movimientos aceptan tipos fuera de la tabla type', () async {
    await loadReference();
    final move = await (db.select(
      db.moves,
    )..where((m) => m.id.equals(1))).getSingle();
    expect(move.typeId, 10002);
  });

  test('watchTypes emite ordenado por id y se actualiza al escribir', () async {
    final names = db.referenceDao.watchTypes().map(
      (rows) => [for (final row in rows) row.name],
    );
    final expectation = expectLater(
      names,
      emitsInOrder([
        emits(isEmpty),
        emitsThrough(['normal', 'fighting']),
      ]),
    );
    await pumpEventQueue();

    await loadReference();
    await expectation;
  });
}

// Planes de consulta de filtros y orden (RNF-REN-02): qué índice usa cada uno.
// Se capturan las consultas reales del DAO y se les pide su plan a SQLite.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/database/daos/catalog_dao.dart';

class _Capture extends QueryInterceptor {
  final selects = <({String sql, List<Object?> args})>[];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selects.add((sql: statement, args: args));
    return executor.runSelect(statement, args);
  }
}

void main() {
  late AppDatabase db;
  late _Capture capture;

  setUp(() {
    capture = _Capture();
    db = AppDatabase(NativeDatabase.memory().interceptWith(capture));
  });
  tearDown(() => db.close());

  Variable<Object> bind(Object? value) => switch (value) {
    final int v => Variable<Object>(v),
    final String v => Variable<Object>(v),
    _ => throw ArgumentError('Variable no soportada: $value'),
  };

  /// Plan de la consulta que arma el DAO para [criteria], una línea por paso.
  Future<String> planOf(CatalogCriteria criteria) async {
    capture.selects.clear();
    await db.catalogDao.watchPokemonWithTypes(criteria).first;
    final query = capture.selects.lastWhere(
      (s) => s.sql.contains('FROM "pokemon"'),
    );
    final plan = await db
        .customSelect(
          'EXPLAIN QUERY PLAN ${query.sql}',
          variables: [for (final arg in query.args) bind(arg)],
        )
        .get();
    return plan.map((row) => row.read<String>('detail')).join('\n');
  }

  group('cada filtro usa su índice', () {
    test('tipo: idx_pokemon_type_type_id', () async {
      final plan = await planOf(const CatalogCriteria(typeIds: {6}));

      expect(plan, contains('pt EXISTS USING INDEX idx_pokemon_type_type_id'));
    });

    test('generación: idx_species_generation_id', () async {
      final plan = await planOf(const CatalogCriteria(generationIds: {1}));

      expect(
        plan,
        contains('sp EXISTS USING COVERING INDEX idx_species_generation_id'),
      );
    });

    test('grupo huevo: la clave primaria de species_egg_group', () async {
      final plan = await planOf(const CatalogCriteria(eggGroupIds: {3}));

      expect(
        plan,
        contains(
          'eg EXISTS USING COVERING INDEX sqlite_autoindex_species_egg_group_1',
        ),
      );
    });

    test('habilidad: idx_pokemon_ability_ability_id', () async {
      final plan = await planOf(const CatalogCriteria(abilityIds: {5}));

      expect(
        plan,
        contains('pa EXISTS USING INDEX idx_pokemon_ability_ability_id'),
      );
    });

    test('combinados: cada categoría usa su propio índice', () async {
      final plan = await planOf(
        const CatalogCriteria(
          typeIds: {6},
          generationIds: {1},
          eggGroupIds: {3},
          abilityIds: {5},
        ),
      );

      for (final index in [
        'idx_pokemon_type_type_id',
        'idx_species_generation_id',
        'sqlite_autoindex_species_egg_group_1',
        'idx_pokemon_ability_ability_id',
      ]) {
        expect(plan, contains(index));
      }
    });
  });

  group('cada orden usa su índice', () {
    test('por número: la clave primaria, sin ordenar aparte', () async {
      final plan = await planOf(const CatalogCriteria());

      expect(plan, isNot(contains('USE TEMP B-TREE')));
    });

    test('por nombre: idx_pokemon_name_nocase', () async {
      final plan = await planOf(
        const CatalogCriteria(order: CatalogOrder.name),
      );

      expect(
        plan,
        contains('SCAN pokemon USING INDEX idx_pokemon_name_nocase'),
      );
    });

    test('por total base: idx_pokemon_base_stat_total', () async {
      final plan = await planOf(
        const CatalogCriteria(order: CatalogOrder.baseTotal, descending: true),
      );

      expect(
        plan,
        contains('SCAN pokemon USING INDEX idx_pokemon_base_stat_total'),
      );
    });
  });

  group('lo demás sobre la consulta', () {
    test('los tipos de cada Pokémon se leen por la clave primaria', () async {
      final plan = await planOf(const CatalogCriteria());

      expect(
        plan,
        contains(
          'pokemon_type USING INDEX sqlite_autoindex_pokemon_type_1 (pokemon_id=?)',
        ),
      );
    });

    test('el número nacional busca por clave primaria', () async {
      final plan = await planOf(const CatalogCriteria(number: 25));

      expect(plan, contains('SEARCH pokemon USING INTEGER PRIMARY KEY'));
    });

    test('el nombre contiene recorre la tabla (sin índice posible)', () async {
      final plan = await planOf(const CatalogCriteria(namePart: 'pika'));

      expect(plan, contains('SCAN pokemon'));
    });
  });
}

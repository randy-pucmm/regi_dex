import 'package:drift/drift.dart';

// Tablas de referencia (D09/D10). Los ids son los de PokéAPI (PS-05).

@DataClassName('GenerationRow')
class Generations extends Table {
  @override
  String get tableName => 'generation';

  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get region => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TypeRow')
class Types extends Table {
  @override
  String get tableName => 'type';

  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get nameEs => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('EggGroupRow')
class EggGroups extends Table {
  @override
  String get tableName => 'egg_group';

  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get nameEs => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AbilityRow')
class Abilities extends Table {
  @override
  String get tableName => 'ability';

  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get nameEs => text().nullable()();
  TextColumn get shortEffect => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Movimiento. `typeId` no es FK: la referencia solo trae tipos con id < 10000
/// y algunos movimientos usan tipos especiales (sombra, desconocido).
@DataClassName('MoveRow')
class Moves extends Table {
  @override
  String get tableName => 'move';

  IntColumn get id => integer()();
  TextColumn get name => text()();
  IntColumn get typeId => integer().nullable()();
  IntColumn get power => integer().nullable()();
  IntColumn get accuracy => integer().nullable()();
  IntColumn get pp => integer().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  IntColumn get damageClassId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('VersionGroupRow')
class VersionGroups extends Table {
  @override
  String get tableName => 'version_group';

  IntColumn get id => integer()();
  TextColumn get name => text()();
  IntColumn get generationId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Eficacia entre tipos. `factor` es 0, 50, 100 o 200 (porcentaje de daño).
@DataClassName('TypeEfficacyRow')
class TypeEfficacies extends Table {
  @override
  String get tableName => 'type_efficacy';

  IntColumn get attackingTypeId => integer()();
  IntColumn get defendingTypeId => integer()();
  IntColumn get factor => integer()();

  @override
  Set<Column> get primaryKey => {attackingTypeId, defendingTypeId};
}

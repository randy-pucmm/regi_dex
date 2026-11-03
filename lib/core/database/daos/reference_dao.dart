import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/reference_tables.dart';

part 'reference_dao.g.dart';

/// Acceso a los datos de referencia: tipos, generaciones, grupos huevo,
/// habilidades, movimientos, version groups y eficacias.
@DriftAccessor(
  tables: [
    Generations,
    Types,
    EggGroups,
    Abilities,
    Moves,
    VersionGroups,
    TypeEfficacies,
  ],
)
class ReferenceDao extends DatabaseAccessor<AppDatabase>
    with _$ReferenceDaoMixin {
  ReferenceDao(super.attachedDatabase);

  /// Persiste todos los datos de referencia en una sola transacción.
  /// Los registros existentes se actualizan por id (sin duplicados).
  Future<void> upsertReferenceData({
    List<GenerationsCompanion> generations = const [],
    List<TypesCompanion> types = const [],
    List<EggGroupsCompanion> eggGroups = const [],
    List<AbilitiesCompanion> abilities = const [],
    List<MovesCompanion> moves = const [],
    List<VersionGroupsCompanion> versionGroups = const [],
    List<TypeEfficaciesCompanion> typeEfficacies = const [],
  }) {
    return transaction(() async {
      await batch((b) {
        b.insertAllOnConflictUpdate(this.generations, generations);
        b.insertAllOnConflictUpdate(this.types, types);
        b.insertAllOnConflictUpdate(this.eggGroups, eggGroups);
        b.insertAllOnConflictUpdate(this.abilities, abilities);
        b.insertAllOnConflictUpdate(this.moves, moves);
        b.insertAllOnConflictUpdate(this.versionGroups, versionGroups);
        b.insertAllOnConflictUpdate(this.typeEfficacies, typeEfficacies);
      });
    });
  }

  /// Tipos por id.
  Stream<List<TypeRow>> watchTypes() =>
      (select(types)..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();

  /// Generaciones por id.
  Stream<List<GenerationRow>> watchGenerations() =>
      (select(generations)..orderBy([(g) => OrderingTerm.asc(g.id)])).watch();

  /// Grupos huevo por id.
  Stream<List<EggGroupRow>> watchEggGroups() =>
      (select(eggGroups)..orderBy([(g) => OrderingTerm.asc(g.id)])).watch();

  /// Habilidades por id.
  Stream<List<AbilityRow>> watchAbilities() =>
      (select(abilities)..orderBy([(a) => OrderingTerm.asc(a.id)])).watch();
}

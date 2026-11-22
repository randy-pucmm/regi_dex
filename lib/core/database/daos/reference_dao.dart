import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/reference_tables.dart';

part 'reference_dao.g.dart';

/// Los datos de referencia que alimentan los filtros del catálogo.
typedef FilterReference = ({
  List<TypeRow> types,
  List<GenerationRow> generations,
  List<EggGroupRow> eggGroups,
  List<AbilityRow> abilities,
});

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

  /// Los valores de los cuatro filtros del catálogo, cada uno por id. Emite al
  /// suscribirse y vuelve a emitir cuando cambia cualquiera de las cuatro tablas.
  Stream<FilterReference> watchFilterReference() {
    return customSelect(
      'SELECT 1',
      readsFrom: {types, generations, eggGroups, abilities},
    ).watch().asyncMap((_) async {
      return (
        types: await (select(
          types,
        )..orderBy([(t) => OrderingTerm.asc(t.id)])).get(),
        generations: await (select(
          generations,
        )..orderBy([(g) => OrderingTerm.asc(g.id)])).get(),
        eggGroups: await (select(
          eggGroups,
        )..orderBy([(g) => OrderingTerm.asc(g.id)])).get(),
        abilities: await (select(
          abilities,
        )..orderBy([(a) => OrderingTerm.asc(a.id)])).get(),
      );
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

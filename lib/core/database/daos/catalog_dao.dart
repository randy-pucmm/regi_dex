import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/catalog_tables.dart';

part 'catalog_dao.g.dart';

/// Un Pokémon con sus tipos ya resueltos, por orden de slot.
typedef PokemonWithTypes = ({PokemonRow pokemon, List<TypeRow> types});

typedef PokemonDetailRows = ({
  PokemonRow pokemon,
  List<TypeRow> types,
  List<PokemonStatRow> stats,
  List<({AbilityRow ability, bool isHidden})> abilities,
  List<EggGroupRow> eggGroups,
  List<PokemonFormRow> forms,
});

/// Un movimiento que aprende un Pokémon, con los datos del movimiento.
typedef PokemonMoveEntry = ({
  int moveId,
  String name,
  String? typeName,
  String? typeNameEs,
  int? power,
  int? accuracy,
  int? pp,
  int? damageClassId,
  int level,
});

/// La cadena evolutiva de un Pokémon: sus pasos y, por especie, el nombre en
/// español y el sprite del Pokémon por defecto.
typedef EvolutionRows = ({
  int currentSpeciesId,
  List<EvolutionRow> steps,
  Map<int, ({String? nameEs, String? spriteUrl})> species,
});

/// Campo por el que se ordena el catálogo.
enum CatalogOrder { number, name, baseTotal }

/// Qué Pokémon del catálogo se piden y en qué orden. Sin campos devuelve todos
/// por número. Cada conjunto de ids filtra una categoría (basta uno de sus
/// valores) y las categorías se combinan con Y.
class CatalogCriteria {
  const CatalogCriteria({
    this.number,
    this.namePart,
    this.typeIds = const {},
    this.generationIds = const {},
    this.eggGroupIds = const {},
    this.abilityIds = const {},
    this.order = CatalogOrder.number,
    this.descending = false,
  });

  /// Número nacional exacto.
  final int? number;

  /// Trozo del nombre, sin distinguir mayúsculas.
  final String? namePart;

  final Set<int> typeIds;
  final Set<int> generationIds;
  final Set<int> eggGroupIds;
  final Set<int> abilityIds;
  final CatalogOrder order;
  final bool descending;

  @override
  bool operator ==(Object other) =>
      other is CatalogCriteria &&
      other.number == number &&
      other.namePart == namePart &&
      _same(other.typeIds, typeIds) &&
      _same(other.generationIds, generationIds) &&
      _same(other.eggGroupIds, eggGroupIds) &&
      _same(other.abilityIds, abilityIds) &&
      other.order == order &&
      other.descending == descending;

  @override
  int get hashCode => Object.hash(
    number,
    namePart,
    Object.hashAllUnordered(typeIds),
    Object.hashAllUnordered(generationIds),
    Object.hashAllUnordered(eggGroupIds),
    Object.hashAllUnordered(abilityIds),
    order,
    descending,
  );

  static bool _same(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);
}

/// Acceso al catálogo de Pokémon y a sus tablas de relación.
@DriftAccessor(
  tables: [
    Species,
    SpeciesEggGroups,
    Pokemons,
    PokemonTypes,
    PokemonStats,
    PokemonAbilities,
    PokemonMoves,
    Evolutions,
    PokemonForms,
  ],
)
class CatalogDao extends DatabaseAccessor<AppDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.attachedDatabase);

  /// Todos los Pokémon por id; vuelve a emitir cuando cambia la tabla.
  Stream<List<PokemonRow>> watchAllPokemon() =>
      (select(pokemons)..orderBy([(p) => OrderingTerm.asc(p.id)])).watch();

  /// Los Pokémon que cumplen [criteria] (todos si está vacía) en el orden
  /// pedido, cada uno con sus tipos por slot (uno o dos; la lista queda vacía
  /// si aún no tiene). Es una sola consulta con join: vuelve a emitir cuando
  /// cambia el catálogo o la tabla de tipos, y como cada lote de la
  /// sincronización es una transacción, emite una vez por lote.
  ///
  /// El nombre se busca con `instr` sobre el nombre en minúsculas («contiene»,
  /// sin comodines que escapar). Los filtros por tipo, generación, grupo huevo
  /// y habilidad usan `EXISTS` sobre las tablas puente: así el join de tipos
  /// solo sirve para mostrar y no recorta el segundo tipo de cada Pokémon. Se
  /// ordena por el campo pedido, luego por id y por slot, de modo que las filas
  /// de un mismo Pokémon quedan juntas.
  Stream<List<PokemonWithTypes>> watchPokemonWithTypes([
    CatalogCriteria criteria = const CatalogCriteria(),
  ]) {
    final typeTable = attachedDatabase.types;
    final query =
        select(pokemons).join([
            leftOuterJoin(
              pokemonTypes,
              pokemonTypes.pokemonId.equalsExp(pokemons.id),
            ),
            leftOuterJoin(
              typeTable,
              typeTable.id.equalsExp(pokemonTypes.typeId),
            ),
          ])
          ..where(_matches(criteria))
          ..orderBy([
            _primaryOrder(criteria),
            if (criteria.order != CatalogOrder.number)
              OrderingTerm.asc(pokemons.id),
            OrderingTerm.asc(pokemonTypes.slot),
          ]);

    return query.watch().map((rows) {
      final result = <PokemonWithTypes>[];
      for (final row in rows) {
        final pokemon = row.readTable(pokemons);
        final type = row.readTableOrNull(typeTable);
        if (result.isEmpty || result.last.pokemon.id != pokemon.id) {
          result.add((pokemon: pokemon, types: [?type]));
        } else if (type != null) {
          result.last.types.add(type);
        }
      }
      return result;
    });
  }

  /// Primer criterio de orden de [criteria].
  OrderingTerm _primaryOrder(CatalogCriteria criteria) {
    final mode = criteria.descending ? OrderingMode.desc : OrderingMode.asc;
    return switch (criteria.order) {
      CatalogOrder.number => OrderingTerm(expression: pokemons.id, mode: mode),
      CatalogOrder.name => OrderingTerm(
        expression: pokemons.name.collate(Collate.noCase),
        mode: mode,
      ),
      CatalogOrder.baseTotal => OrderingTerm(
        expression: pokemons.baseStatTotal,
        mode: mode,
      ),
    };
  }

  /// Condición de [criteria] sobre `pokemon`; verdadera si no pide nada.
  Expression<bool> _matches(CatalogCriteria criteria) {
    Expression<bool> where = pokemons.isDefault.equals(true);
    final number = criteria.number;
    if (number != null) where = where & pokemons.id.equals(number);
    final namePart = criteria.namePart;
    if (namePart != null) {
      where =
          where &
          FunctionCallExpression<int>('instr', [
            pokemons.name.lower(),
            Variable<String>(namePart),
          ]).isBiggerThanValue(0);
    }
    if (criteria.typeIds.isNotEmpty) {
      final pt = pokemonTypes.createAlias('pt');
      where =
          where &
          existsQuery(
            selectOnly(pt)
              ..addColumns([pt.pokemonId])
              ..where(
                pt.pokemonId.equalsExp(pokemons.id) &
                    pt.typeId.isIn(criteria.typeIds),
              ),
          );
    }
    if (criteria.generationIds.isNotEmpty) {
      final sp = species.createAlias('sp');
      where =
          where &
          existsQuery(
            selectOnly(sp)
              ..addColumns([sp.id])
              ..where(
                sp.id.equalsExp(pokemons.speciesId) &
                    sp.generationId.isIn(criteria.generationIds),
              ),
          );
    }
    if (criteria.eggGroupIds.isNotEmpty) {
      final eg = speciesEggGroups.createAlias('eg');
      where =
          where &
          existsQuery(
            selectOnly(eg)
              ..addColumns([eg.speciesId])
              ..where(
                eg.speciesId.equalsExp(pokemons.speciesId) &
                    eg.eggGroupId.isIn(criteria.eggGroupIds),
              ),
          );
    }
    if (criteria.abilityIds.isNotEmpty) {
      final pa = pokemonAbilities.createAlias('pa');
      where =
          where &
          existsQuery(
            selectOnly(pa)
              ..addColumns([pa.pokemonId])
              ..where(
                pa.pokemonId.equalsExp(pokemons.id) &
                    pa.abilityId.isIn(criteria.abilityIds),
              ),
          );
    }
    return where;
  }

  /// Cantidad de Pokémon del catálogo, como flujo.
  Stream<int> watchPokemonCount() {
    final count = pokemons.id.count();
    return (selectOnly(pokemons)
          ..addColumns([count])
          ..where(pokemons.isDefault.equals(true)))
        .map((row) => row.read(count)!)
        .watchSingle();
  }

  /// Cantidad de Pokémon del catálogo.
  Future<int> countPokemon() => watchPokemonCount().first;

  /// Pokémon por id, o null si no está en el catálogo.
  Future<PokemonRow?> getPokemon(int id) =>
      (select(pokemons)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// Inserta o actualiza una especie por su id.
  Future<void> upsertSpecies(SpeciesCompanion row) =>
      into(species).insertOnConflictUpdate(row);

  /// Reemplaza en una transacción los grupos huevo de [speciesId].
  Future<void> replaceSpeciesEggGroups(int speciesId, List<int> eggGroupIds) {
    return transaction(() async {
      await (delete(
        speciesEggGroups,
      )..where((t) => t.speciesId.equals(speciesId))).go();
      await batch(
        (b) => b.insertAll(speciesEggGroups, [
          for (final id in eggGroupIds)
            SpeciesEggGroupsCompanion.insert(
              speciesId: speciesId,
              eggGroupId: id,
            ),
        ]),
      );
    });
  }

  /// Tipos de [pokemonId] por slot.
  Future<List<PokemonTypeRow>> typesOf(int pokemonId) =>
      (select(pokemonTypes)
            ..where((t) => t.pokemonId.equals(pokemonId))
            ..orderBy([(t) => OrderingTerm.asc(t.slot)]))
          .get();

  /// Estadísticas base de [pokemonId] por id de stat.
  Future<List<PokemonStatRow>> statsOf(int pokemonId) =>
      (select(pokemonStats)
            ..where((t) => t.pokemonId.equals(pokemonId))
            ..orderBy([(t) => OrderingTerm.asc(t.statId)]))
          .get();

  /// Habilidades de [pokemonId] por slot.
  Future<List<PokemonAbilityRow>> abilitiesOf(int pokemonId) =>
      (select(pokemonAbilities)
            ..where((t) => t.pokemonId.equals(pokemonId))
            ..orderBy([(t) => OrderingTerm.asc(t.slot)]))
          .get();

  /// Inserta o actualiza habilidades por id; solo cambia las columnas con valor.
  Future<void> upsertAbilities(List<AbilitiesCompanion> rows) => batch(
    (b) => b.insertAllOnConflictUpdate(attachedDatabase.abilities, rows),
  );

  /// Reemplaza los movimientos de [pokemonId] por [rows].
  Future<void> replacePokemonMoves(
    int pokemonId,
    List<PokemonMovesCompanion> rows,
  ) {
    return transaction(() async {
      await (delete(
        pokemonMoves,
      )..where((t) => t.pokemonId.equals(pokemonId))).go();
      await batch((b) => b.insertAll(pokemonMoves, rows));
    });
  }

  /// Reemplaza las variantes de [speciesId] por [rows].
  Future<void> replaceSpeciesForms(
    int speciesId,
    List<PokemonFormsCompanion> rows,
  ) {
    return transaction(() async {
      await (delete(
        pokemonForms,
      )..where((t) => t.speciesId.equals(speciesId))).go();
      await batch((b) => b.insertAll(pokemonForms, rows));
    });
  }

  /// Reemplaza la cadena evolutiva [chainId] por [rows], en su orden.
  Future<void> replaceEvolutionChain(
    int chainId,
    List<EvolutionsCompanion> rows,
  ) {
    return transaction(() async {
      await (delete(evolutions)..where((t) => t.chainId.equals(chainId))).go();
      await batch((b) => b.insertAll(evolutions, rows));
    });
  }

  /// Un Pokémon con tipos, stats y habilidades; null si no existe. Vuelve a
  /// emitir cuando cambia su fila, que es lo que toca [upsertPokemon].
  Stream<PokemonDetailRows?> watchPokemonDetail(int id) {
    final typeTable = attachedDatabase.types;
    final abilityTable = attachedDatabase.abilities;
    return (select(
      pokemons,
    )..where((p) => p.id.equals(id))).watchSingleOrNull().asyncMap((
      pokemon,
    ) async {
      if (pokemon == null) return null;
      final types =
          await (select(typeTable).join([
                  innerJoin(
                    pokemonTypes,
                    pokemonTypes.typeId.equalsExp(typeTable.id),
                  ),
                ])
                ..where(pokemonTypes.pokemonId.equals(id))
                ..orderBy([OrderingTerm.asc(pokemonTypes.slot)]))
              .map((row) => row.readTable(typeTable))
              .get();
      final stats = await (select(
        pokemonStats,
      )..where((s) => s.pokemonId.equals(id))).get();
      final abilities =
          await (select(abilityTable).join([
                  innerJoin(
                    pokemonAbilities,
                    pokemonAbilities.abilityId.equalsExp(abilityTable.id),
                  ),
                ])
                ..where(pokemonAbilities.pokemonId.equals(id))
                ..orderBy([OrderingTerm.asc(pokemonAbilities.slot)]))
              .map(
                (row) => (
                  ability: row.readTable(abilityTable),
                  isHidden: row.read(pokemonAbilities.isHidden)!,
                ),
              )
              .get();
      final eggGroupTable = attachedDatabase.eggGroups;
      final eggGroups =
          await (select(eggGroupTable).join([
                  innerJoin(
                    speciesEggGroups,
                    speciesEggGroups.eggGroupId.equalsExp(eggGroupTable.id),
                  ),
                ])
                ..where(speciesEggGroups.speciesId.equals(pokemon.speciesId))
                ..orderBy([OrderingTerm.asc(eggGroupTable.id)]))
              .map((row) => row.readTable(eggGroupTable))
              .get();
      final forms =
          await (select(pokemonForms)
                ..where((f) => f.speciesId.equals(pokemon.speciesId))
                ..orderBy([(f) => OrderingTerm.asc(f.pokemonId)]))
              .get();
      return (
        pokemon: pokemon,
        types: types,
        stats: stats,
        abilities: abilities,
        eggGroups: eggGroups,
        forms: forms,
      );
    });
  }

  /// La cadena evolutiva de [pokemonId]; null si no está o no se descargó.
  Stream<EvolutionRows?> watchEvolutions(int pokemonId) =>
      select(evolutions).watch().asyncMap((_) => _evolutionRows(pokemonId));

  Future<EvolutionRows?> _evolutionRows(int pokemonId) async {
    final pokemon = await getPokemon(pokemonId);
    if (pokemon == null) return null;
    final current = await (select(
      species,
    )..where((s) => s.id.equals(pokemon.speciesId))).getSingleOrNull();
    final chainId = current?.evolutionChainId;
    if (chainId == null) return null;

    final steps =
        await (select(evolutions)
              ..where((e) => e.chainId.equals(chainId))
              ..orderBy([(e) => OrderingTerm.asc(e.id)]))
            .get();
    if (steps.isEmpty) return null;
    final ids = {for (final e in steps) e.toSpeciesId};
    final names = await (select(species)..where((s) => s.id.isIn(ids))).get();
    final defaults = await (select(
      pokemons,
    )..where((p) => p.speciesId.isIn(ids) & p.isDefault.equals(true))).get();
    final nameEs = {for (final n in names) n.id: n.nameEs};
    final sprites = {for (final p in defaults) p.speciesId: p.spriteUrl};
    return (
      currentSpeciesId: pokemon.speciesId,
      steps: steps,
      species: {
        for (final id in ids) id: (nameEs: nameEs[id], spriteUrl: sprites[id]),
      },
    );
  }

  /// Condición de las filas de [pokemonId] en [versionGroupId], de
  /// [methodId] o de cualquier método si es null.
  Expression<bool> _learned(int pokemonId, int versionGroupId, int? methodId) =>
      pokemonMoves.pokemonId.equals(pokemonId) &
      pokemonMoves.versionGroupId.equals(versionGroupId) &
      (methodId == null
          ? const Constant(true)
          : pokemonMoves.learnMethodId.equals(methodId));

  /// Juegos (grupos de versiones) en los que [pokemonId] aprende movimientos,
  /// del más reciente al más antiguo, con su nombre.
  Future<List<({int id, String name})>> getMoveGames(int pokemonId) async {
    final versionGroups = attachedDatabase.versionGroups;
    final query =
        selectOnly(pokemonMoves).join([
            innerJoin(
              versionGroups,
              versionGroups.id.equalsExp(pokemonMoves.versionGroupId),
            ),
          ])
          ..addColumns([pokemonMoves.versionGroupId, versionGroups.name])
          ..where(pokemonMoves.pokemonId.equals(pokemonId))
          ..groupBy([pokemonMoves.versionGroupId])
          ..orderBy([OrderingTerm.desc(pokemonMoves.versionGroupId)]);
    return query
        .map(
          (row) => (
            id: row.read(pokemonMoves.versionGroupId)!,
            name: row.read(versionGroups.name)!,
          ),
        )
        .get();
  }

  /// El juego más reciente donde [pokemonId] aprende movimientos por nivel;
  /// si no hay, el más reciente con datos. Null si no tiene movimientos.
  Future<int?> getDefaultMoveGame(int pokemonId) async {
    final latest = pokemonMoves.versionGroupId.max();
    Future<int?> latestWhere(Expression<bool> condition) =>
        (selectOnly(pokemonMoves)
              ..addColumns([latest])
              ..where(condition))
            .map((row) => row.read(latest))
            .getSingle();

    final ofPokemon = pokemonMoves.pokemonId.equals(pokemonId);
    return await latestWhere(
          ofPokemon & pokemonMoves.learnMethodId.equals(1),
        ) ??
        await latestWhere(ofPokemon);
  }

  Future<int> countMoves(
    int pokemonId, {
    required int versionGroupId,
    int? methodId,
  }) {
    final count = pokemonMoves.moveId.count(distinct: true);
    return (selectOnly(pokemonMoves)
          ..addColumns([count])
          ..where(_learned(pokemonId, versionGroupId, methodId)))
        .map((row) => row.read(count)!)
        .getSingle();
  }

  /// Movimientos de [pokemonId] en [versionGroupId] por [methodId] (todos si
  /// es null, cada uno una vez y por nombre; si no, por nivel y nombre).
  /// [limit] y [offset] paginan en la consulta.
  Future<List<PokemonMoveEntry>> getMoves(
    int pokemonId, {
    required int versionGroupId,
    required int? methodId,
    required int limit,
    int offset = 0,
  }) async {
    final moveTable = attachedDatabase.moves;
    final typeTable = attachedDatabase.types;
    final query =
        select(pokemonMoves).join([
            innerJoin(moveTable, moveTable.id.equalsExp(pokemonMoves.moveId)),
            leftOuterJoin(typeTable, typeTable.id.equalsExp(moveTable.typeId)),
          ])
          ..where(_learned(pokemonId, versionGroupId, methodId))
          ..orderBy([
            if (methodId != null) OrderingTerm.asc(pokemonMoves.level),
            OrderingTerm.asc(moveTable.name),
          ])
          ..limit(limit, offset: offset);
    if (methodId == null) query.groupBy([pokemonMoves.moveId]);
    return query.map((row) {
      final move = row.readTable(moveTable);
      final type = row.readTableOrNull(typeTable);
      return (
        moveId: move.id,
        name: move.name,
        typeName: type?.name,
        typeNameEs: type?.nameEs,
        power: move.power,
        accuracy: move.accuracy,
        pp: move.pp,
        damageClassId: move.damageClassId,
        level: row.read(pokemonMoves.level)!,
      );
    }).get();
  }

  /// Inserta o actualiza [pokemon] y reemplaza sus tipos, stats y habilidades
  /// en una sola transacción (PS-06). [pokemon] debe traer el `id`.
  Future<void> upsertPokemon(
    PokemonsCompanion pokemon, {
    required List<({int slot, int typeId})> types,
    required List<({int statId, int baseStat})> stats,
    required List<({int slot, int abilityId, bool isHidden})> abilities,
  }) {
    final id = pokemon.id.value;
    return transaction(() async {
      await into(pokemons).insertOnConflictUpdate(pokemon);
      await (delete(pokemonTypes)..where((t) => t.pokemonId.equals(id))).go();
      await (delete(pokemonStats)..where((t) => t.pokemonId.equals(id))).go();
      await (delete(
        pokemonAbilities,
      )..where((t) => t.pokemonId.equals(id))).go();
      await batch((b) {
        b.insertAll(pokemonTypes, [
          for (final t in types)
            PokemonTypesCompanion.insert(
              pokemonId: id,
              slot: t.slot,
              typeId: t.typeId,
            ),
        ]);
        b.insertAll(pokemonStats, [
          for (final s in stats)
            PokemonStatsCompanion.insert(
              pokemonId: id,
              statId: s.statId,
              baseStat: s.baseStat,
            ),
        ]);
        b.insertAll(pokemonAbilities, [
          for (final a in abilities)
            PokemonAbilitiesCompanion.insert(
              pokemonId: id,
              slot: a.slot,
              abilityId: a.abilityId,
              isHidden: Value(a.isHidden),
            ),
        ]);
      });
    });
  }
}

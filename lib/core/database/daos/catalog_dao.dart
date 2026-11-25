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

/// La cadena evolutiva de un Pokémon: sus especies con el sprite del Pokémon
/// por defecto y las condiciones de cada evolución.
typedef EvolutionRows = ({
  int currentSpeciesId,
  List<({SpeciesRow species, String? spriteUrl})> members,
  List<SpeciesEvolutionRow> evolutions,
});

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
    SpeciesEvolutions,
  ],
)
class CatalogDao extends DatabaseAccessor<AppDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.attachedDatabase);

  /// Todos los Pokémon por id; vuelve a emitir cuando cambia la tabla.
  Stream<List<PokemonRow>> watchAllPokemon() =>
      (select(pokemons)..orderBy([(p) => OrderingTerm.asc(p.id)])).watch();

  /// Todos los Pokémon por id, cada uno con sus tipos por slot (uno o dos; la
  /// lista queda vacía si aún no tiene). Es una sola consulta con join: vuelve
  /// a emitir cuando cambia el catálogo o la tabla de tipos, y como cada lote
  /// de la sincronización es una transacción, emite una vez por lote.
  Stream<List<PokemonWithTypes>> watchPokemonWithTypes() {
    final typeTable = attachedDatabase.types;
    final query =
        select(pokemons).join([
          leftOuterJoin(
            pokemonTypes,
            pokemonTypes.pokemonId.equalsExp(pokemons.id),
          ),
          leftOuterJoin(typeTable, typeTable.id.equalsExp(pokemonTypes.typeId)),
        ])..orderBy([
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

  /// Un Pokémon con tipos, stats y habilidades; null si no existe. Vuelve a
  /// emitir cuando cambia su fila, que es lo que toca [upsertPokemon].
  Stream<PokemonDetailRows?> watchPokemonDetail(int id) {
    final typeTable = attachedDatabase.types;
    final abilityTable = attachedDatabase.abilities;
    return (select(pokemons)..where((p) => p.id.equals(id)))
        .watchSingleOrNull()
        .asyncMap((pokemon) async {
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
          return (
            pokemon: pokemon,
            types: types,
            stats: stats,
            abilities: abilities,
          );
        });
  }

  /// Guarda lo del detalle en una transacción y marca el Pokémon como
  /// sincronizado en [syncedAt].
  Future<void> saveDetail({
    required int pokemonId,
    required int speciesId,
    required DateTime syncedAt,
    required List<({int id, String? nameEs, String? shortEffect})> abilities,
    required List<({int moveId, int versionGroupId, int methodId, int level})>
    moves,
    List<int> chainSpeciesIds = const [],
    List<
          ({
            int speciesId,
            int fromSpeciesId,
            int ordinal,
            String? trigger,
            int? minLevel,
            int? minHappiness,
            String? timeOfDay,
            String? itemName,
          })
        >
        evolutions =
        const [],
    String? speciesNameEs,
    String? genusEs,
  }) => transaction(() async {
    final abilityTable = attachedDatabase.abilities;
    for (final a in abilities) {
      await (update(abilityTable)..where((t) => t.id.equals(a.id))).write(
        AbilitiesCompanion(
          nameEs: Value(a.nameEs),
          shortEffect: Value(a.shortEffect),
        ),
      );
    }
    await (delete(
      pokemonMoves,
    )..where((m) => m.pokemonId.equals(pokemonId))).go();
    await batch(
      (b) => b.insertAll(pokemonMoves, [
        for (final m in moves)
          PokemonMovesCompanion.insert(
            pokemonId: pokemonId,
            moveId: m.moveId,
            versionGroupId: m.versionGroupId,
            methodId: m.methodId,
            level: Value(m.level),
          ),
      ], mode: InsertMode.insertOrIgnore),
    );
    if (chainSpeciesIds.isNotEmpty) {
      await (delete(
        speciesEvolutions,
      )..where((e) => e.speciesId.isIn(chainSpeciesIds))).go();
      await batch(
        (b) => b.insertAll(speciesEvolutions, [
          for (final e in evolutions)
            SpeciesEvolutionsCompanion.insert(
              speciesId: e.speciesId,
              ordinal: e.ordinal,
              evolvesFromSpeciesId: e.fromSpeciesId,
              trigger: Value(e.trigger),
              minLevel: Value(e.minLevel),
              minHappiness: Value(e.minHappiness),
              timeOfDay: Value(e.timeOfDay),
              itemName: Value(e.itemName),
            ),
        ]),
      );
    }
    await (update(species)..where((s) => s.id.equals(speciesId))).write(
      SpeciesCompanion(nameEs: Value(speciesNameEs), genusEs: Value(genusEs)),
    );
    await (update(pokemons)..where((p) => p.id.equals(pokemonId))).write(
      PokemonsCompanion(detailSyncedAt: Value(syncedAt)),
    );
  });

  /// La cadena evolutiva de [pokemonId]; null si no está o no sabe su cadena.
  /// Vuelve a emitir cuando se guardan evoluciones.
  Stream<EvolutionRows?> watchEvolutions(int pokemonId) =>
      select(speciesEvolutions)
          .watch()
          .asyncMap((_) => _evolutionRows(pokemonId));

  Future<EvolutionRows?> _evolutionRows(int pokemonId) async {
    final pokemon = await getPokemon(pokemonId);
    if (pokemon == null) return null;
    final current = await (select(
      species,
    )..where((s) => s.id.equals(pokemon.speciesId))).getSingleOrNull();
    final chainId = current?.evolutionChainId;
    if (chainId == null) return null;

    final members =
        await (select(species)
              ..where((s) => s.evolutionChainId.equals(chainId))
              ..orderBy([(s) => OrderingTerm.asc(s.id)]))
            .get();
    final ids = [for (final m in members) m.id];
    final defaults = await (select(
      pokemons,
    )..where((p) => p.speciesId.isIn(ids) & p.isDefault.equals(true))).get();
    final sprites = {for (final p in defaults) p.speciesId: p.spriteUrl};
    final evolutions =
        await (select(speciesEvolutions)
              ..where((e) => e.speciesId.isIn(ids))
              ..orderBy([
                (e) => OrderingTerm.asc(e.speciesId),
                (e) => OrderingTerm.asc(e.ordinal),
              ]))
            .get();
    return (
      currentSpeciesId: pokemon.speciesId,
      members: [
        for (final m in members) (species: m, spriteUrl: sprites[m.id]),
      ],
      evolutions: evolutions,
    );
  }

  /// Indica si hay algún movimiento guardado de [pokemonId].
  Future<bool> hasMoves(int pokemonId) async =>
      (await (select(pokemonMoves)
                ..where((m) => m.pokemonId.equals(pokemonId))
                ..limit(1))
              .get())
          .isNotEmpty;

  /// Condición de las filas de [pokemonId] en [versionGroupId], de
  /// [methodId] o de cualquier método si es null.
  Expression<bool> _learned(int pokemonId, int versionGroupId, int? methodId) =>
      pokemonMoves.pokemonId.equals(pokemonId) &
      pokemonMoves.versionGroupId.equals(versionGroupId) &
      (methodId == null
          ? const Constant(true)
          : pokemonMoves.methodId.equals(methodId));

  /// Juegos (grupos de versiones) en los que [pokemonId] aprende movimientos,
  /// del más reciente al más antiguo, con su nombre si la referencia lo tiene.
  Future<List<({int id, String? name})>> getMoveGames(int pokemonId) async {
    final versionGroups = attachedDatabase.versionGroups;
    final query =
        selectOnly(pokemonMoves).join([
            leftOuterJoin(
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
            name: row.read(versionGroups.name),
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
    return await latestWhere(ofPokemon & pokemonMoves.methodId.equals(1)) ??
        await latestWhere(ofPokemon);
  }

  /// Cantidad de movimientos distintos de [pokemonId] en [versionGroupId] que
  /// muestra [getMoves] para [methodId].
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

  /// Cantidad de Pokémon del catálogo, como flujo.
  Stream<int> watchPokemonCount() {
    final count = pokemons.id.count();
    return (selectOnly(
      pokemons,
    )..addColumns([count])).map((row) => row.read(count)!).watchSingle();
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

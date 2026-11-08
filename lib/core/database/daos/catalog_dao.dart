import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/catalog_tables.dart';

part 'catalog_dao.g.dart';

/// Un Pokémon con sus tipos ya resueltos, por orden de slot.
typedef PokemonWithTypes = ({PokemonRow pokemon, List<TypeRow> types});

/// Acceso al catálogo de Pokémon y a sus tablas de relación.
@DriftAccessor(
  tables: [
    Species,
    SpeciesEggGroups,
    Pokemons,
    PokemonTypes,
    PokemonStats,
    PokemonAbilities,
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

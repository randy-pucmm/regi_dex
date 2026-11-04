import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/user_tables.dart';

part 'favorite_dao.g.dart';

/// Acceso a los favoritos del usuario.
@DriftAccessor(tables: [Favorites])
class FavoriteDao extends DatabaseAccessor<AppDatabase>
    with _$FavoriteDaoMixin {
  FavoriteDao(super.attachedDatabase);

  /// Favoritos, el más reciente primero.
  Stream<List<FavoriteRow>> watchFavorites() => (select(
    favorites,
  )..orderBy([(f) => OrderingTerm.desc(f.createdAt)])).watch();

  /// Ids de los Pokémon favoritos.
  Stream<Set<int>> watchFavoriteIds() =>
      select(favorites)
          .watch()
          .map((rows) => {for (final row in rows) row.pokemonId});

  /// Indica si [pokemonId] es favorito.
  Future<bool> isFavorite(int pokemonId) async =>
      await (select(
        favorites,
      )..where((f) => f.pokemonId.equals(pokemonId))).getSingleOrNull() !=
      null;

  /// Marca [pokemonId] como favorito; si ya lo era, no cambia nada.
  /// [createdAt] es la fecha de alta (por defecto, ahora).
  Future<void> addFavorite(int pokemonId, {DateTime? createdAt}) {
    return into(favorites).insert(
      FavoritesCompanion.insert(
        pokemonId: Value(pokemonId),
        createdAt: createdAt ?? DateTime.now(),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Quita [pokemonId] de los favoritos.
  Future<void> removeFavorite(int pokemonId) =>
      (delete(favorites)..where((f) => f.pokemonId.equals(pokemonId))).go();
}

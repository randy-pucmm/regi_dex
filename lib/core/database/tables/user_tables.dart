import 'package:drift/drift.dart';

// Datos del usuario (D11). Sin FK hacia el catálogo: la sync y la restauración
// de integridad nunca los tocan (PS-11, OF-21).

/// Favorito. `pokemonId` es solo un id de PokéAPI, no una FK.
@DataClassName('FavoriteRow')
class Favorites extends Table {
  @override
  String get tableName => 'favorite';

  IntColumn get pokemonId => integer()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get artworkLocalPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {pokemonId};
}

/// Preferencias en pares clave/valor: tema, idioma, filtros y orden.
@DataClassName('UserPreferenceRow')
class UserPreferences extends Table {
  @override
  String get tableName => 'user_preference';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

import '../../../core/database/daos/catalog_dao.dart';
import '../domain/pokemon.dart';

/// Indica si dos listas tienen los mismos Pokémon en el mismo orden. Sirve
/// para no volver a emitir cuando una tabla cambió pero la lista no.
bool samePokemonList(List<Pokemon> a, List<Pokemon> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Convierte un Pokémon con sus tipos, tal como sale de Drift, en la entidad
/// de dominio. Las filas de la BD no salen de la capa de datos.
Pokemon pokemonFromRows(PokemonWithTypes item) {
  final row = item.pokemon;
  return Pokemon(
    id: row.id,
    name: row.name,
    baseStatTotal: row.baseStatTotal,
    spriteUrl: row.spriteUrl,
    artworkUrl: row.artworkUrl,
    types: [
      for (final type in item.types)
        PokemonTypeRef(id: type.id, name: type.name, nameEs: type.nameEs),
    ],
  );
}

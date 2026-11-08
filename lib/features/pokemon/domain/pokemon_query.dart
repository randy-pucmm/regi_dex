/// Criterios para consultar el catálogo.
///
/// Hoy no tiene campos: la consulta vacía devuelve todo el catálogo ordenado
/// por número nacional. La búsqueda (RD-26) y los filtros y el orden (RD-27)
/// le agregarán campos sin cambiar el contrato del repositorio.
class PokemonQuery {
  const PokemonQuery();

  @override
  bool operator ==(Object other) => other is PokemonQuery;

  @override
  int get hashCode => (PokemonQuery).hashCode;
}

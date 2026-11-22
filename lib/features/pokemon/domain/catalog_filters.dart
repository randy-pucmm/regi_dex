/// Un valor elegible de un filtro (un tipo, una generación, un grupo huevo o una
/// habilidad) tal como lo muestra el panel de filtros.
class FilterOption {
  const FilterOption({required this.id, required this.label, this.key = ''});

  /// Id de PokéAPI: es lo que se guarda en `PokemonQuery`.
  final int id;

  /// Texto visible, en español si la referencia lo trae.
  final String label;

  /// Nombre en inglés de PokéAPI (`rock`); sirve para el color de un tipo.
  final String key;

  @override
  bool operator ==(Object other) =>
      other is FilterOption &&
      other.id == id &&
      other.label == label &&
      other.key == key;

  @override
  int get hashCode => Object.hash(id, label, key);
}

/// Todos los valores que ofrece cada filtro, desde los datos de referencia
/// guardados en el dispositivo (disponibles sin conexión).
class FilterOptions {
  const FilterOptions({
    this.types = const [],
    this.generations = const [],
    this.eggGroups = const [],
    this.abilities = const [],
  });

  static const empty = FilterOptions();

  final List<FilterOption> types;
  final List<FilterOption> generations;
  final List<FilterOption> eggGroups;
  final List<FilterOption> abilities;

  /// No hay ningún valor: la referencia aún no se descargó.
  bool get isEmpty =>
      types.isEmpty &&
      generations.isEmpty &&
      eggGroups.isEmpty &&
      abilities.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is FilterOptions &&
      _same(other.types, types) &&
      _same(other.generations, generations) &&
      _same(other.eggGroups, eggGroups) &&
      _same(other.abilities, abilities);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(types),
    Object.hashAll(generations),
    Object.hashAll(eggGroups),
    Object.hashAll(abilities),
  );

  static bool _same(List<FilterOption> a, List<FilterOption> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Cuántos Pokémon hay en el dispositivo frente al total de la Pokédex (RF-FIL-05).
class CatalogAvailability {
  const CatalogAvailability({required this.available, this.total});

  /// Pokémon guardados en la base local.
  final int available;

  /// Total que informó PokéAPI en la última sincronización de referencia, o
  /// null si todavía no se conoce.
  final int? total;

  /// El catálogo local está incompleto: se avisa «N de T disponibles sin
  /// conexión». Con el total desconocido no se avisa.
  bool get isPartial => total != null && available < total!;

  @override
  bool operator ==(Object other) =>
      other is CatalogAvailability &&
      other.available == available &&
      other.total == total;

  @override
  int get hashCode => Object.hash(available, total);
}

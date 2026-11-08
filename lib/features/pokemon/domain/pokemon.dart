/// Tipo elemental de un Pokémon, tal como lo muestra una lista del catálogo.
class PokemonTypeRef {
  const PokemonTypeRef({required this.id, required this.name, this.nameEs});

  /// Id del tipo en PokéAPI.
  final int id;

  /// Nombre en inglés (`grass`).
  final String name;

  /// Nombre en español, si la referencia lo trae.
  final String? nameEs;

  @override
  bool operator ==(Object other) =>
      other is PokemonTypeRef &&
      other.id == id &&
      other.name == name &&
      other.nameEs == nameEs;

  @override
  int get hashCode => Object.hash(id, name, nameEs);
}

/// Pokémon del catálogo con lo necesario para listarlo. Es inmutable: no se
/// debe modificar la lista [types].
class Pokemon {
  const Pokemon({
    required this.id,
    required this.name,
    required this.baseStatTotal,
    required this.types,
    this.spriteUrl,
    this.artworkUrl,
  });

  /// Número nacional (id de PokéAPI).
  final int id;
  final String name;

  /// Suma de las estadísticas base.
  final int baseStatTotal;

  /// Tipos por orden de slot: uno o dos.
  final List<PokemonTypeRef> types;
  final String? spriteUrl;
  final String? artworkUrl;

  @override
  bool operator ==(Object other) =>
      other is Pokemon &&
      other.id == id &&
      other.name == name &&
      other.baseStatTotal == baseStatTotal &&
      other.spriteUrl == spriteUrl &&
      other.artworkUrl == artworkUrl &&
      _sameTypes(other.types, types);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    baseStatTotal,
    spriteUrl,
    artworkUrl,
    Object.hashAll(types),
  );

  static bool _sameTypes(List<PokemonTypeRef> a, List<PokemonTypeRef> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

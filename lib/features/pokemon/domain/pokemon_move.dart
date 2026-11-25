enum MoveMethod {
  all(null, 'Todos'),
  levelUp(1, 'Nivel'),
  machine(4, 'MT'),
  tutor(3, 'Tutor'),
  egg(2, 'Huevo');

  const MoveMethod(this.id, this.label);

  /// Id de `move_learn_method` en PokéAPI; null junta todos los métodos.
  final int? id;
  final String label;
}

/// Clase de daño de un movimiento (`move_damage_class` de PokéAPI).
enum MoveCategory {
  status('Estado'),
  physical('Físico'),
  special('Especial');

  const MoveCategory(this.label);

  final String label;

  /// La de [damageClassId] (1 estado, 2 físico, 3 especial), o null.
  static MoveCategory? fromId(int? damageClassId) => switch (damageClassId) {
    1 => status,
    2 => physical,
    3 => special,
    _ => null,
  };
}

/// Movimientos que muestra cada página.
const movesPageSize = 10;

class PokemonMove {
  const PokemonMove({
    required this.id,
    required this.name,
    required this.level,
    this.category,
    this.typeName,
    this.typeNameEs,
    this.power,
    this.accuracy,
    this.pp,
  });

  final int id;
  final String name;
  final MoveCategory? category;
  final String? typeName;
  final String? typeNameEs;
  final int? power;
  final int? accuracy;
  final int? pp;

  /// Nivel en que lo aprende; 0 si no depende del nivel.
  final int level;
}

/// Una página de movimientos, contando desde 0, de [totalPages] páginas.
class MovePage {
  const MovePage({
    required this.moves,
    required this.page,
    required this.totalPages,
  });

  final List<PokemonMove> moves;
  final int page;
  final int totalPages;

  bool get hasPrevious => page > 0;
  bool get hasNext => page + 1 < totalPages;
}

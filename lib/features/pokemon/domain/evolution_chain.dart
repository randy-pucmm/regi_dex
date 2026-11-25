class EvolutionSpecies {
  const EvolutionSpecies({
    required this.id,
    required this.name,
    this.nameEs,
    this.spriteUrl,
  });

  final int id;
  final String name;
  final String? nameEs;
  final String? spriteUrl;

  String get displayName {
    final shown = nameEs ?? name;
    return shown.isEmpty
        ? shown
        : '${shown[0].toUpperCase()}${shown.substring(1)}';
  }
}

/// Una condición para evolucionar. Una evolución puede tener varias
/// alternativas.
class EvolutionStep {
  const EvolutionStep({
    this.trigger,
    this.minLevel,
    this.minHappiness,
    this.timeOfDay,
    this.itemName,
  });

  final String? trigger;
  final int? minLevel;
  final int? minHappiness;
  final String? timeOfDay;
  final String? itemName;

  /// La condición en texto, o vacío si no se conoce.
  String get label {
    final item = itemName;
    final parts = [
      if (minLevel != null) 'Nv. $minLevel',
      if (minHappiness != null) 'Felicidad $minHappiness',
      if (item != null) 'Usar ${item.replaceAll('-', ' ')}',
      if (trigger == 'trade') 'Intercambio',
      if (timeOfDay == 'day') 'de día',
      if (timeOfDay == 'night') 'de noche',
    ];
    if (parts.isEmpty) return trigger == 'level-up' ? 'Subir de nivel' : '';
    return parts.join(' · ');
  }
}

class EvolutionNode {
  const EvolutionNode({
    required this.species,
    required this.steps,
    required this.children,
  });

  final EvolutionSpecies species;

  /// Cómo se llega a esta especie; vacío en la primera de la cadena.
  final List<EvolutionStep> steps;
  final List<EvolutionNode> children;

  /// Las condiciones alternativas, sin repetir, separadas por «o».
  String get requirement =>
      steps.map((s) => s.label).where((l) => l.isNotEmpty).toSet().join(' o ');
}

/// Árbol evolutivo de una especie. [currentSpeciesId] es la que se está
/// mirando.
class EvolutionChain {
  const EvolutionChain({required this.roots, required this.currentSpeciesId});

  final List<EvolutionNode> roots;
  final int currentSpeciesId;

  bool get evolves => roots.any((root) => root.children.isNotEmpty);

  /// Nodos en orden de lectura con su profundidad.
  List<(EvolutionNode, int)> get flattened => [
    for (final root in roots) ..._walk(root, 0),
  ];

  static List<(EvolutionNode, int)> _walk(EvolutionNode node, int depth) => [
    (node, depth),
    for (final child in node.children) ..._walk(child, depth + 1),
  ];
}

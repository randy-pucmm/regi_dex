import '../../../core/database/daos/catalog_dao.dart';
import '../domain/evolution_chain.dart';

/// Arma el árbol evolutivo desde los pasos de la cadena. Cada especie puede
/// tener varias filas: una por condición alternativa.
EvolutionChain evolutionChainFromRows(EvolutionRows rows) {
  final stepsBySpecies = <int, List<EvolutionStep>>{};
  final names = <int, String>{};
  final fromOf = <int, int?>{};
  for (final row in rows.steps) {
    names[row.toSpeciesId] = row.toSpeciesName;
    fromOf[row.toSpeciesId] = row.fromSpeciesId;
    final steps = stepsBySpecies.putIfAbsent(row.toSpeciesId, () => []);
    if (row.fromSpeciesId != null) {
      steps.add(
        EvolutionStep(
          trigger: row.trigger,
          minLevel: row.minLevel,
          minHappiness: row.minHappiness,
          timeOfDay: row.timeOfDay,
          itemName: row.item,
        ),
      );
    }
  }

  EvolutionNode build(int id) {
    final extra = rows.species[id];
    return EvolutionNode(
      species: EvolutionSpecies(
        id: id,
        name: names[id]!,
        nameEs: extra?.nameEs,
        spriteUrl: extra?.spriteUrl,
      ),
      steps: stepsBySpecies[id]!,
      children: [
        for (final entry in fromOf.entries)
          if (entry.value == id) build(entry.key),
      ],
    );
  }

  return EvolutionChain(
    currentSpeciesId: rows.currentSpeciesId,
    roots: [
      for (final entry in fromOf.entries)
        if (entry.value == null) build(entry.key),
    ],
  );
}

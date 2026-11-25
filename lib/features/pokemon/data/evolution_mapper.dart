import '../../../core/database/daos/catalog_dao.dart';
import '../domain/evolution_chain.dart';

/// Arma el árbol evolutivo desde las filas de Drift. Devuelve null si la
/// cadena tiene varias especies pero aún no se descargaron sus condiciones.
EvolutionChain? evolutionChainFromRows(EvolutionRows rows) {
  if (rows.members.length > 1 && rows.evolutions.isEmpty) return null;

  final stepsBySpecies = {
    for (final e in rows.evolutions)
      e.speciesId: [
        for (final s in rows.evolutions)
          if (s.speciesId == e.speciesId) s,
      ],
  };
  final bySpecies = {for (final m in rows.members) m.species.id: m};
  final childrenOf = <int, List<int>>{};
  for (final entry in stepsBySpecies.entries) {
    (childrenOf[entry.value.first.evolvesFromSpeciesId] ??= []).add(entry.key);
  }

  EvolutionNode build(int id) {
    final member = bySpecies[id]!;
    return EvolutionNode(
      species: EvolutionSpecies(
        id: id,
        name: member.species.name,
        nameEs: member.species.nameEs,
        spriteUrl: member.spriteUrl,
      ),
      steps: [
        for (final e in stepsBySpecies[id] ?? const [])
          EvolutionStep(
            trigger: e.trigger,
            minLevel: e.minLevel,
            minHappiness: e.minHappiness,
            timeOfDay: e.timeOfDay,
            itemName: e.itemName,
          ),
      ],
      children: [
        for (final child in childrenOf[id] ?? const <int>[])
          if (bySpecies.containsKey(child)) build(child),
      ],
    );
  }

  return EvolutionChain(
    currentSpeciesId: rows.currentSpeciesId,
    roots: [
      for (final member in rows.members)
        if (!stepsBySpecies.containsKey(member.species.id))
          build(member.species.id),
    ],
  );
}

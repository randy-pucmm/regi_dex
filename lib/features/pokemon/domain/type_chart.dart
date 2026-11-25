import 'pokemon.dart';

class TypeChart {
  const TypeChart({required this.types, required this.percents});

  /// Sin datos: la referencia aún no se descargó.
  const TypeChart.empty() : types = const [], percents = const {};

  final List<PokemonTypeRef> types;

  /// Porcentaje de daño (0, 50, 100 o 200) por (atacante, defensor). Lo que
  /// no está se toma como 100.
  final Map<(int, int), int> percents;

  bool get isEmpty => types.isEmpty;

  double multiplier(int attackerId, List<int> defenderIds) => defenderIds.fold(
    1.0,
    (total, defender) =>
        total * (percents[(attackerId, defender)] ?? 100) / 100,
  );

  /// Tipos atacantes agrupados por su multiplicador contra [defenderIds], del
  /// más al menos efectivo y sin los neutros (×1).
  Map<double, List<PokemonTypeRef>> matchups(List<int> defenderIds) {
    final groups = <double, List<PokemonTypeRef>>{};
    for (final attacker in types) {
      final value = multiplier(attacker.id, defenderIds);
      if (value != 1) (groups[value] ??= []).add(attacker);
    }
    return Map.fromEntries(
      groups.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }
}

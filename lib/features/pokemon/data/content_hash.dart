import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Calcula el `content_hash` (OF-19, ADR-006) de un Pokémon del catálogo.
///
/// Es el SHA-1, en hexadecimal, de nombre, medidas, tipos, habilidades y stats
/// en forma canónica: cada lista se ordena por su clave, así que el orden de
/// entrada no cambia el resultado. Las URLs de sprite y artwork no cuentan.
/// Recibe primitivos para poder recalcularlo también desde filas de la BD.
String computeContentHash({
  required String name,
  required int height,
  required int weight,
  required Iterable<({int slot, int typeId})> types,
  required Iterable<({int slot, int abilityId, bool isHidden})> abilities,
  required Iterable<({int statId, int baseStat})> stats,
}) {
  final sortedTypes = types.toList()..sort((a, b) => a.slot.compareTo(b.slot));
  final sortedAbilities = abilities.toList()
    ..sort((a, b) => a.slot.compareTo(b.slot));
  final sortedStats = stats.toList()
    ..sort((a, b) => a.statId.compareTo(b.statId));

  final canonical = [
    name,
    height,
    weight,
    sortedTypes.map((t) => '${t.slot}:${t.typeId}').join(','),
    sortedAbilities
        .map((a) => '${a.slot}:${a.abilityId}:${a.isHidden ? 1 : 0}')
        .join(','),
    sortedStats.map((s) => '${s.statId}:${s.baseStat}').join(','),
  ].join('|');

  return sha1.convert(utf8.encode(canonical)).toString();
}

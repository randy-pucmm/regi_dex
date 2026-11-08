import 'package:flutter/material.dart';

/// Colores del LED por estado, según el rediseño.
abstract final class RegiLedColors {
  static const online = Color(0xFF4ADE80);

  /// Fondo de un ojo apagado.
  static const off = Color(0xFF05080A);

  /// Con el LED apagado solo colorea el texto y el borde.
  static const offline = Color(0xFFC4CACE);
  static const down = Color(0xFFFF5A5A);
  static const sync = Color(0xFFFFC53D);
}

/// Colores de la carcasa y las ventanas oscuras; no cambian entre temas.
abstract final class RegiInk {
  static const shell = Color(0xFF0A0C0D);
  static const onShell = Color(0xFFF2F4F5);
  static const onShellMuted = Color(0xFFB4BCC2);
  static const panel = Color(0xFF14181B);
}

/// Colores de los botones de destino de Inicio; no cambian con el tema.
abstract final class RegiHubColors {
  static const favorites = Color(0xFFFFC53D);
  static const trivia = Color(0xFF4DA3FF);
  static const teams = Color(0xFF4ADE80);
}

/// Las seis estadísticas base, en el orden de PokéAPI.
enum RegiStat {
  hp('PS', Color(0xFF4ADE80)),
  attack('ATAQUE', Color(0xFFFF6B6B)),
  defense('DEFENSA', Color(0xFFFFD54A)),
  specialAttack('AT. ESP.', Color(0xFFFFA24A)),
  specialDefense('DEF. ESP.', Color(0xFF4DA3FF)),
  speed('VELOCIDAD', Color(0xFF3FD6E8));

  const RegiStat(this.label, this.color);

  final String label;
  final Color color;
}

/// Colores de los 18 tipos, por clave de PokéAPI.
abstract final class RegiTypeColors {
  static const Map<String, Color> byKey = {
    'normal': Color(0xFFB9B28A),
    'fire': Color(0xFFFF9A57),
    'water': Color(0xFF6FA8F5),
    'electric': Color(0xFFF5D547),
    'grass': Color(0xFF7ED06B),
    'ice': Color(0xFF7FD6E0),
    'fighting': Color(0xFFE0735F),
    'poison': Color(0xFFC58AE0),
    'ground': Color(0xFFD9B76A),
    'flying': Color(0xFFA9B8F0),
    'psychic': Color(0xFFF58AB6),
    'bug': Color(0xFFB5CF55),
    'rock': Color(0xFFC8B560),
    'ghost': Color(0xFF9A8CCB),
    'dragon': Color(0xFF8F7CF0),
    'dark': Color(0xFF9C8C82),
    'steel': Color(0xFFB0B4CE),
    'fairy': Color(0xFFF0A8D8),
  };

  static Color of(String key) => byKey[key] ?? const Color(0xFF9AA3AA);
}

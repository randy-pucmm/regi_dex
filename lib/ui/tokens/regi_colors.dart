import 'package:flutter/material.dart';

/// Colores del indicador LED por estado, según el rediseño Regi.
abstract final class RegiLedColors {
  /// Verde: servicio disponible con datos remotos.
  static const online = Color(0xFF4ADE80);

  /// Punto apagado de cualquier LED: negro con borde para que se vea.
  static const off = Color(0xFF05080A);
  static const offRim = Color(0x80FFFFFF);

  /// Texto del estado «sin conexión» (el LED va apagado).
  static const offline = Color(0xFFC4CACE);

  /// Rojo: red activa pero PokéAPI sin respuesta.
  static const down = Color(0xFFFF5A5A);

  /// Amarillo: sincronizando.
  static const sync = Color(0xFFFFC53D);
}

/// Colores de la pantalla y la carcasa que no cambian entre temas.
abstract final class RegiInk {
  /// Fondo de la carcasa y de las pantallas oscuras.
  static const shell = Color(0xFF0A0C0D);
  static const onShell = Color(0xFFF2F4F5);
  static const onShellMuted = Color(0xFFB4BCC2);

  /// Panel de contenido en modo oscuro.
  static const panel = Color(0xFF14181B);
  static const panelRaised = Color(0xFF1E2327);
}

/// Borde y texto de los botones de destino de Inicio; no cambian con el tema.
abstract final class RegiHubColors {
  static const favorites = Color(0xFFFFC53D);
  static const trivia = Color(0xFF4DA3FF);
  static const teams = Color(0xFF4ADE80);
}

/// Colores de las seis estadísticas base, por orden de PokéAPI.
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

/// Colores de los 18 tipos, indexados por la clave de PokéAPI.
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

  /// Color de la clave de tipo, o un gris neutro si es desconocida.
  static Color of(String key) => byKey[key] ?? const Color(0xFF9AA3AA);
}

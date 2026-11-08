import 'package:flutter/material.dart';

import '../tokens/regi_colors.dart';
import '../tokens/regi_palette.dart';

/// Tokens propios de la Pokédex Regi (ADR-009), como `ThemeExtension`.
///
/// Las features no definen colores sueltos: los leen de aquí o del
/// `ColorScheme` del tema.
@immutable
class RegiTheme extends ThemeExtension<RegiTheme> {
  const RegiTheme({
    required this.variant,
    required this.shell,
    required this.onShell,
    required this.onShellMuted,
    required this.frame,
    required this.screen,
    required this.onScreen,
    required this.accent,
    required this.ledOnline,
    required this.ledOffline,
    required this.ledDown,
    required this.ledSync,
  });

  /// Tema Regi con los tokens de [variant] para el [brightness] dado.
  factory RegiTheme.forVariant(RegiVariant variant, Brightness brightness) {
    final swatch = RegiPalette.of(variant, brightness);
    final dark = brightness == Brightness.dark;
    return RegiTheme(
      variant: variant,
      shell: RegiInk.shell,
      onShell: RegiInk.onShell,
      onShellMuted: RegiInk.onShellMuted,
      // En claro el borde lleva el color de carcasa; en oscuro, el acento.
      frame: dark ? swatch.accent : swatch.shell,
      screen: dark ? RegiInk.panel : const Color(0xFFD9D5C8),
      onScreen: dark ? RegiInk.onShell : const Color(0xFF1B1F22),
      accent: swatch.accent,
      ledOnline: RegiLedColors.online,
      ledOffline: RegiLedColors.offline,
      ledDown: RegiLedColors.down,
      ledSync: RegiLedColors.sync,
    );
  }

  /// Tema Regi del [context] actual.
  static RegiTheme of(BuildContext context) =>
      Theme.of(context).extension<RegiTheme>()!;

  final RegiVariant variant;

  /// Cuerpo de la carcasa (cabecera, barra inferior) y su texto.
  final Color shell;
  final Color onShell;
  final Color onShellMuted;

  /// Borde de la carcasa.
  final Color frame;

  /// Fondo de la pantalla de contenido y su texto.
  final Color screen;
  final Color onScreen;

  /// Acento no textual: bordes, chips de filtro, puntos.
  final Color accent;

  /// Colores del LED por estado de conectividad.
  final Color ledOnline;
  final Color ledOffline;
  final Color ledDown;
  final Color ledSync;

  @override
  RegiTheme copyWith({
    RegiVariant? variant,
    Color? shell,
    Color? onShell,
    Color? onShellMuted,
    Color? frame,
    Color? screen,
    Color? onScreen,
    Color? accent,
    Color? ledOnline,
    Color? ledOffline,
    Color? ledDown,
    Color? ledSync,
  }) {
    return RegiTheme(
      variant: variant ?? this.variant,
      shell: shell ?? this.shell,
      onShell: onShell ?? this.onShell,
      onShellMuted: onShellMuted ?? this.onShellMuted,
      frame: frame ?? this.frame,
      screen: screen ?? this.screen,
      onScreen: onScreen ?? this.onScreen,
      accent: accent ?? this.accent,
      ledOnline: ledOnline ?? this.ledOnline,
      ledOffline: ledOffline ?? this.ledOffline,
      ledDown: ledDown ?? this.ledDown,
      ledSync: ledSync ?? this.ledSync,
    );
  }

  @override
  RegiTheme lerp(ThemeExtension<RegiTheme>? other, double t) {
    if (other is! RegiTheme) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return RegiTheme(
      // La variante es discreta: cambia a mitad de la transición.
      variant: t < 0.5 ? variant : other.variant,
      shell: mix(shell, other.shell),
      onShell: mix(onShell, other.onShell),
      onShellMuted: mix(onShellMuted, other.onShellMuted),
      frame: mix(frame, other.frame),
      screen: mix(screen, other.screen),
      onScreen: mix(onScreen, other.onScreen),
      accent: mix(accent, other.accent),
      ledOnline: mix(ledOnline, other.ledOnline),
      ledOffline: mix(ledOffline, other.ledOffline),
      ledDown: mix(ledDown, other.ledDown),
      ledSync: mix(ledSync, other.ledSync),
    );
  }
}

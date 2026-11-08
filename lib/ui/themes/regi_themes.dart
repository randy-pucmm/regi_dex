import 'package:flutter/material.dart';

import '../tokens/contrast.dart';
import '../tokens/regi_palette.dart';
import 'regi_theme.dart';

/// Fabrica los `ThemeData` Material 3 de los seis temas Regi.
abstract final class RegiThemes {
  /// Tema que usa la app hasta que el usuario elija otro (RD-34).
  static const defaultVariant = RegiVariant.regirock;

  static const _display = 'Chakra Petch';
  static const _body = 'Figtree';

  /// `ThemeData` de [variant] para el [brightness] dado.
  static ThemeData build(RegiVariant variant, Brightness brightness) {
    final regi = RegiTheme.forVariant(variant, brightness);
    final swatch = RegiPalette.of(variant, brightness);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: swatch.primary,
          brightness: brightness,
        ).copyWith(
          primary: swatch.primary,
          onPrimary: readableOn(swatch.primary),
          surface: regi.screen,
          onSurface: regi.onScreen,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: regi.screen,
      textTheme: _textTheme(regi.onScreen),
      extensions: [regi],
    );
  }

  /// Chakra Petch para títulos y etiquetas; Figtree para el cuerpo.
  static TextTheme _textTheme(Color color) {
    TextStyle display(double size, FontWeight weight, {double spacing = 0.5}) =>
        TextStyle(
          fontFamily: _display,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: spacing,
          color: color,
        );
    TextStyle body(double size, FontWeight weight) => TextStyle(
      fontFamily: _body,
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
    return TextTheme(
      displayLarge: display(40, FontWeight.w700),
      displayMedium: display(32, FontWeight.w700),
      displaySmall: display(28, FontWeight.w700),
      headlineLarge: display(26, FontWeight.w700),
      headlineMedium: display(22, FontWeight.w700),
      headlineSmall: display(20, FontWeight.w600),
      titleLarge: display(18, FontWeight.w700, spacing: 0.8),
      titleMedium: display(16, FontWeight.w600, spacing: 0.6),
      titleSmall: display(14, FontWeight.w600, spacing: 0.6),
      labelLarge: display(14, FontWeight.w600, spacing: 1),
      labelMedium: display(12, FontWeight.w600, spacing: 1),
      labelSmall: display(11, FontWeight.w500, spacing: 1),
      bodyLarge: body(16, FontWeight.w500),
      bodyMedium: body(14, FontWeight.w500),
      bodySmall: body(12, FontWeight.w500),
    );
  }
}

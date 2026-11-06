import 'package:flutter/material.dart';

/// Los seis temas Regi (ADR-009). Cada uno tiene variante clara y oscura.
enum RegiVariant {
  regirock('Regirock'),
  regice('Regice'),
  registeel('Registeel'),
  regigigas('Regigigas'),
  regieleki('Regieleki'),
  regidrago('Regidrago');

  const RegiVariant(this.displayName);

  final String displayName;
}

/// Colores base de un tema Regi en un brillo concreto.
///
/// - [shell]: color de la carcasa (borde y fondos de acento de la Pokédex).
/// - [primary]: color primario del `ColorScheme`.
/// - [accent]: acento no textual (bordes, puntos, resaltes).
@immutable
class RegiSwatch {
  const RegiSwatch({
    required this.shell,
    required this.primary,
    required this.accent,
  });

  final Color shell;
  final Color primary;
  final Color accent;
}

/// Tabla de paletas verificada (Arquitectura §8). Es la única fuente de
/// colores de tema: ninguna feature define colores sueltos.
abstract final class RegiPalette {
  static const Map<RegiVariant, RegiSwatch> light = {
    RegiVariant.regirock: RegiSwatch(
      shell: Color(0xFF8E4F2B),
      primary: Color(0xFF8A4B25),
      accent: Color(0xFFC46A12),
    ),
    RegiVariant.regice: RegiSwatch(
      shell: Color(0xFF5BB4E5),
      primary: Color(0xFF1E6CA4),
      accent: Color(0xFF1580B8),
    ),
    RegiVariant.registeel: RegiSwatch(
      shell: Color(0xFF5F6B77),
      primary: Color(0xFF4A5561),
      accent: Color(0xFFC93838),
    ),
    RegiVariant.regigigas: RegiSwatch(
      shell: Color(0xFFEDE5CF),
      primary: Color(0xFF7E6210),
      accent: Color(0xFF5E8C3A),
    ),
    RegiVariant.regieleki: RegiSwatch(
      shell: Color(0xFFF5C800),
      primary: Color(0xFF1F1F1F),
      accent: Color(0xFF0E8FA1),
    ),
    RegiVariant.regidrago: RegiSwatch(
      shell: Color(0xFF9C2F2F),
      primary: Color(0xFF8E2A2A),
      accent: Color(0xFFA8720F),
    ),
  };

  static const Map<RegiVariant, RegiSwatch> dark = {
    RegiVariant.regirock: RegiSwatch(
      shell: Color(0xFF5E3418),
      primary: Color(0xFFE6A673),
      accent: Color(0xFFF2A35A),
    ),
    RegiVariant.regice: RegiSwatch(
      shell: Color(0xFF1C4E6E),
      primary: Color(0xFF8FD3F4),
      accent: Color(0xFF6FC8EE),
    ),
    RegiVariant.registeel: RegiSwatch(
      shell: Color(0xFF39424B),
      primary: Color(0xFFB9C3CD),
      accent: Color(0xFFEE6B6B),
    ),
    RegiVariant.regigigas: RegiSwatch(
      shell: Color(0xFF4A4130),
      primary: Color(0xFFE2C25A),
      accent: Color(0xFF8DBF63),
    ),
    RegiVariant.regieleki: RegiSwatch(
      shell: Color(0xFF2A2A2A),
      primary: Color(0xFFFFD84D),
      accent: Color(0xFF3FD6E8),
    ),
    RegiVariant.regidrago: RegiSwatch(
      shell: Color(0xFF5C1C1C),
      primary: Color(0xFFF09A8A),
      accent: Color(0xFFE7B04A),
    ),
  };

  /// Paleta de [variant] para el [brightness] dado.
  static RegiSwatch of(RegiVariant variant, Brightness brightness) =>
      (brightness == Brightness.dark ? dark : light)[variant]!;
}

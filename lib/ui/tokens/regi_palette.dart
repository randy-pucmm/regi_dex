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

/// Única fuente de colores de tema: ninguna feature define colores sueltos.
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

  /// Modo oscuro = formas shiny, medidas sobre la foto normal/shiny. Regieleki
  /// va en blanco porque en su shiny cambian los anillos, no el cuerpo
  /// amarillo; Regigigas no sale en la foto y conserva el color del diseño.
  static const Map<RegiVariant, RegiSwatch> dark = {
    RegiVariant.regirock: RegiSwatch(
      shell: Color(0xFF5D3D2B),
      primary: Color(0xFFE1BFA6),
      accent: Color(0xFFCC8F6C),
    ),
    RegiVariant.regice: RegiSwatch(
      shell: Color(0xFF1B5E8C),
      primary: Color(0xFF8CCBEE),
      accent: Color(0xFF38ADE6),
    ),
    RegiVariant.registeel: RegiSwatch(
      shell: Color(0xFF2F5A47),
      primary: Color(0xFFBFE2D0),
      accent: Color(0xFF7ACBA3),
    ),
    RegiVariant.regigigas: RegiSwatch(
      shell: Color(0xFF4A4130),
      primary: Color(0xFFE2C25A),
      accent: Color(0xFF8DBF63),
    ),
    RegiVariant.regieleki: RegiSwatch(
      shell: Color(0xFF2A2A2A),
      primary: Color(0xFFC9D0D5),
      accent: Color(0xFFEEF1F3),
    ),
    RegiVariant.regidrago: RegiSwatch(
      shell: Color(0xFF2A4A68),
      primary: Color(0xFFA9C8E4),
      accent: Color(0xFF5A86B3),
    ),
  };

  static RegiSwatch of(RegiVariant variant, Brightness brightness) =>
      (brightness == Brightness.dark ? dark : light)[variant]!;
}

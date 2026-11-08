import 'package:flutter/painting.dart';

/// Relación de contraste WCAG 2.x entre dos colores opacos (de 1 a 21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

const _nearBlack = Color(0xFF10151A);
const _nearWhite = Color(0xFFFFFFFF);

/// Texto (casi negro o blanco) con mejor contraste sobre [background].
Color readableOn(Color background) =>
    contrastRatio(_nearBlack, background) >=
        contrastRatio(_nearWhite, background)
    ? _nearBlack
    : _nearWhite;

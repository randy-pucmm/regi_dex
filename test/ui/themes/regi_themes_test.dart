import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/ui/themes/regi_theme.dart';
import 'package:regi_dex/ui/themes/regi_themes.dart';
import 'package:regi_dex/ui/tokens/contrast.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

void main() {
  group('RegiThemes', () {
    // Los doce temas: seis Regis en claro y en oscuro.
    final themes = [
      for (final variant in RegiVariant.values)
        for (final brightness in Brightness.values)
          (
            '${variant.displayName} ${brightness.name}',
            RegiThemes.build(variant, brightness),
          ),
    ];

    test('cada tema expone la extensión RegiTheme de su variante', () {
      for (final (name, theme) in themes) {
        expect(theme.extension<RegiTheme>(), isNotNull, reason: name);
        expect(theme.useMaterial3, isTrue, reason: name);
      }
    });

    test('el texto cumple contraste ≥ 4.5:1', () {
      for (final (name, theme) in themes) {
        final regi = theme.extension<RegiTheme>()!;
        final scheme = theme.colorScheme;
        final pairs = {
          'onScreen/screen': (regi.onScreen, regi.screen),
          'onShell/shell': (regi.onShell, regi.shell),
          'onShellMuted/shell': (regi.onShellMuted, regi.shell),
          'onPrimary/primary': (scheme.onPrimary, scheme.primary),
          'onSurface/surface': (scheme.onSurface, scheme.surface),
        };
        for (final MapEntry(key: pair, value: (fg, bg)) in pairs.entries) {
          expect(
            contrastRatio(fg, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$name · $pair',
          );
        }
      }
    });

    test('el acento cumple ≥ 3:1 sobre la carcasa', () {
      for (final (name, theme) in themes) {
        final regi = theme.extension<RegiTheme>()!;
        expect(
          contrastRatio(regi.accent, regi.shell),
          greaterThanOrEqualTo(3),
          reason: name,
        );
      }
    });

    test('los seis marcos oscuros se distinguen entre sí', () {
      double distance(Color a, Color b) => math.sqrt(
        math.pow((a.r - b.r) * 255, 2) +
            math.pow((a.g - b.g) * 255, 2) +
            math.pow((a.b - b.b) * 255, 2),
      );
      Color frame(RegiVariant v) =>
          RegiTheme.forVariant(v, Brightness.dark).frame;

      for (final a in RegiVariant.values) {
        for (final b in RegiVariant.values.skip(a.index + 1)) {
          expect(
            distance(frame(a), frame(b)),
            greaterThanOrEqualTo(60),
            reason: '${a.displayName} / ${b.displayName}',
          );
        }
      }
    });

    test('el tema por defecto es Regirock', () {
      expect(RegiThemes.defaultVariant, RegiVariant.regirock);
    });
  });

  group('RegiTheme', () {
    test('lerp interpola los colores y cambia la variante a mitad', () {
      final a = RegiTheme.forVariant(RegiVariant.regirock, Brightness.light);
      final b = RegiTheme.forVariant(RegiVariant.regice, Brightness.light);

      expect(a.lerp(b, 0).accent, a.accent);
      expect(a.lerp(b, 1).accent, b.accent);
      expect(a.lerp(b, 0.25).variant, RegiVariant.regirock);
      expect(a.lerp(b, 0.75).variant, RegiVariant.regice);
    });

    test('copyWith reemplaza solo lo indicado', () {
      final a = RegiTheme.forVariant(RegiVariant.regirock, Brightness.dark);
      final b = a.copyWith(accent: const Color(0xFF123456));
      expect(b.accent, const Color(0xFF123456));
      expect(b.frame, a.frame);
      expect(b.variant, a.variant);
    });
  });
}

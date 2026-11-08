import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/ui/themes/regi_theme.dart';
import 'package:regi_dex/ui/themes/regi_themes.dart';
import 'package:regi_dex/ui/tokens/contrast.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

void main() {
  group('RegiThemes', () {
    for (final variant in RegiVariant.values) {
      for (final brightness in Brightness.values) {
        final name = '${variant.displayName} ${brightness.name}';

        test('$name expone la extensión RegiTheme de su variante', () {
          final theme = RegiThemes.build(variant, brightness);
          final regi = theme.extension<RegiTheme>();
          expect(regi, isNotNull);
          expect(regi!.variant, variant);
          expect(theme.brightness, brightness);
          expect(theme.useMaterial3, isTrue);
        });

        test('$name cumple contraste de texto ≥ 4.5:1', () {
          final theme = RegiThemes.build(variant, brightness);
          final regi = theme.extension<RegiTheme>()!;
          final scheme = theme.colorScheme;
          final pairs = {
            'onScreen/screen': (regi.onScreen, regi.screen),
            'onShell/shell': (regi.onShell, regi.shell),
            'onShellMuted/shell': (regi.onShellMuted, regi.shell),
            'onPrimary/primary': (scheme.onPrimary, scheme.primary),
            'onSurface/surface': (scheme.onSurface, scheme.surface),
          };
          for (final entry in pairs.entries) {
            final (fg, bg) = entry.value;
            expect(
              contrastRatio(fg, bg),
              greaterThanOrEqualTo(4.5),
              reason: '$name · ${entry.key}',
            );
          }
        });

        test('$name cumple contraste del acento ≥ 3:1 sobre la carcasa', () {
          final regi = RegiThemes.build(
            variant,
            brightness,
          ).extension<RegiTheme>()!;
          expect(
            contrastRatio(regi.accent, regi.shell),
            greaterThanOrEqualTo(3),
            reason: '$name · accent/shell',
          );
        });
      }
    }

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

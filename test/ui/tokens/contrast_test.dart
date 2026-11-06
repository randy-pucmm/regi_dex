import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/ui/tokens/contrast.dart';
import 'package:regi_dex/ui/tokens/regi_colors.dart';

void main() {
  group('contrastRatio', () {
    test('negro sobre blanco es 21:1', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
    });

    test('un color contra sí mismo es 1:1', () {
      expect(
        contrastRatio(const Color(0xFF8A4B25), const Color(0xFF8A4B25)),
        closeTo(1, 0.001),
      );
    });

    test('es simétrico', () {
      const a = Color(0xFF1E6CA4);
      const b = Color(0xFFEDE5CF);
      expect(contrastRatio(a, b), closeTo(contrastRatio(b, a), 1e-9));
    });
  });

  group('readableOn', () {
    test('elige texto oscuro sobre fondos claros y claro sobre oscuros', () {
      expect(
        readableOn(const Color(0xFFF5D547)).computeLuminance(),
        lessThan(.1),
      );
      expect(
        readableOn(const Color(0xFF1C4E6E)).computeLuminance(),
        greaterThan(.9),
      );
    });

    test('el texto de cada chip de tipo supera 4.5:1', () {
      for (final entry in RegiTypeColors.byKey.entries) {
        final ratio = contrastRatio(readableOn(entry.value), entry.value);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: entry.key);
      }
    });
  });
}

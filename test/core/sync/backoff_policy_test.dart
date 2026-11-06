import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/sync/backoff_policy.dart';

void main() {
  test('sin jitter la espera es 2 s × 2 con tope de 60 s', () {
    final policy = BackoffPolicy(jitter: 0);

    expect(
      [for (var attempt = 1; attempt <= 7; attempt++) policy.delayFor(attempt)],
      [
        const Duration(seconds: 2),
        const Duration(seconds: 4),
        const Duration(seconds: 8),
        const Duration(seconds: 16),
        const Duration(seconds: 32),
        const Duration(seconds: 60),
        const Duration(seconds: 60),
      ],
    );
  });

  test(
    'con jitter la espera varía como máximo ±20 % y nunca pasa del tope',
    () {
      final policy = BackoffPolicy(random: Random(42));
      final samples = <Duration>[];

      for (var attempt = 1; attempt <= 7; attempt++) {
        final base = min(2000 * pow(2, attempt - 1), 60000).toDouble();
        for (var i = 0; i < 200; i++) {
          final delay = policy.delayFor(attempt);
          samples.add(delay);
          expect(
            delay.inMilliseconds,
            greaterThanOrEqualTo((base * 0.8).floor()),
          );
          expect(delay.inMilliseconds, lessThanOrEqualTo(60000));
          expect(delay.inMilliseconds, lessThanOrEqualTo((base * 1.2).ceil()));
        }
      }
      expect(samples.toSet().length, greaterThan(50));
    },
  );

  test('con la misma semilla produce las mismas esperas', () {
    final a = BackoffPolicy(random: Random(7));
    final b = BackoffPolicy(random: Random(7));

    expect(
      [for (var i = 1; i <= 5; i++) a.delayFor(i)],
      [for (var i = 1; i <= 5; i++) b.delayFor(i)],
    );
  });

  test('permite 5 reintentos', () {
    final policy = BackoffPolicy();

    expect(
      [for (var made = 0; made <= 5; made++) policy.hasAttemptsLeft(made)],
      [true, true, true, true, true, false],
    );
  });
}

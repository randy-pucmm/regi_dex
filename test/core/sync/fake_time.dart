import 'package:clock/clock.dart';

/// Reloj controlado por la prueba.
class FakeTime {
  DateTime now = DateTime(2026, 11, 6, 10);

  void advance(Duration duration) => now = now.add(duration);

  /// Ejecuta [body] con este reloj como `clock`.
  Future<T> run<T>(Future<T> Function() body) =>
      withClock(Clock(() => now), body);
}

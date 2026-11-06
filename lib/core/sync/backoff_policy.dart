import 'dart:math';

/// Espera exponencial con jitter (PS-10): 2 s × 2, ±20 %, tope de 60 s y
/// 5 intentos. La usan el monitor de conectividad y la sincronización.
class BackoffPolicy {
  /// [random] permite fijar el jitter en las pruebas; con `jitter: 0` la
  /// espera es exacta.
  BackoffPolicy({
    this.initial = const Duration(seconds: 2),
    this.factor = 2,
    this.maxDelay = const Duration(seconds: 60),
    this.jitter = 0.2,
    this.maxAttempts = 5,
    Random? random,
  }) : _random = random ?? Random();

  final Duration initial;
  final double factor;
  final Duration maxDelay;

  /// Fracción de variación aleatoria: 0.2 equivale a ±20 %.
  final double jitter;

  /// Cantidad máxima de reintentos.
  final int maxAttempts;

  final Random _random;

  /// Espera antes del reintento número [attempt] (el primero es 1).
  /// Nunca supera [maxDelay].
  Duration delayFor(int attempt) {
    final base = initial.inMilliseconds * pow(factor, attempt - 1);
    final variation = 1 + (_random.nextDouble() * 2 - 1) * jitter;
    final milliseconds = min(base * variation, maxDelay.inMilliseconds * 1.0);
    return Duration(milliseconds: milliseconds.round());
  }

  /// Indica si, tras [attemptsMade] reintentos, todavía se puede reintentar.
  bool hasAttemptsLeft(int attemptsMade) => attemptsMade < maxAttempts;
}

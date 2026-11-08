/// Estados visuales del LED; los calcula `lib/app`.
enum LedState {
  online,
  offline,
  down,

  /// Sincronizando o verificando.
  sync,
}

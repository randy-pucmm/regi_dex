/// Estado de la sincronización con PokéAPI (D08), independiente de la
/// disponibilidad del servicio.
enum SyncStatus {
  /// No hay nada sincronizándose ni esperando.
  inactiva,

  /// Hay al menos un recurso sincronizándose.
  sincronizando,

  /// La última sincronización terminó bien.
  completada,

  /// La última sincronización falló.
  fallida,

  /// Falló y hay un reintento programado.
  esperandoReintento,
}

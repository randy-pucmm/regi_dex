/// Claves de la tabla `user_preference`.
abstract final class PreferenceKeys {
  /// Búsqueda, filtros y orden del catálogo, como JSON (RF-FIL-04).
  static const catalogQuery = 'catalog_query';

  /// Total de Pokémon que informó PokéAPI en la última sincronización de
  /// referencia, para el aviso de catálogo parcial (RF-FIL-05).
  static const catalogTotal = 'catalog_total';
}

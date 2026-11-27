/// Versión de los datos de Champions guardados y su atribución (RF-TB-10,
/// RNF-API-02).
class ChampionsInfo {
  const ChampionsInfo({
    required this.dataVersion,
    required this.generatedAt,
    required this.fetchedAt,
    required this.defaultSeason,
  });

  /// Texto de atribución que exige el servicio.
  static const attributionText =
      'Battle data provided by Pokémon Champions Battle Data';

  /// Enlace al servicio.
  static const attributionUrl = 'https://championsbattledata.com/';

  /// Versión del índice (`dataVersion`).
  final String dataVersion;

  /// Cuándo generó el servicio los datos: la «fecha de datos» que ve el usuario.
  final DateTime generatedAt;

  /// Cuándo se confirmó por última vez contra el servicio.
  final DateTime fetchedAt;

  final String defaultSeason;
}

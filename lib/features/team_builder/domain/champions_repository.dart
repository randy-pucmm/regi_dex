import 'champions_info.dart';
import 'champions_pokemon.dart';

/// Datos de Pokémon Champions para el Team Builder (RF-TB-02, RF-TB-09).
///
/// Todo se lee de la caché local; [refresh] la actualiza cuando hay servicio.
abstract interface class ChampionsRepository {
  /// Pokémon de la regulación vigente por nombre. Emite una lista vacía hasta
  /// que se descarga el índice por primera vez.
  Stream<List<ChampionsPokemon>> watchPool();

  /// Versión y fecha de los datos guardados, o null si aún no hay ninguno.
  Stream<ChampionsInfo?> watchInfo();

  /// Movimientos que [showdownId] puede aprender en Champions, por nombre.
  Future<List<String>> learnableMoves(String showdownId);

  /// Actualiza el índice si la caché tiene 24 h o más (o siempre con [force]).
  /// Sin red o con el servicio caído lanza un `Failure` y la caché sigue
  /// sirviendo.
  Future<void> refresh({bool force = false});
}

import 'package:clock/clock.dart';

import '../domain/pokemon_query.dart';
import 'catalog_local_source.dart';
import 'pokemon_mapper.dart';
import 'pokemon_remote_source.dart';

/// Respaldo remoto de la búsqueda (RF-CAT-03): cuando lo local no devuelve nada
/// pregunta a PokéAPI y **guarda** los resultados en la base; la pantalla los
/// muestra porque observa la base, nunca la respuesta.
///
/// Gasta una llamada del presupuesto. No pasa por el `SyncCoordinator` para no
/// alterar `sync_metadata` ni el estado global de sincronización del LED.
class RemoteSearch {
  RemoteSearch({required this._remote, required this._local});

  final PokemonRemoteSource _remote;
  final CatalogLocalSource _local;
  final _inFlight = <SearchTerm, Future<int>>{};

  /// Busca [term] en PokéAPI y guarda lo encontrado sin tocar el cursor del
  /// catálogo. Devuelve cuántos Pokémon guardó. Dos búsquedas iguales a la vez
  /// comparten una sola llamada. Un fallo se propaga y no guarda nada.
  Future<int> run(SearchTerm term) {
    final running = _inFlight[term];
    if (running != null) return running;
    // El bloque con llaves evita devolver el Future de `remove`: whenComplete
    // esperaría a ese mismo Future y no terminaría nunca.
    final future = _download(term).whenComplete(() {
      _inFlight.remove(term);
    });
    _inFlight[term] = future;
    return future;
  }

  Future<int> _download(SearchTerm term) async {
    final data = switch (term) {
      SearchNumber(:final number) => await _remote.searchPokemon(
        number: number,
      ),
      SearchName(:final text) => await _remote.searchPokemon(name: text),
    };
    final records = mapPokemonPage(data, clock.now());
    if (records.isEmpty) return 0;
    await _local.savePokemon(records);
    return records.length;
  }
}

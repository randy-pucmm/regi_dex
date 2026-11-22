import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/connectivity/service_status.dart';
import '../../../core/sync/sync_status.dart';
import '../domain/pokemon.dart';
import '../domain/pokemon_query.dart';

/// Consulta vigente del catálogo. La búsqueda se actualiza con un debounce de
/// 350 ms (RF-CAT-03): mientras se escribe no se consulta la base.
class CatalogSearch extends Notifier<PokemonQuery> {
  /// Espera tras la última tecla antes de buscar.
  static const debounce = Duration(milliseconds: 350);

  Timer? _timer;

  @override
  PokemonQuery build() {
    ref.onDispose(() => _timer?.cancel());
    return const PokemonQuery();
  }

  /// Programa la búsqueda de [text] para dentro de [debounce]; una pulsación
  /// nueva cancela la anterior.
  void setText(String text) {
    _timer?.cancel();
    _timer = Timer(debounce, () => state = state.copyWith(search: text));
  }

  /// Borra la búsqueda al instante, sin esperar el debounce.
  void clear() {
    _timer?.cancel();
    state = state.copyWith(search: '');
  }
}

final catalogQueryProvider = NotifierProvider<CatalogSearch, PokemonQuery>(
  CatalogSearch.new,
);

/// Pokémon de la base local que cumplen la consulta vigente.
final catalogResultsProvider = StreamProvider<List<Pokemon>>(
  (ref) => ref.watch(watchPokemonProvider)(ref.watch(catalogQueryProvider)),
);

/// Respaldo remoto de la búsqueda (RF-CAT-03). El estado es `true` mientras
/// consulta a PokéAPI.
///
/// Se dispara una vez por texto cuando la base local no devuelve nada, hay
/// servicio y el catálogo no se está descargando (en ese caso el Pokémon puede
/// llegar solo). Guarda los resultados en la base: la pantalla los recibe
/// porque observa la base, no la respuesta. Un fallo se ignora: queda en el
/// registro de llamadas y la búsqueda sigue sin resultados.
class CatalogRemoteSearch extends Notifier<bool> {
  String? _attempted;

  @override
  bool build() {
    ref.listen(catalogResultsProvider, (_, _) => _evaluate());
    ref.listen(serviceStatusProvider, (_, _) => _evaluate());
    ref.listen(syncStatusProvider, (_, _) => _evaluate());
    ref.listen(catalogQueryProvider, (_, _) => _evaluate());
    return false;
  }

  void _evaluate() {
    final search = ref.read(catalogQueryProvider).search.trim();
    if (search.isEmpty) {
      _attempted = null;
      return;
    }
    if (search == _attempted) return;
    final results = ref.read(catalogResultsProvider);
    final service = ref.read(serviceStatusProvider).value?.status;
    final sync = ref.read(syncStatusProvider).value;
    final noLocalResults = results.hasValue && results.requireValue.isEmpty;
    if (!noLocalResults ||
        results.isLoading ||
        service != ServiceStatus.online ||
        sync == SyncStatus.sincronizando) {
      return;
    }
    _attempted = search;
    unawaited(_run(search));
  }

  Future<void> _run(String search) async {
    if (!ref.mounted) return;
    state = true;
    try {
      await ref.read(searchPokemonRemoteProvider)(search);
    } on Object {
      // Sin respuesta útil: se queda en «Sin resultados».
    } finally {
      if (ref.mounted) state = false;
    }
  }
}

final catalogRemoteSearchProvider = NotifierProvider<CatalogRemoteSearch, bool>(
  CatalogRemoteSearch.new,
);

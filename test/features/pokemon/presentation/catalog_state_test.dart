import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/connectivity/service_status.dart';
import 'package:regi_dex/core/sync/sync_status.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_query.dart';
import 'package:regi_dex/features/pokemon/presentation/catalog_state.dart';

const _regirock = Pokemon(
  id: 377,
  name: 'regirock',
  baseStatTotal: 580,
  types: [],
);

CatalogState _state({
  AsyncValue<List<Pokemon>> pokemon = const AsyncData([]),
  SyncStatus sync = SyncStatus.inactiva,
  ServiceStatus service = ServiceStatus.online,
  PokemonQuery query = const PokemonQuery(),
  bool searchingRemote = false,
}) => catalogStateOf(
  pokemon: pokemon,
  sync: sync,
  service: service,
  query: query,
  searchingRemote: searchingRemote,
);

void main() {
  test('con datos los muestra, aunque la sync siga o haya fallado', () {
    for (final sync in SyncStatus.values) {
      final state = _state(pokemon: const AsyncData([_regirock]), sync: sync);

      expect(state, isA<CatalogLoaded>(), reason: '$sync');
      expect((state as CatalogLoaded).pokemon, [_regirock]);
    }
  });

  test('mientras no llega la primera lista o se descarga, está cargando', () {
    expect(_state(pokemon: const AsyncLoading()), isA<CatalogLoading>());
    expect(_state(sync: SyncStatus.sincronizando), isA<CatalogLoading>());
  });

  test('sin datos al arrancar con red, espera a que empiece la sync', () {
    expect(_state(), isA<CatalogLoading>());
    expect(_state(service: ServiceStatus.verificando), isA<CatalogLoading>());
  });

  test('sin datos y sin red es la primera ejecución sin conexión', () {
    expect(_state(service: ServiceStatus.offline), isA<CatalogEmpty>());
  });

  test(
    'sin datos y con la descarga fallida o el servicio caído es un error',
    () {
      expect(_state(sync: SyncStatus.fallida), isA<CatalogError>());
      expect(_state(sync: SyncStatus.esperandoReintento), isA<CatalogError>());
      expect(
        _state(service: ServiceStatus.servicioNoDisponible),
        isA<CatalogError>(),
      );
      expect(
        _state(pokemon: AsyncError(Exception('bd'), StackTrace.empty)),
        isA<CatalogError>(),
      );
    },
  );

  test('sin red gana sobre un fallo anterior: se pide conectarse', () {
    expect(
      _state(sync: SyncStatus.fallida, service: ServiceStatus.offline),
      isA<CatalogEmpty>(),
    );
  });

  group('con una búsqueda', () {
    const query = PokemonQuery(search: ' mew ');

    test('sin coincidencias es «sin resultados», con el texto recortado', () {
      final state = _state(query: query);

      expect(state, isA<CatalogNoResults>());
      final noResults = state as CatalogNoResults;
      expect(noResults.search, 'mew');
      expect(noResults.searching, isFalse);
      expect(noResults.offline, isFalse);
    });

    test('no depende de la sync: aunque haya fallado sigue sin resultados', () {
      for (final sync in [
        SyncStatus.inactiva,
        SyncStatus.completada,
        SyncStatus.fallida,
        SyncStatus.esperandoReintento,
      ]) {
        expect(
          _state(query: query, sync: sync),
          isA<CatalogNoResults>(),
          reason: '$sync',
        );
      }
      expect(
        _state(query: query, service: ServiceStatus.servicioNoDisponible),
        isA<CatalogNoResults>(),
      );
    });

    test('mientras se consulta PokéAPI o se descarga el catálogo, busca', () {
      expect(
        (_state(
          query: query,
          searchingRemote: true,
        ) as CatalogNoResults).searching,
        isTrue,
      );
      expect(
        (_state(
          query: query,
          sync: SyncStatus.sincronizando,
        ) as CatalogNoResults).searching,
        isTrue,
      );
    });

    test('sin conexión lo avisa', () {
      final state = _state(query: query, service: ServiceStatus.offline);

      expect((state as CatalogNoResults).offline, isTrue);
    });

    test('con coincidencias muestra la lista', () {
      expect(
        _state(query: query, pokemon: const AsyncData([_regirock])),
        isA<CatalogLoaded>(),
      );
    });

    test('una búsqueda en blanco no cuenta como búsqueda', () {
      expect(
        _state(
          query: const PokemonQuery(search: '  '),
          service: ServiceStatus.offline,
        ),
        isA<CatalogEmpty>(),
      );
    });

    test('mientras llega la lista sigue cargando', () {
      expect(
        _state(query: query, pokemon: const AsyncLoading()),
        isA<CatalogLoading>(),
      );
    });
  });
}

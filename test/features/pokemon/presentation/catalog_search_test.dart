// Búsqueda del catálogo: debounce de 350 ms, respaldo remoto y la cadena
// completa sobre una base real (PA-17).
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/core/connectivity/service_status.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/core/sync/sync_status.dart';
import 'package:regi_dex/features/pokemon/data/catalog_local_source.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_mapper.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_query.dart';
import 'package:regi_dex/features/pokemon/presentation/catalog_search.dart';
import 'package:regi_dex/features/pokemon/presentation/catalog_state.dart';

import '../../../core/database/database_test_helpers.dart';
import '../data/catalog_test_data.dart';
import '../data/fake_pokemon_remote.dart';
import '../fake_pokemon_repository.dart';

/// Búsqueda que fija el texto sin esperar el debounce.
class _InstantSearch extends CatalogSearch {
  void apply(String search) => state = PokemonQuery(search: search);
}

/// Repositorio falso con resultados locales y búsqueda remota controlables.
class _Repo extends FakePokemonRepository {
  /// Qué devuelve la base local para cada consulta.
  List<Pokemon> Function(PokemonQuery query) local = (_) => const [];

  /// Si no es null, `searchRemote` espera a que se complete.
  Completer<int>? gate;

  @override
  Stream<List<Pokemon>> watchPokemon(PokemonQuery query) {
    queries.add(query);
    return Stream.value(local(query));
  }

  @override
  Future<int> searchRemote(String search) async {
    remoteSearches.add(search);
    final error = searchError;
    if (error != null) throw error;
    return gate == null ? 0 : gate!.future;
  }
}

class _FailingSave extends FakePokemonRepository {
  @override
  Future<void> saveQuery(PokemonQuery query) async =>
      throw Exception('disco lleno');
}

class _SlowLoadRepo extends FakePokemonRepository {
  _SlowLoadRepo(this._load);

  final Future<PokemonQuery> _load;

  @override
  Future<PokemonQuery> loadQuery() => _load;

  @override
  Stream<List<Pokemon>> watchPokemon(PokemonQuery query) {
    queries.add(query);
    return Stream.value(const []);
  }
}

const _pikachu = Pokemon(
  id: 25,
  name: 'pikachu',
  baseStatTotal: 320,
  types: [],
);

/// Contenedor con un repositorio falso, sin base ni red.
ProviderContainer _fakeContainer([FakePokemonRepository? repo]) =>
    ProviderContainer(
      overrides: [
        pokemonRepositoryProvider.overrideWithValue(
          repo ?? FakePokemonRepository(),
        ),
      ],
    );

ProviderContainer _container(List overrides) {
  final container = ProviderContainer(overrides: List.from(overrides));
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('debounce de 350 ms', () {
    test('la consulta cambia 350 ms después de la última pulsación', () {
      fakeAsync((async) {
        final container = _fakeContainer();
        container.listen(catalogQueryProvider, (_, _) {});
        async.flushMicrotasks();
        final search = container.read(catalogQueryProvider.notifier);

        search.setText('p');
        async.elapse(const Duration(milliseconds: 200));
        search.setText('pi');
        async.elapse(const Duration(milliseconds: 349));
        expect(container.read(catalogQueryProvider), const PokemonQuery());

        async.elapse(const Duration(milliseconds: 1));
        expect(container.read(catalogQueryProvider).search, 'pi');
        container.dispose();
      });
    });

    test('muchas pulsaciones seguidas producen un solo cambio', () {
      fakeAsync((async) {
        final container = _fakeContainer();
        final changes = <String>[];
        container.listen(
          catalogQueryProvider,
          (_, next) => changes.add(next.search),
        );
        async.flushMicrotasks();
        final search = container.read(catalogQueryProvider.notifier);

        for (final text in ['p', 'pi', 'pik', 'pika']) {
          search.setText(text);
          async.elapse(const Duration(milliseconds: 100));
        }
        async.elapse(const Duration(seconds: 1));

        expect(changes, ['pika']);
        container.dispose();
      });
    });

    test('borrar es inmediato y cancela la búsqueda pendiente', () {
      fakeAsync((async) {
        final container = _fakeContainer();
        container.listen(catalogQueryProvider, (_, _) {});
        async.flushMicrotasks();
        final search = container.read(catalogQueryProvider.notifier);
        search.setText('pika');
        async.elapse(const Duration(milliseconds: 400));
        expect(container.read(catalogQueryProvider).search, 'pika');

        search.setText('raichu');
        search.clear();
        expect(container.read(catalogQueryProvider).search, '');
        async.elapse(const Duration(seconds: 1));

        expect(container.read(catalogQueryProvider).search, '');
        container.dispose();
      });
    });

    test('al cerrar el contenedor se cancela lo pendiente', () {
      fakeAsync((async) {
        final container = _fakeContainer();
        container.listen(catalogQueryProvider, (_, _) {});
        async.flushMicrotasks();
        container.read(catalogQueryProvider.notifier).setText('pika');

        container.dispose();

        expect(() => async.elapse(const Duration(seconds: 1)), returnsNormally);
        expect(async.nonPeriodicTimerCount, 0);
      });
    });

    test('catalogResultsProvider consulta con la búsqueda vigente', () async {
      final repo = _Repo();
      final container = _container([
        pokemonRepositoryProvider.overrideWithValue(repo),
        catalogQueryProvider.overrideWith(_InstantSearch.new),
      ]);
      container.listen(catalogResultsProvider, (_, _) {});
      await pumpEventQueue();

      (container.read(catalogQueryProvider.notifier) as _InstantSearch).apply(
        'pika',
      );
      await pumpEventQueue();

      expect(repo.queries, [
        const PokemonQuery(),
        const PokemonQuery(search: 'pika'),
      ]);
    });
  });

  group('filtros, orden y persistencia (RF-FIL-04)', () {
    late FakePokemonRepository repo;
    late ProviderContainer container;

    CatalogSearch controller() => container.read(catalogQueryProvider.notifier);
    PokemonQuery query() => container.read(catalogQueryProvider);

    Future<void> start([PokemonQuery stored = const PokemonQuery()]) async {
      repo = FakePokemonRepository()..storedQuery = stored;
      container = _fakeContainer(repo);
      container.listen(catalogQueryProvider, (_, _) {});
      await container.read(savedQueryProvider.future);
      await pumpEventQueue();
    }

    test('arranca con lo guardado en la sesión anterior', () async {
      const stored = PokemonQuery(
        search: 'reg',
        types: {6},
        sort: PokemonSort.baseTotal,
        descending: true,
      );

      await start(stored);

      expect(query(), stored);
    });

    test('sin nada guardado arranca con la consulta por defecto', () async {
      await start();

      expect(query(), const PokemonQuery());
    });

    test('toggle agrega y quita un valor de cada categoría', () async {
      await start();

      controller().toggle(FilterCategory.types, 6);
      controller().toggle(FilterCategory.types, 5);
      controller().toggle(FilterCategory.generations, 1);
      controller().toggle(FilterCategory.eggGroups, 3);
      controller().toggle(FilterCategory.abilities, 69);
      expect(query().types, {6, 5});
      expect(query().generations, {1});
      expect(query().eggGroups, {3});
      expect(query().abilities, {69});

      controller().toggle(FilterCategory.types, 6);
      expect(query().types, {5});
    });

    test('el estado nunca se puede modificar por fuera', () async {
      await start();
      controller().toggle(FilterCategory.types, 6);

      expect(() => query().types.add(1), throwsUnsupportedError);
    });

    test(
      'sortBy cambia el campo y, al repetirlo, invierte el sentido',
      () async {
        await start();

        controller().sortBy(PokemonSort.name);
        expect(query().sort, PokemonSort.name);
        expect(query().descending, isFalse);

        controller().sortBy(PokemonSort.name);
        expect(query().descending, isTrue);

        controller().sortBy(PokemonSort.baseTotal);
        expect(query().sort, PokemonSort.baseTotal);
        expect(query().descending, isFalse);
      },
    );

    test('toggleDirection invierte el sentido', () async {
      await start();

      controller().toggleDirection();
      expect(query().descending, isTrue);
      controller().toggleDirection();
      expect(query().descending, isFalse);
    });

    test(
      'clearFilters quita las categorías y conserva búsqueda y orden',
      () async {
        await start(
          const PokemonQuery(
            search: 'reg',
            types: {6},
            eggGroups: {3},
            sort: PokemonSort.name,
          ),
        );

        controller().clearFilters();

        expect(
          query(),
          const PokemonQuery(search: 'reg', sort: PokemonSort.name),
        );
      },
    );

    test('cada cambio se guarda', () async {
      await start();

      controller().toggle(FilterCategory.types, 6);
      controller().sortBy(PokemonSort.name);
      controller().clear();
      await pumpEventQueue();

      expect(repo.savedQueries, [
        const PokemonQuery(types: {6}),
        const PokemonQuery(types: {6}, sort: PokemonSort.name),
        const PokemonQuery(types: {6}, sort: PokemonSort.name),
      ]);
    });

    test('la búsqueda se guarda al pasar el debounce, no antes', () async {
      await start();

      controller().setText('pika');
      await pumpEventQueue();
      expect(repo.savedQueries, isEmpty);

      await Future<void>.delayed(
        CatalogSearch.debounce + const Duration(milliseconds: 50),
      );
      expect(repo.savedQueries, [const PokemonQuery(search: 'pika')]);
    });

    test('si guardar falla no se rompe nada', () async {
      await start();
      final failing = _FailingSave();
      container = _fakeContainer(failing);
      container.listen(catalogQueryProvider, (_, _) {});
      await container.read(savedQueryProvider.future);

      controller().toggle(FilterCategory.types, 6);
      await pumpEventQueue();

      expect(query().types, {6});
    });

    test('la lista espera a leer lo guardado antes de consultar', () async {
      final gate = Completer<PokemonQuery>();
      final repo = _SlowLoadRepo(gate.future);
      final container = _fakeContainer(repo);
      container.listen(catalogResultsProvider, (_, _) {});
      await pumpEventQueue();
      expect(repo.queries, isEmpty);

      gate.complete(const PokemonQuery(types: {6}));
      await pumpEventQueue();

      expect(repo.queries, [
        const PokemonQuery(types: {6}),
      ]);
    });
  });

  group('respaldo remoto', () {
    late _Repo repo;
    late StreamController<ConnectivitySnapshot> service;
    late StreamController<SyncStatus> sync;
    late ProviderContainer container;

    _InstantSearch search() =>
        container.read(catalogQueryProvider.notifier) as _InstantSearch;

    Future<void> start({
      ServiceStatus status = ServiceStatus.online,
      SyncStatus syncStatus = SyncStatus.inactiva,
    }) async {
      repo = _Repo();
      service = StreamController<ConnectivitySnapshot>();
      sync = StreamController<SyncStatus>();
      addTearDown(() async {
        await service.close();
        await sync.close();
      });
      container = _container([
        pokemonRepositoryProvider.overrideWithValue(repo),
        catalogQueryProvider.overrideWith(_InstantSearch.new),
        serviceStatusProvider.overrideWith((ref) => service.stream),
        syncStatusProvider.overrideWith((ref) => sync.stream),
      ]);
      service.add(ConnectivitySnapshot(status: status));
      sync.add(syncStatus);
      container.listen(catalogRemoteSearchProvider, (_, _) {});
      await pumpEventQueue();
    }

    test(
      'sin resultados locales y con servicio consulta una sola vez',
      () async {
        await start();

        search().apply('pika');
        await pumpEventQueue();

        expect(repo.remoteSearches, ['pika']);
      },
    );

    test('el mismo texto no se vuelve a consultar', () async {
      await start();
      search().apply('pika');
      await pumpEventQueue();

      service.add(const ConnectivitySnapshot(status: ServiceStatus.online));
      sync.add(SyncStatus.completada);
      await pumpEventQueue();

      expect(repo.remoteSearches, ['pika']);
    });

    test('un texto nuevo vuelve a consultar', () async {
      await start();

      search().apply('pika');
      await pumpEventQueue();
      search().apply('raichu');
      await pumpEventQueue();

      expect(repo.remoteSearches, ['pika', 'raichu']);
    });

    test('con resultados locales no consulta', () async {
      await start();
      repo.local = (_) => [_pikachu];

      search().apply('pika');
      await pumpEventQueue();

      expect(repo.remoteSearches, isEmpty);
    });

    test('sin búsqueda no consulta', () async {
      await start();

      search().apply('   ');
      await pumpEventQueue();

      expect(repo.remoteSearches, isEmpty);
    });

    test('sin conexión no consulta, y lo hace al volver la conexión', () async {
      await start(status: ServiceStatus.offline);

      search().apply('pika');
      await pumpEventQueue();
      expect(repo.remoteSearches, isEmpty);

      service.add(const ConnectivitySnapshot(status: ServiceStatus.online));
      await pumpEventQueue();
      expect(repo.remoteSearches, ['pika']);
    });

    test('con el servicio caído tampoco consulta', () async {
      await start(status: ServiceStatus.servicioNoDisponible);

      search().apply('pika');
      await pumpEventQueue();

      expect(repo.remoteSearches, isEmpty);
    });

    test('espera a que termine la descarga del catálogo', () async {
      await start(syncStatus: SyncStatus.sincronizando);

      search().apply('pika');
      await pumpEventQueue();
      expect(repo.remoteSearches, isEmpty);

      sync.add(SyncStatus.completada);
      await pumpEventQueue();
      expect(repo.remoteSearches, ['pika']);
    });

    test('mientras consulta el estado es «buscando»', () async {
      await start();
      repo.gate = Completer<int>();

      search().apply('pika');
      await pumpEventQueue();
      expect(container.read(catalogRemoteSearchProvider), isTrue);

      repo.gate!.complete(1);
      await pumpEventQueue();
      expect(container.read(catalogRemoteSearchProvider), isFalse);
    });

    test('un fallo se ignora y deja de estar «buscando»', () async {
      await start();
      repo.searchError = const NetworkFailure();

      search().apply('pika');
      await pumpEventQueue();

      expect(repo.remoteSearches, ['pika']);
      expect(container.read(catalogRemoteSearchProvider), isFalse);
    });

    test('borrar la búsqueda permite repetir el mismo texto', () async {
      await start();
      search().apply('pika');
      await pumpEventQueue();

      search().apply('');
      await pumpEventQueue();
      search().apply('pika');
      await pumpEventQueue();

      expect(repo.remoteSearches, ['pika', 'pika']);
    });
  });

  group('sobre la base real (PA-17)', () {
    late AppDatabase db;
    late FakePokemonRemote remote;
    late StreamController<ConnectivitySnapshot> service;
    late ProviderContainer container;

    _InstantSearch search() =>
        container.read(catalogQueryProvider.notifier) as _InstantSearch;

    /// Escribe [text] y espera a que la lista y el respaldo se asienten.
    Future<CatalogState> searchFor(String text) async {
      search().apply(text);
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      return container.read(catalogStateProvider);
    }

    List<String> names(CatalogState state) => [
      for (final p in (state as CatalogLoaded).pokemon) p.name,
    ];

    Future<void> start(ServiceStatus status) async {
      db = createTestDatabase();
      await CatalogLocalSource(db)
          .saveReference(mapReferenceData(syntheticReference()));
      await seedSearchCatalog(db);
      remote = FakePokemonRemote();
      service = StreamController<ConnectivitySnapshot>();
      service.add(ConnectivitySnapshot(status: status));
      container = _container([
        appDatabaseProvider.overrideWithValue(db),
        pokemonRemoteSourceProvider.overrideWithValue(remote),
        catalogQueryProvider.overrideWith(_InstantSearch.new),
        serviceStatusProvider.overrideWith((ref) => service.stream),
        syncStatusProvider.overrideWith(
          (ref) => Stream.value(SyncStatus.inactiva),
        ),
      ]);
      container.listen(catalogStateProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    tearDown(() async {
      await service.close();
      container.dispose();
      await db.close();
    });

    test(
      '«377» y «#0378» devuelven Regirock y Regice, también sin red',
      () async {
        await start(ServiceStatus.offline);

        expect(names(await searchFor('377')), ['regirock']);
        expect(names(await searchFor('#0378')), ['regice']);
        expect(remote.searches, isEmpty);
      },
    );

    test('«pika» y «25» devuelven Pikachu', () async {
      await start(ServiceStatus.offline);

      expect(names(await searchFor('pika')), ['pikachu']);
      expect(names(await searchFor('25')), ['pikachu']);
    });

    test('al borrar la búsqueda vuelve todo el catálogo', () async {
      await start(ServiceStatus.offline);
      await searchFor('377');

      expect(names(await searchFor('')), hasLength(5));
    });

    test(
      'sin red y sin coincidencias queda «sin resultados» y sin llamadas',
      () async {
        await start(ServiceStatus.offline);

        final state = await searchFor('mewtwo');

        expect(state, isA<CatalogNoResults>());
        expect((state as CatalogNoResults).offline, isTrue);
        expect(remote.searches, isEmpty);
      },
    );

    test(
      'con red y sin coincidencias locales consulta, guarda y muestra',
      () async {
        await start(ServiceStatus.online);
        remote.searchResultIds = [700];

        final state = await searchFor('700');

        expect(remote.searches, ['numero:700']);
        expect(names(state), ['pokemon-700']);
        // Quedó en la base: ahora se encuentra sin red.
        expect(await db.catalogDao.getPokemon(700), isNotNull);
      },
    );

    test('con red pero sin nada en PokéAPI queda «sin resultados»', () async {
      await start(ServiceStatus.online);

      final state = await searchFor('mewtwo');

      expect(remote.searches, ['nombre:mewtwo']);
      expect(state, isA<CatalogNoResults>());
      expect((state as CatalogNoResults).searching, isFalse);
    });

    test('con red y coincidencias locales no gasta llamadas', () async {
      await start(ServiceStatus.online);

      await searchFor('reg');

      expect(remote.searches, isEmpty);
    });

    test('si PokéAPI falla queda «sin resultados» sin romper', () async {
      await start(ServiceStatus.online);
      remote.failSearch = true;

      final state = await searchFor('mewtwo');

      expect(state, isA<CatalogNoResults>());
      expect((state as CatalogNoResults).searching, isFalse);
    });
  });
}

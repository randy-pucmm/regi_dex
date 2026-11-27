import '../domain/champions_info.dart';
import '../domain/champions_pokemon.dart';
import '../domain/champions_repository.dart';
import 'champions_local_source.dart';
import 'champions_sync.dart';

/// [ChampionsRepository] sobre la caché de Drift y la sincronización de 24 h.
class ChampionsRepositoryImpl implements ChampionsRepository {
  ChampionsRepositoryImpl({required this._local, required this._sync});

  final ChampionsLocalSource _local;
  final ChampionsSync _sync;

  @override
  Stream<List<ChampionsPokemon>> watchPool() async* {
    // El catálogo de PokéAPI puede haber llegado después que Champions.
    await _local.resolvePokeApiIds();
    yield* _local.watchPool();
  }

  @override
  Stream<ChampionsInfo?> watchInfo() => _local.watchInfo();

  @override
  Future<List<String>> learnableMoves(String showdownId) =>
      _local.learnableMoves(showdownId);

  @override
  Future<void> refresh({bool force = false}) async {
    await _sync.sync(force: force);
  }
}

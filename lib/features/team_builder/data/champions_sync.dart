import 'dart:async';
import 'dart:isolate';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/champions_config.dart';
import '../../../core/sync/sync_coordinator.dart';
import '../../pokemon/data/catalog_sync.dart' show Offload;
import 'champions_local_source.dart';
import 'champions_mapper.dart';
import 'champions_remote_source.dart';

/// Resultado de [ChampionsSync.sync].
class ChampionsSyncResult {
  const ChampionsSyncResult({required this.fetched, required this.replaced});

  /// La caché estaba vigente: no se hizo ninguna llamada.
  static const fresh = ChampionsSyncResult(fetched: false, replaced: false);

  /// Se descargó el índice.
  final bool fetched;

  /// El `dataVersion` era distinto y se reemplazaron los datos.
  final bool replaced;
}

/// Sincronización del índice de Champions (RF-TB-02, RNF-API-02, D16).
///
/// Uso: `sync.sync()` al abrir el Team Builder. Si el índice falta o tiene 24 h
/// o más, lo descarga, lo valida y lo traduce en un isolate y lo guarda solo si
/// cambió el `dataVersion`; si no cambió, únicamente renueva la fecha de
/// confirmación. El coordinador aporta el single-flight y el registro en
/// `sync_metadata` bajo la clave `champions`. Un fallo deja la caché anterior.
class ChampionsSync {
  ChampionsSync({
    required this._remote,
    required this._local,
    required this._coordinator,
    Offload? offload,
    void Function(String message)? log,
  }) : _offload = offload ?? Isolate.run,
       _log = log ?? debugPrint;

  /// Clave de `sync_metadata` del índice.
  static const resourceKey = 'champions';

  final ChampionsRemoteSource _remote;
  final ChampionsLocalSource _local;
  final SyncCoordinator _coordinator;
  final Offload _offload;
  final void Function(String message) _log;

  /// Indica si el índice se confirmó hace menos de 24 h.
  Future<bool> isFresh() async {
    final fetchedAt = await _local.readFetchedAt();
    return fetchedAt != null &&
        clock.now().difference(fetchedAt) < championsCacheMaxAge;
  }

  /// Actualiza el índice si falta o venció; con [force] lo descarga siempre.
  /// Devuelve si hubo llamada y si cambiaron los datos. Un fallo se propaga
  /// al coordinador y la caché anterior queda intacta.
  Future<ChampionsSyncResult> sync({bool force = false}) async {
    if (!force && await isFresh()) return ChampionsSyncResult.fresh;
    return _coordinator.run<ChampionsSyncResult>(resourceKey, _download);
  }

  Future<ChampionsSyncResult> _download() async {
    final body = await _remote.fetchIndex();
    final now = clock.now();
    final record = await _parse(_offload, body, now, _remote.baseUrl);

    final replaced = await _local.readDataVersion() != record.dataVersion;
    if (replaced) {
      await _local.replaceIndex(record);
    } else {
      await _local.touch(now);
    }
    await _local.resolvePokeApiIds();
    final check = await _local.checkLearnsets();
    if (!check.versionGroupKnown) {
      _log(
        '[Champions] el version group champions (32) aún no está en PokéAPI local',
      );
    } else if (check.movesMissingInPokeApi > 0) {
      _log(
        '[Champions] ${check.movesMissingInPokeApi} movimientos de Champions '
        'no figuran en PokéAPI (${check.pokemonChecked} Pokémon comparados)',
      );
    }
    return ChampionsSyncResult(fetched: true, replaced: replaced);
  }
}

// Función de nivel superior para que el closure que viaja al isolate solo
// capture los datos y no `this` (ver CatalogSync).
Future<ChampionsIndexRecord> _parse(
  Offload offload,
  Uint8List body,
  DateTime fetchedAt,
  String baseUrl,
) => offload(() => mapChampionsIndex(body, fetchedAt, baseUrl));

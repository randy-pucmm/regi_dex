import 'dart:isolate';

import 'package:clock/clock.dart';

import '../../../core/sync/sync_coordinator.dart';
import 'catalog_local_source.dart';
import 'catalog_sync.dart';
import 'pokemon_detail_mapper.dart';
import 'pokemon_remote_source.dart';

/// Resultado de [DetailSync.sync].
class DetailSyncResult {
  const DetailSyncResult({required this.fetched, required this.changed});

  /// El detalle estaba vigente: no se hizo ninguna llamada.
  static const fresh = DetailSyncResult(fetched: false, changed: false);

  /// Se descargó el detalle (una llamada).
  final bool fetched;

  /// El `content_hash` remoto difería del recalculado en local, o el Pokémon no
  /// estaba en el catálogo: el remoto gana y se sobrescribió lo local (ADR-006).
  final bool changed;
}

/// Sincronización del detalle bajo demanda (OF-20, PS-03, PS-07, UC-04).
///
/// Uso: `detailSync.sync(id)` al abrir un detalle. Si el detalle falta o venció
/// hace 3 días o más, hace **una sola llamada** (GetPokemonDetail, que incluye
/// la cadena evolutiva), compara con lo local y lo guarda todo o nada. El
/// coordinador aporta el single-flight por Pokémon y el registro en
/// `sync_metadata` bajo la clave `detail:{id}`.
class DetailSync {
  DetailSync({
    required this._remote,
    required this._local,
    required this._coordinator,
    Offload? offload,
  }) : _offload = offload ?? Isolate.run;

  /// Vigencia del detalle (PS-03). Pasado el plazo el dato se sigue mostrando
  /// y se refresca cuando hay servicio y presupuesto.
  static const detailMaxAge = Duration(days: 3);

  /// Prefijo de las claves de `sync_metadata` de los detalles.
  static const keyPrefix = 'detail:';

  /// Clave de `sync_metadata` del detalle de [pokemonId].
  static String resourceKey(int pokemonId) => '$keyPrefix$pokemonId';

  final PokemonRemoteSource _remote;
  final CatalogLocalSource _local;
  final SyncCoordinator _coordinator;
  final Offload _offload;

  /// Indica si el detalle de [pokemonId] se descargó hace menos de [detailMaxAge].
  Future<bool> isFresh(int pokemonId) async {
    final syncedAt = (await _local.readPokemon(pokemonId))?.detailSyncedAt;
    return syncedAt != null && clock.now().difference(syncedAt) < detailMaxAge;
  }

  /// Descarga y guarda el detalle de [pokemonId] si falta o venció; con [force]
  /// lo descarga siempre. Devuelve si hubo llamada y si lo remoto difería de lo
  /// local. Un fallo conserva intacto el detalle anterior y se propaga al
  /// coordinador, que lo registra en `sync_metadata`.
  Future<DetailSyncResult> sync(int pokemonId, {bool force = false}) async {
    if (!force && await isFresh(pokemonId)) return DetailSyncResult.fresh;
    return _coordinator.run<DetailSyncResult>(
      resourceKey(pokemonId),
      () => _download(pokemonId),
    );
  }

  Future<DetailSyncResult> _download(int pokemonId) async {
    final data = await _remote.fetchDetail(pokemonId);
    final record = await _mapDetail(_offload, data, clock.now());

    final localHash = await _local.localContentHash(pokemonId);
    await _local.saveDetail(record);
    return DetailSyncResult(
      fetched: true,
      changed: localHash != record.contentHash,
    );
  }
}

// Función de nivel superior para que el closure que viaja al isolate solo
// capture los datos y no `this` (ver CatalogSync).
Future<PokemonDetailRecord> _mapDetail(
  Offload offload,
  Map<String, dynamic> data,
  DateTime syncedAt,
) => offload(() => mapPokemonDetail(data, syncedAt));

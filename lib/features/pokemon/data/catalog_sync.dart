import 'dart:async';
import 'dart:isolate';

import 'package:clock/clock.dart';

import '../../../core/sync/sync_coordinator.dart';
import 'catalog_local_source.dart';
import 'pokemon_mapper.dart';
import 'pokemon_remote_source.dart';

/// Ejecuta [computation] fuera del hilo principal. Por defecto `Isolate.run`;
/// las pruebas pueden inyectar una versión en línea.
typedef Offload = Future<R> Function<R>(FutureOr<R> Function() computation);

/// Sincronización del catálogo (OF-01, OF-02, PS-02, PS-07, D13).
///
/// Uso: `coordinator.run(CatalogSync.resourceKey, sync.execute)`. El
/// coordinador aporta el single-flight y el registro en `sync_metadata`.
class CatalogSync {
  CatalogSync({
    required this._remote,
    required this._local,
    required this._coordinator,
    this.pageSize = defaultPageSize,
    Offload? offload,
  }) : _offload = offload ?? Isolate.run;

  /// Clave de `sync_metadata` del catálogo ligero.
  static const resourceKey = 'catalog';

  /// Clave de `sync_metadata` de los datos de referencia.
  static const referenceKey = 'reference';

  /// Pokémon por página de GetPokemonPage.
  static const defaultPageSize = 200;

  /// Vigencia de los datos de referencia (PS-03).
  static const referenceMaxAge = Duration(days: 30);

  final PokemonRemoteSource _remote;
  final CatalogLocalSource _local;
  final SyncCoordinator _coordinator;
  final Offload _offload;

  /// Pokémon que se piden por página.
  final int pageSize;

  /// Descarga la referencia (si falta o venció) y luego el catálogo por lotes
  /// desde el cursor guardado. Cada lote se valida y mapea en un isolate y se
  /// guarda con el avance del cursor en una transacción. Termina con la
  /// primera página incompleta y deja el cursor en 0. Cualquier fallo
  /// conserva los lotes ya confirmados y se propaga al coordinador.
  Future<void> execute() async {
    await _ensureReference();

    var offset = await _local.readCursor(resourceKey);
    while (true) {
      final data = await _remote.fetchPage(offset: offset, limit: pageSize);
      final syncedAt = clock.now();
      final records = await _offload(() => mapPokemonPage(data, syncedAt));

      final isLast = records.length < pageSize;
      final nextOffset = isLast ? 0 : offset + records.length;
      await _local.saveBatch(resourceKey, records, nextOffset: nextOffset);
      if (isLast) return;
      offset = nextOffset;
    }
  }

  /// Sincroniza la referencia si no se hizo en los últimos [referenceMaxAge].
  /// El catálogo la necesita primero por las claves foráneas.
  Future<void> _ensureReference() async {
    if (await _local.isReferenceFresh(referenceKey, referenceMaxAge)) return;
    await _coordinator.run<void>(referenceKey, () async {
      final data = await _remote.fetchReference();
      final records = await _offload(() => mapReferenceData(data));
      await _local.saveReference(records);
    });
  }
}

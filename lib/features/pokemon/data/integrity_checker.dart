import 'dart:async';
import 'dart:isolate';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/sync_metadata_dao.dart';
import '../../../core/sync/api_budget.dart';
import '../../../core/sync/sync_coordinator.dart';
import 'catalog_local_source.dart';
import 'catalog_sync.dart';
import 'pokemon_mapper.dart';
import 'pokemon_remote_source.dart';

/// Resultado de una verificación de [IntegrityChecker].
class IntegrityReport {
  const IntegrityReport({
    this.checked = 0,
    this.restored = const [],
    this.skipped = false,
    this.error,
  });

  /// No se hizo nada: sin servicio o sin Pokémon en el catálogo.
  static const nothing = IntegrityReport(skipped: true);

  /// Pokémon comparados con el remoto.
  final int checked;

  /// Ids que se restauraron porque no coincidían (el remoto gana).
  final List<int> restored;

  /// No hubo qué verificar o no se pudo salir (ver [error] si falló).
  final bool skipped;

  /// El fallo que cortó la verificación, si lo hubo.
  final Object? error;

  bool get isSuccess => error == null && !skipped;
}

/// Detecta y restaura datos del catálogo alterados en el dispositivo
/// (OF-19, OF-20, OF-21, ADR-006, D14).
///
/// Cada verificación recalcula el hash de las filas locales y arma un lote de
/// hasta [batchSize] ids: primero los que no coinciden con su `content_hash` y
/// luego los siguientes de un recorrido rotativo del catálogo. Pide ese lote
/// a PokéAPI (`GetPokemonsByIds`, una llamada) y, si algo difiere del remoto,
/// lo restaura en una transacción: **el remoto gana**. Solo escribe tablas del
/// catálogo, nunca las del usuario.
///
/// Uso: `await checker.verify()` al iniciar, al reconectar y cada 30 min;
/// `verifyPokemon(id)` al abrir un detalle. Nunca lanza: el fallo queda en
/// [IntegrityReport.error], en la consola y en `sync_metadata` (`integrity`).
/// No pasa por el `SyncCoordinator` para no encender el LED «Sincronizando».
class IntegrityChecker {
  /// [isOnline] dice si hay servicio; sin él no se hace ninguna llamada.
  /// [reserve] son las llamadas del presupuesto que se dejan libres para la
  /// interacción del usuario: con menos cupo solo se verifican los marcados.
  IntegrityChecker({
    required this._remote,
    required this._local,
    required this._metadata,
    required this._budget,
    required this._isOnline,
    this.batchSize = defaultBatchSize,
    this.reserve = 10,
    Offload? offload,
    void Function(String message)? log,
  }) : _offload = offload ?? Isolate.run,
       _log = log ?? debugPrint;

  /// Clave de `sync_metadata`: su `cursorOffset` es el último id verificado.
  static const resourceKey = 'integrity';

  /// Ids por llamada de `GetPokemonsByIds`.
  static const defaultBatchSize = 200;

  final PokemonRemoteSource _remote;
  final CatalogLocalSource _local;
  final SyncMetadataDao _metadata;
  final ApiBudget _budget;
  final bool Function() _isOnline;
  final Offload _offload;
  final void Function(String message) _log;

  /// Máximo de ids por lote.
  final int batchSize;

  /// Llamadas del presupuesto que no se gastan en el recorrido rotativo.
  final int reserve;

  Future<IntegrityReport>? _batchInFlight;
  final _pokemonInFlight = <int, Future<IntegrityReport>>{};
  final _checkedOnOpen = <int>{};

  /// Verifica los marcados y el siguiente lote rotativo. Dos solicitudes a la
  /// vez comparten la misma ejecución.
  Future<IntegrityReport> verify() {
    final running = _batchInFlight;
    if (running != null) return running;
    final future = _guard(_verifyBatch).whenComplete(() {
      _batchInFlight = null;
    });
    return _batchInFlight = future;
  }

  /// Compara [pokemonId] con el remoto (al abrir su detalle) y lo restaura si
  /// difiere. Una vez por Pokémon y sesión, salvo que su hash local ya no
  /// coincida. Dos solicitudes a la vez comparten la llamada.
  Future<IntegrityReport> verifyPokemon(int pokemonId) {
    final running = _pokemonInFlight[pokemonId];
    if (running != null) return running;
    final future = _guard(() => _verifyOne(pokemonId)).whenComplete(() {
      _pokemonInFlight.remove(pokemonId);
    });
    return _pokemonInFlight[pokemonId] = future;
  }

  Future<IntegrityReport> _guard(
    Future<IntegrityReport> Function() body,
  ) async {
    try {
      final report = await body();
      if (report.isSuccess) _logReport(report);
      return report;
    } catch (error) {
      _log('[Integridad] falló: $error');
      await _recordFailure(error);
      return IntegrityReport(error: error);
    }
  }

  Future<IntegrityReport> _verifyBatch() async {
    if (!_isOnline()) return IntegrityReport.nothing;
    final hashes = await _local.contentHashes();
    if (hashes.isEmpty) return IntegrityReport.nothing;

    final marked = [
      for (final entry in hashes.entries)
        if (entry.value.stored != entry.value.computed) entry.key,
    ].take(batchSize).toList();
    final cursor = (await _metadata.getEntry(resourceKey))?.cursorOffset ?? 0;
    final room = batchSize - marked.length;
    final rotating = room > 0 && await _hasRoom()
        ? _nextRotating(hashes.keys, marked.toSet(), cursor).take(room).toList()
        : const <int>[];
    final batch = [...marked, ...rotating];
    if (batch.isEmpty) return IntegrityReport.nothing;

    final restored = await _compareAndRestore(batch, hashes);
    await _recordSuccess(cursor: rotating.isEmpty ? cursor : rotating.last);
    return IntegrityReport(checked: batch.length, restored: restored);
  }

  Future<IntegrityReport> _verifyOne(int pokemonId) async {
    final hashes = await _local.contentHashes(ids: [pokemonId]);
    final local = hashes[pokemonId];
    if (local == null || !_isOnline()) return IntegrityReport.nothing;
    final tampered = local.stored != local.computed;
    if (!tampered && _checkedOnOpen.contains(pokemonId)) {
      return IntegrityReport.nothing;
    }
    final restored = await _compareAndRestore([pokemonId], hashes);
    _checkedOnOpen.add(pokemonId);
    return IntegrityReport(checked: 1, restored: restored);
  }

  /// Pide [ids] al remoto y restaura en una transacción los que difieren, ya
  /// sea del hash recalculado o del guardado. Devuelve los ids restaurados.
  Future<List<int>> _compareAndRestore(
    List<int> ids,
    Map<int, ({String? stored, String computed})> hashes,
  ) async {
    final data = await _remote.fetchByIds(ids);
    final records = await _mapPage(_offload, data, clock.now());
    final different = [
      for (final record in records)
        if (_differs(record, hashes[record.pokemon.id.value])) record,
    ];
    if (different.isNotEmpty) await _local.savePokemon(different);
    return [for (final record in different) record.pokemon.id.value];
  }

  bool _differs(
    PokemonRecord remote,
    ({String? stored, String computed})? local,
  ) {
    if (local == null) return true;
    final hash = remote.pokemon.contentHash.value;
    return hash != local.computed || hash != local.stored;
  }

  /// Ids que siguen a [cursor] en el recorrido, sin los ya marcados; da la
  /// vuelta al final del catálogo.
  List<int> _nextRotating(Iterable<int> allIds, Set<int> marked, int cursor) {
    final candidates = [
      for (final id in allIds)
        if (!marked.contains(id)) id,
    ]..sort();
    final after = candidates.where((id) => id > cursor).toList();
    return after.isEmpty ? candidates : after;
  }

  /// Hay cupo en el presupuesto más allá de la [reserve] para el usuario.
  Future<bool> _hasRoom() async =>
      await _budget.used() < _budget.limit - reserve;

  Future<void> _recordSuccess({required int cursor}) => _metadata.upsert(
    SyncMetadataEntriesCompanion.insert(
      resourceKey: resourceKey,
      status: SyncMetadataStatus.completed,
      lastAttemptAt: Value(clock.now()),
      lastSuccessAt: Value(clock.now()),
      attempts: const Value(0),
      cursorOffset: Value(cursor),
      lastError: const Value(null),
    ),
  );

  Future<void> _recordFailure(Object error) async {
    try {
      await _metadata.upsert(
        SyncMetadataEntriesCompanion.insert(
          resourceKey: resourceKey,
          status: SyncMetadataStatus.failed,
          lastAttemptAt: Value(clock.now()),
          lastError: Value(error.toString()),
        ),
      );
    } catch (_) {
      // No poder registrar el fallo no debe tapar el error original.
    }
  }

  void _logReport(IntegrityReport report) {
    final restored = report.restored.isEmpty
        ? 'sin diferencias'
        : 'restaurados ${report.restored.length} (ids ${report.restored.join(', ')})';
    _log('[Integridad] verificados ${report.checked} · $restored');
  }
}

// Función de nivel superior para que el closure que viaja al isolate solo
// capture los datos y no `this` (ver CatalogSync).
Future<List<PokemonRecord>> _mapPage(
  Offload offload,
  Map<String, dynamic> data,
  DateTime syncedAt,
) => offload(() => mapPokemonPage(data, syncedAt));

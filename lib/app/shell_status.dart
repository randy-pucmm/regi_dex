import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connectivity/service_status.dart';
import '../core/database/app_database.dart';
import '../core/error/failure.dart';
import '../core/images/image_prefetcher.dart';
import '../core/sync/sync_status.dart';
import '../features/pokemon/data/catalog_sync.dart';
import '../features/pokemon/data/image_sync.dart';
import '../ui/components/indicator_glyph.dart';
import '../ui/components/status_popover.dart';
import '../ui/tokens/led_state.dart';
import 'providers.dart';

/// Clave de `sync_metadata` del recurso cuya sync describe el indicador (PS-09).
/// Hoy es siempre el catálogo; cuando haya pantallas con datos propios
/// (Equipos con `champions`, Detalle con `detail:{id}`) seguirá a la ruta.
final visibleResourceProvider = Provider<String>(
  (ref) => CatalogSync.resourceKey,
);

/// Hora de la última sync correcta del recurso visible; null si no hubo. Una
/// sync más reciente de otro recurso no cuenta: si la referencia se actualiza
/// pero el catálogo falla, el indicador no debe decir que está al día. La
/// primera sync del catálogo no se da por completa hasta que se descargaron
/// las imágenes (ver `imageAutoSyncProvider`).
final lastSyncAtProvider = StreamProvider<DateTime?>((ref) {
  final dao = ref.watch(appDatabaseProvider).syncMetadataDao;
  final resourceKey = ref.watch(visibleResourceProvider);
  return dao
      .watchAll()
      .map((rows) => completedSyncAt(rows, resourceKey))
      .distinct();
});

/// Hora de la última sync correcta de [resourceKey] según [rows] (las filas de
/// `sync_metadata`); null si no hubo. Con el catálogo exige además que las
/// imágenes se hayan descargado alguna vez.
DateTime? completedSyncAt(List<SyncMetadataRow> rows, String resourceKey) {
  SyncMetadataRow? find(String key) {
    for (final row in rows) {
      if (row.resourceKey == key) return row;
    }
    return null;
  }

  if (resourceKey == CatalogSync.resourceKey &&
      find(ImageSync.resourceKey)?.lastSuccessAt == null) {
    return null;
  }
  return find(resourceKey)?.lastSuccessAt;
}

final shellStatusProvider = Provider<ShellStatus>((ref) {
  return buildShellStatus(
    connectivity:
        ref.watch(serviceStatusProvider).value ?? const ConnectivitySnapshot(),
    sync: ref.watch(syncStatusProvider).value ?? SyncStatus.inactiva,
    lastSyncAt: ref.watch(lastSyncAtProvider).value,
    now: clock.now(),
    images:
        ref.watch(imageProgressProvider).value ?? ImagePrefetchProgress.idle,
  );
});

/// Un indicador de la cabecera; sin [tone] va en el color neutro de la carcasa.
@immutable
class IndicatorSpec {
  const IndicatorSpec({
    required this.label,
    required this.glyph,
    required this.semantics,
    this.tone,
  });

  final String label;
  final IndicatorGlyph glyph;
  final LedState? tone;
  final String semantics;
}

/// Estado de la conexión listo para pintar.
@immutable
class ShellStatus {
  const ShellStatus({
    required this.led,
    required this.title,
    required this.subtitle,
    required this.updatedLabel,
    required this.indicators,
    required this.message,
    required this.rows,
    required this.canSyncNow,
  });

  final LedState led;

  /// Línea 1 de la banda: el estado.
  final String title;

  /// Línea 2 de la banda: origen y vigencia de los datos.
  final String subtitle;

  final String updatedLabel;
  final List<IndicatorSpec> indicators;
  final String message;
  final List<StatusRow> rows;

  /// Solo con servicio y sin una sync en curso.
  final bool canSyncNow;

  bool get isSyncing => led == LedState.sync;

  String get semanticsLabel => 'Estado de conexión: $title. $subtitle';
}

/// Antes de un estado estable (arranque) muestra «Verificando» con el aspecto
/// de sincronización. Después no parpadea (IND-06): eso ya lo evita el monitor.
ShellStatus buildShellStatus({
  required ConnectivitySnapshot connectivity,
  required SyncStatus sync,
  required DateTime? lastSyncAt,
  required DateTime now,
  ImagePrefetchProgress images = ImagePrefetchProgress.idle,
}) {
  final stable = connectivity.status;
  final verifying = stable == ServiceStatus.verificando;
  final syncing =
      stable == ServiceStatus.online && sync == SyncStatus.sincronizando;
  final hasNetwork = stable != ServiceStatus.offline;
  final at = lastSyncAt == null ? null : _hhmm(lastSyncAt);

  final led = switch (stable) {
    ServiceStatus.verificando => LedState.sync,
    ServiceStatus.online => syncing ? LedState.sync : LedState.online,
    ServiceStatus.offline => LedState.offline,
    ServiceStatus.servicioNoDisponible => LedState.down,
  };

  final (title, subtitle) = switch (led) {
    LedState.online => (
      'En línea',
      at == null
          ? 'Datos remotos · aún sin actualizar'
          : 'Datos remotos · actualizado $at',
    ),
    LedState.offline => (
      'Sin conexión',
      at == null
          ? 'Datos locales · sin sincronizar'
          : 'Datos locales · última sync $at',
    ),
    LedState.down => (
      'Servicio no disponible',
      'Red activa, API sin respuesta · datos locales',
    ),
    LedState.sync when verifying => (
      'Verificando',
      'Comprobando la conexión · datos locales',
    ),
    LedState.sync => ('Sincronizando', 'En línea · puedes seguir navegando'),
  };

  final message = switch (led) {
    LedState.online =>
      'PokéAPI responde y estás viendo datos remotos. Si no hay red, '
          'seguirás con los datos locales.',
    LedState.offline =>
      'Tu dispositivo no tiene conexión. Sigues viendo datos locales y la '
          'app se actualiza sola cuando vuelva la red.',
    LedState.down =>
      'Tu red funciona, pero PokéAPI no responde. Sigues viendo datos '
          'locales y la app reintenta sola, sin que hagas nada.',
    LedState.sync when verifying =>
      'Estamos comprobando la conexión con PokéAPI. Puedes seguir '
          'navegando con los datos locales.',
    LedState.sync =>
      'Estamos actualizando los datos. Puedes seguir navegando mientras '
          'termina.',
  };

  final local = at == null ? 'sin sincronizar' : 'última sync $at';
  final rows = [
    StatusRow('Red', _networkText(connectivity, hasNetwork)),
    StatusRow('PokéAPI', switch (led) {
      LedState.online => 'Disponible',
      LedState.offline => 'Sin conexión',
      LedState.down => _failureText(connectivity.lastFailure),
      LedState.sync when verifying => 'Verificando',
      LedState.sync => 'Disponible',
    }),
    StatusRow('Datos', switch (led) {
      LedState.online =>
        at == null
            ? 'Remotos · aún sin actualizar'
            : 'Remotos · actualizado $at',
      LedState.sync => 'Actualizando…',
      LedState.offline || LedState.down => 'Locales · $local',
    }),
    if (images.isRunning)
      StatusRow('Imágenes', '${images.done} de ${images.total}'),
    if (connectivity.nextRetryAt case final retry?)
      StatusRow('Reintento', _inText(retry.difference(now))),
  ];

  final indicators = [
    IndicatorSpec(
      label: 'RED',
      glyph: hasNetwork ? IndicatorGlyph.solid : IndicatorGlyph.hollow,
      tone: hasNetwork ? LedState.online : LedState.offline,
      semantics: hasNetwork ? 'Red: conectada' : 'Red: sin conexión',
    ),
    switch (led) {
      LedState.online => const IndicatorSpec(
        label: 'API',
        glyph: IndicatorGlyph.solid,
        tone: LedState.online,
        semantics: 'API: disponible',
      ),
      LedState.offline => const IndicatorSpec(
        label: 'API',
        glyph: IndicatorGlyph.hollow,
        tone: LedState.offline,
        semantics: 'API: sin conexión',
      ),
      LedState.down => const IndicatorSpec(
        label: 'API',
        glyph: IndicatorGlyph.target,
        tone: LedState.down,
        semantics: 'API: sin respuesta',
      ),
      LedState.sync => IndicatorSpec(
        label: 'API',
        glyph: IndicatorGlyph.syncing,
        tone: LedState.sync,
        semantics: verifying ? 'API: verificando' : 'API: sincronizando',
      ),
    },
    switch (led) {
      LedState.online => const IndicatorSpec(
        label: 'DATOS',
        glyph: IndicatorGlyph.solid,
        tone: LedState.online,
        semantics: 'Datos: remotos',
      ),
      LedState.sync => const IndicatorSpec(
        label: 'DATOS',
        glyph: IndicatorGlyph.syncing,
        tone: LedState.sync,
        semantics: 'Datos: sincronizando',
      ),
      LedState.offline || LedState.down => const IndicatorSpec(
        label: 'DATOS',
        glyph: IndicatorGlyph.solid,
        semantics: 'Datos: locales',
      ),
    },
  ];

  return ShellStatus(
    led: led,
    title: title,
    subtitle: subtitle,
    updatedLabel: 'ACT. ${at ?? '--:--'}',
    indicators: indicators,
    message: message,
    rows: rows,
    canSyncNow: led == LedState.online || led == LedState.down,
  );
}

String _hhmm(DateTime time) {
  final local = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}

String _networkText(ConnectivitySnapshot connectivity, bool hasNetwork) {
  if (!hasNetwork) return 'Sin conexión';
  final kind = switch (connectivity.networkKind) {
    NetworkKind.wifi => 'Wi-Fi',
    NetworkKind.mobile => 'datos móviles',
    NetworkKind.ethernet => 'Ethernet',
    NetworkKind.other => 'otra red',
    NetworkKind.none => null,
  };
  return kind == null ? 'Activa' : 'Activa ($kind)';
}

String _failureText(Failure? failure) => switch (failure) {
  null => 'Sin respuesta',
  TimeoutFailure() => 'Sin respuesta (timeout)',
  NetworkFailure() => 'No se pudo conectar',
  ServiceUnavailableFailure(:final statusCode) =>
    statusCode == null
        ? 'Servicio no disponible'
        : 'Error del servidor (HTTP $statusCode)',
  RateLimitFailure() => 'Límite de llamadas superado',
  BudgetExhaustedFailure() => 'Cupo de llamadas agotado',
  GraphQLFailure() ||
  PartialDataFailure() ||
  ValidationFailure() => 'Respuesta no válida',
};

String _inText(Duration wait) {
  final seconds = wait.inSeconds < 0 ? 0 : wait.inSeconds;
  if (seconds < 60) return 'en $seconds s';
  return 'en ${(seconds / 60).ceil()} min';
}

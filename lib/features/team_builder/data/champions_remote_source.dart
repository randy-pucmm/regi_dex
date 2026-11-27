import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/champions_config.dart';
import '../../../core/network/failure_mapper.dart';

/// Llamadas REST a Pokémon Champions Battle Data (ADR-008).
///
/// A diferencia de PokéAPI, el servicio no publica un límite de llamadas, así
/// que no pasa por `ApiBudget`: la caché de 24 h es el control. Tampoco alimenta
/// al `ConnectivityMonitor`, que mide solo PokéAPI. Los errores salen como
/// [Failure].
class ChampionsRemoteSource {
  /// [endpoint] es la raíz del servicio y [client] el cliente HTTP (pruebas).
  /// [log] recibe una línea por llamada (por defecto, la consola).
  ChampionsRemoteSource({
    required this._endpoint,
    required this._client,
    void Function(String message)? log,
  }) : _log = log ?? debugPrint;

  static const _service = 'Champions Battle Data';

  final Uri _endpoint;
  final http.Client _client;
  final void Function(String message) _log;

  /// Raíz del servicio, para completar las rutas relativas de las imágenes.
  String get baseUrl => _endpoint.toString();

  /// Descarga el índice (`GET /api`) y devuelve el JSON sin interpretar. Lanza
  /// [Failure] si la red, el tiempo o el estado HTTP lo impiden.
  Future<Uint8List> fetchIndex() => _get('api', championsIndexTimeout);

  Future<Uint8List> _get(String path, Duration timeout) async {
    final uri = _endpoint.resolve(path);
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) {
        throw failureFromRestStatus(
          response.statusCode,
          response.headers,
          _service,
        );
      }
      _log(
        '[Champions] GET /$path ok (${response.bodyBytes.length} B, '
        '${stopwatch.elapsedMilliseconds} ms)',
      );
      return response.bodyBytes;
    } catch (error) {
      final failure = failureFromError(error);
      _log('[Champions] GET /$path falló: $failure');
      throw failure;
    }
  }
}

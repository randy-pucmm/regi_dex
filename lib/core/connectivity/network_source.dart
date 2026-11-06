import 'package:connectivity_plus/connectivity_plus.dart';

import 'service_status.dart';

/// Interfaz de red activa. Es solo una pista: que haya Wi-Fi no significa que
/// PokéAPI responda (IND-02).
class NetworkState {
  const NetworkState(this.kind);

  final NetworkKind kind;

  bool get hasInterface => kind != NetworkKind.none;

  @override
  bool operator ==(Object other) => other is NetworkState && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;

  @override
  String toString() => 'NetworkState($kind)';
}

/// Origen de los eventos de red del dispositivo.
abstract interface class NetworkSource {
  /// Interfaz activa en este momento.
  Future<NetworkState> current();

  /// Cambios de interfaz, sin repetir el mismo estado.
  Stream<NetworkState> get changes;
}

/// Traduce la lista de `connectivity_plus` a un [NetworkState]. Gana la
/// primera interfaz de datos (Wi-Fi, ethernet, móvil); una VPN o Bluetooth sin
/// ellas cuenta como `other`; una lista vacía o solo `none`, como sin red.
NetworkState networkStateFromResults(List<ConnectivityResult> results) {
  const priority = [
    (ConnectivityResult.wifi, NetworkKind.wifi),
    (ConnectivityResult.ethernet, NetworkKind.ethernet),
    (ConnectivityResult.mobile, NetworkKind.mobile),
  ];
  for (final (result, kind) in priority) {
    if (results.contains(result)) return NetworkState(kind);
  }
  final hasOther = results.any((result) => result != ConnectivityResult.none);
  return NetworkState(hasOther ? NetworkKind.other : NetworkKind.none);
}

/// [NetworkSource] sobre `connectivity_plus`.
class ConnectivityPlusNetworkSource implements NetworkSource {
  ConnectivityPlusNetworkSource([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<NetworkState> current() async =>
      networkStateFromResults(await _connectivity.checkConnectivity());

  @override
  Stream<NetworkState> get changes => _connectivity.onConnectivityChanged
      .map(networkStateFromResults)
      .distinct();
}

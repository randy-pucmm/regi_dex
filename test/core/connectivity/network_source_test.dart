import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/connectivity/network_source.dart';
import 'package:regi_dex/core/connectivity/service_status.dart';

void main() {
  group('networkStateFromResults', () {
    NetworkKind kindOf(List<ConnectivityResult> results) =>
        networkStateFromResults(results).kind;

    test('una interfaz de datos', () {
      expect(kindOf([ConnectivityResult.wifi]), NetworkKind.wifi);
      expect(kindOf([ConnectivityResult.mobile]), NetworkKind.mobile);
      expect(kindOf([ConnectivityResult.ethernet]), NetworkKind.ethernet);
    });

    test('gana Wi-Fi sobre ethernet y datos móviles', () {
      expect(
        kindOf([ConnectivityResult.mobile, ConnectivityResult.wifi]),
        NetworkKind.wifi,
      );
      expect(
        kindOf([ConnectivityResult.ethernet, ConnectivityResult.mobile]),
        NetworkKind.ethernet,
      );
    });

    test('una VPN se describe por la interfaz que la lleva', () {
      expect(
        kindOf([ConnectivityResult.mobile, ConnectivityResult.vpn]),
        NetworkKind.mobile,
      );
    });

    test('VPN o Bluetooth solos cuentan como otra interfaz', () {
      expect(kindOf([ConnectivityResult.vpn]), NetworkKind.other);
      expect(kindOf([ConnectivityResult.bluetooth]), NetworkKind.other);
    });

    test('sin resultados o solo none no hay red', () {
      expect(kindOf([]), NetworkKind.none);
      expect(kindOf([ConnectivityResult.none]), NetworkKind.none);
      expect(
        networkStateFromResults([ConnectivityResult.none]).hasInterface,
        isFalse,
      );
    });
  });

  test('NetworkState compara por tipo de interfaz', () {
    expect(
      const NetworkState(NetworkKind.wifi),
      const NetworkState(NetworkKind.wifi),
    );
    expect(
      const NetworkState(NetworkKind.wifi),
      isNot(const NetworkState(NetworkKind.mobile)),
    );
  });
}

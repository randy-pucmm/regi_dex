import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/core/connectivity/service_status.dart';
import 'package:regi_dex/core/error/failure.dart';

import '../core/connectivity/connectivity_fakes.dart';

void main() {
  ProviderContainer containerWith(
    FakeNetworkSource network,
    FakeHealthChecker checker,
  ) {
    final container = ProviderContainer(
      overrides: [
        networkSourceProvider.overrideWithValue(network),
        healthCheckerProvider.overrideWithValue(checker),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<ConnectivitySnapshot> snapshotOf(ProviderContainer container) async {
    container.listen(serviceStatusProvider, (_, _) {});
    await pumpEventQueue();
    return container.read(serviceStatusProvider).requireValue;
  }

  test('con red y API sana el indicador queda online', () async {
    final checker = FakeHealthChecker();
    final container = containerWith(FakeNetworkSource(), checker);

    final snapshot = await snapshotOf(container);

    expect(snapshot.status, ServiceStatus.online);
    expect(snapshot.networkKind, NetworkKind.wifi);
    expect(checker.calls, 1);
  });

  test('sin red queda offline sin llamar a la API', () async {
    final checker = FakeHealthChecker();
    final container = containerWith(
      FakeNetworkSource(NetworkKind.none),
      checker,
    );

    final snapshot = await snapshotOf(container);

    expect(snapshot.status, ServiceStatus.offline);
    expect(checker.calls, 0);
  });

  test('con red y la API caída queda en servicioNoDisponible', () async {
    final checker = FakeHealthChecker()
      ..failure = const ServiceUnavailableFailure('caída', statusCode: 404);
    final container = containerWith(FakeNetworkSource(), checker);

    final snapshot = await snapshotOf(container);

    expect(snapshot.status, ServiceStatus.servicioNoDisponible);
    expect(snapshot.lastFailure, isA<ServiceUnavailableFailure>());
  });
}

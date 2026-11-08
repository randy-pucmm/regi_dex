import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/ui/components/pokemon_image.dart';

import '../../helpers/ui_test_helpers.dart';

const _caption = 'Imagen no disponible offline';

/// Gestor de caché cuyo resultado controla la prueba.
class _FakeCacheManager extends Fake implements BaseCacheManager {
  _FakeCacheManager(this._response);

  final Stream<FileResponse> Function() _response;

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => _response();
}

/// Sin red y sin la imagen guardada.
_FakeCacheManager _offline() =>
    _FakeCacheManager(() => Stream.error(const SocketExceptionStub()));

/// Descargando: no llega nada.
_FakeCacheManager _loading() =>
    _FakeCacheManager(() => StreamController<FileResponse>().stream);

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}

Widget _image({
  String? url = 'https://example.test/regirock.png',
  double size = 56,
  BaseCacheManager? manager,
  String? label,
}) => regiHost(
  PokemonImage(
    url: url,
    size: size,
    cacheManager: manager ?? _offline(),
    label: label,
  ),
);

void main() {
  testWidgets('sin la imagen y sin red muestra el respaldo', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_image());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.bySemanticsLabel(_caption), findsOneWidget);
    handle.dispose();
  });

  testWidgets('mientras descarga no muestra el respaldo', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_image(manager: _loading()));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.bySemanticsLabel(_caption), findsNothing);
    handle.dispose();
  });

  testWidgets('sin URL muestra el respaldo sin intentar descargar', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_image(url: null));

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.bySemanticsLabel(_caption), findsOneWidget);
    handle.dispose();
  });

  testWidgets('el texto del respaldo solo se escribe si hay sitio', (
    tester,
  ) async {
    await tester.pumpWidget(_image(url: null, size: 56));
    expect(find.text(_caption), findsNothing);

    await tester.pumpWidget(
      _image(url: null, size: PokemonImage.captionMinSize),
    );
    expect(find.text(_caption), findsOneWidget);
  });

  testWidgets('usa la caché indicada y decodifica al tamaño del contenedor', (
    tester,
  ) async {
    final manager = _loading();
    await tester.pumpWidget(_image(size: 56, manager: manager));

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    final pixels = (56 * tester.view.devicePixelRatio).round();
    expect(image.cacheManager, same(manager));
    expect(image.memCacheWidth, pixels);
    expect(image.memCacheHeight, pixels);
  });

  testWidgets('se anuncia como imagen con el nombre del Pokémon', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_image(label: 'Regirock', manager: _loading()));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Regirock')),
      isSemantics(label: 'Regirock', isImage: true),
    );
    handle.dispose();
  });
}

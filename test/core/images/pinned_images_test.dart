import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/images/pinned_images.dart';

void main() {
  late Directory dir;
  late File source;
  late PinnedImages pinned;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('regi_pinned_test');
    addTearDown(() => dir.delete(recursive: true));
    source = await File('${dir.path}/origen').writeAsString('png');
    pinned = PinnedImages(() async => Directory('${dir.path}/pinned'));
  });

  Future<File> fetch(String url) async => source;

  test('fija las pedidas y borra las que ya no lo están', () async {
    await pinned.keep({'a', 'b'}, fetch);
    await pinned.keep({'b'}, fetch);

    expect(await pinned.find('a'), isNull);
    expect(await (await pinned.find('b'))!.readAsString(), 'png');
  });

  test('la que no se pudo bajar se intenta otra vez', () async {
    await pinned.keep({'a'}, (_) => throw const SocketException('sin red'));
    expect(await pinned.find('a'), isNull);

    await pinned.keep({'a'}, fetch);

    expect(await pinned.find('a'), isNotNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/images/image_cache_policy.dart';

CachedImageEntry _entry(String key, int bytes, int minute) => CachedImageEntry(
  key: key,
  bytes: bytes,
  touched: DateTime(2026, 11, 6, 10, minute),
);

void main() {
  test('los límites son los del ADR-004: 150 MB y 1500 archivos', () {
    expect(ImageCacheLimits.maxBytes, 150 * 1024 * 1024);
    expect(ImageCacheLimits.maxFiles, 1500);
  });

  test('si todo cabe no expulsa nada', () {
    final entries = [_entry('a', 100, 1), _entry('b', 100, 2)];

    expect(keysToEvict(entries, maxBytes: 200), isEmpty);
    expect(keysToEvict(const [], maxBytes: 0), isEmpty);
  });

  test('expulsa las menos recientes, sea cual sea el orden de entrada', () {
    final entries = [
      _entry('reciente', 100, 30),
      _entry('antigua', 100, 1),
      _entry('media', 100, 15),
    ];

    expect(keysToEvict(entries, maxBytes: 250), ['antigua']);
    expect(keysToEvict(entries, maxBytes: 150), ['antigua', 'media']);
    expect(keysToEvict(entries, maxBytes: 0), ['antigua', 'media', 'reciente']);
  });

  test('para en cuanto lo que queda cabe, aunque una entrada sea enorme', () {
    final entries = [_entry('vieja', 10, 1), _entry('grande', 500, 2)];

    expect(keysToEvict(entries, maxBytes: 300), ['vieja', 'grande']);
  });
}

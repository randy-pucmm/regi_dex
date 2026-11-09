/// Límites de la caché de imágenes (ADR-004).
abstract final class ImageCacheLimits {
  static const maxBytes = 150 * 1024 * 1024;
  static const maxFiles = 1500;
}

/// Un archivo de la caché, lo mínimo que necesita la política de expulsión.
class CachedImageEntry {
  const CachedImageEntry({
    required this.key,
    required this.bytes,
    required this.touched,
  });

  final String key;
  final int bytes;

  /// Último uso.
  final DateTime touched;
}

/// Claves a expulsar, de la menos reciente a la más reciente, hasta que lo que
/// queda cabe en [maxBytes]. Si ya cabe, no expulsa nada.
List<String> keysToEvict(
  Iterable<CachedImageEntry> entries, {
  required int maxBytes,
}) {
  var total = entries.fold<int>(0, (sum, e) => sum + e.bytes);
  final oldestFirst = entries.toList()
    ..sort((a, b) => a.touched.compareTo(b.touched));

  final evicted = <String>[];
  for (final entry in oldestFirst) {
    if (total <= maxBytes) break;
    evicted.add(entry.key);
    total -= entry.bytes;
  }
  return evicted;
}

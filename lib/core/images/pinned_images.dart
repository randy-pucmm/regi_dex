import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Copias de imágenes que la caché LRU no puede expulsar (ADR-004).
class PinnedImages {
  PinnedImages(this._directory);

  final Future<Directory> Function() _directory;
  Future<void> _last = Future.value();

  Future<File?> find(String url) async {
    final file = _file(await _directory(), url);
    return await file.exists() ? file : null;
  }

  /// Deja fijadas exactamente [urls]. La que [fetch] no consiga se intenta en la
  /// siguiente llamada. Las llamadas se ejecutan en orden.
  Future<void> keep(Set<String> urls, Future<File> Function(String) fetch) =>
      _last = _last.catchError((_) {}).then((_) => _keep(urls, fetch));

  Future<void> _keep(
    Set<String> urls,
    Future<File> Function(String) fetch,
  ) async {
    final directory = await (await _directory()).create(recursive: true);
    final wanted = {for (final url in urls) _file(directory, url).path: url};
    await for (final entry in directory.list()) {
      if (wanted.remove(entry.path) == null) await entry.delete();
    }
    for (final MapEntry(key: path, value: url) in wanted.entries) {
      try {
        await (await fetch(url)).copy(path);
      } catch (_) {
        // Sin red y sin caché: queda pendiente.
      }
    }
  }

  File _file(Directory directory, String url) => File(
    '${directory.path}${Platform.pathSeparator}${sha1.convert(utf8.encode(url))}',
  );
}

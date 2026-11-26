import '../../../core/database/app_database.dart';
import '../../../core/database/daos/catalog_dao.dart';
import '../../../core/images/image_prefetcher.dart';
import '../../../core/sync/sync_coordinator.dart';

/// La descarga de imágenes no terminó: [failed] de [total] quedaron pendientes.
class ImageSyncIncomplete implements Exception {
  const ImageSyncIncomplete({required this.failed, required this.total});

  final int failed;
  final int total;

  @override
  String toString() =>
      'ImageSyncIncomplete: faltaron $failed de $total imágenes';
}

/// Descarga en segundo plano los sprites del catálogo (ADR-004).
///
/// Uso: `await imageSync.run()`. El coordinador aporta el single-flight y el
/// registro en `sync_metadata` bajo la clave [resourceKey]; si faltan imágenes
/// al terminar, falla para que se reintente con backoff.
class ImageSync {
  ImageSync({
    required this._catalog,
    required this._prefetcher,
    required this._coordinator,
  });

  /// Clave de `sync_metadata` de las imágenes.
  static const resourceKey = 'images';

  final CatalogDao _catalog;
  final ImagePrefetcher _prefetcher;
  final SyncCoordinator _coordinator;

  /// Descarga los sprites que falten. Lanza [ImageSyncIncomplete] si alguno no
  /// se pudo bajar por la red.
  Future<void> run() => _coordinator.run<void>(resourceKey, _execute);

  Future<void> _execute() async {
    final urls = await _catalog.spriteUrls();
    final result = await _prefetcher.prefetch(urls);
    if (!result.isComplete) {
      throw ImageSyncIncomplete(failed: result.failed, total: urls.length);
    }
  }
}

/// Indica si las imágenes hay que descargarlas: nunca se completó una pasada o
/// el catálogo se sincronizó después de la última. [images] y [catalog] son las
/// filas de `sync_metadata`, o null si no existen.
bool imagesNeedSync(SyncMetadataRow? images, SyncMetadataRow? catalog) {
  final catalogDone = catalog?.lastSuccessAt;
  if (catalogDone == null ||
      catalog!.status != SyncMetadataStatus.completed ||
      catalog.cursorOffset > 0) {
    return false;
  }
  final imagesDone = images?.lastSuccessAt;
  return imagesDone == null || imagesDone.isBefore(catalogDone);
}

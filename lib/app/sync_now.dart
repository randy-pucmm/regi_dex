import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Acción de «Sincronizar ahora» (IND-08): vuelve a comprobar PokéAPI y luego
/// sincroniza el catálogo. Si la sincronización falla no se propaga: ya queda
/// en `sync_metadata` y el LED lo refleja; el reintento con backoff es de
/// RD-28. Una pasada en curso se reutiliza (single-flight), no se duplica.
final syncNowProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    if (!ref.mounted) return;
    await ref.read(connectivityMonitorProvider).checkNow();
    if (!ref.mounted) return;
    try {
      await ref.read(refreshCatalogProvider)();
    } catch (_) {
      // Ver arriba: el fallo ya está registrado.
    }
  };
});

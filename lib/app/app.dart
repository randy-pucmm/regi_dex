import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/presentation/appearance_controller.dart';
import '../ui/themes/regi_themes.dart';
import 'catalog_auto_sync.dart';
import 'providers.dart';
import 'router.dart';

/// Raíz de la app. Mantiene vivos el monitor de conectividad y la sincronización
/// automática del catálogo mientras esté abierta.
class RegiDexApp extends ConsumerWidget {
  const RegiDexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(connectivityMonitorProvider);
    ref.watch(catalogAutoSyncProvider);
    final appearance = ref.watch(appearanceProvider);
    return MaterialApp.router(
      title: 'RegiDex',
      theme: RegiThemes.build(appearance.variant, Brightness.light),
      darkTheme: RegiThemes.build(appearance.variant, Brightness.dark),
      themeMode: appearance.mode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

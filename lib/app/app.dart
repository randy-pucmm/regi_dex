import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'router.dart';

/// Raíz de la aplicación: `MaterialApp.router` con el router del provider.
/// Mantiene vivo el monitor de conectividad mientras la app esté abierta.
/// El tema es provisional hasta que llegue el sistema de diseño Regi (lib/ui).
class RegiDexApp extends ConsumerWidget {
  const RegiDexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(connectivityMonitorProvider);
    return MaterialApp.router(
      title: 'RegiDex',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF8B5A2B),
        useMaterial3: true,
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

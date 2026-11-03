import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';

/// Carcasa común de las pantallas. Muestra el botón «Inicio» fuera de Inicio.
/// Es provisional: la sustituye PokedexShell del kit lib/ui.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final atHome = GoRouterState.of(context).uri.path == AppRoutes.home;
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: atHome
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton.icon(
                  onPressed: () => context.go(AppRoutes.home),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Inicio'),
                ),
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';

/// Pantalla de Inicio: acceso a Catálogo, Favoritos, Equipos, Trivia y Ajustes.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const destinations = [
      ('Catálogo', AppRoutes.catalog),
      ('Favoritos', AppRoutes.favorites),
      ('Equipos', AppRoutes.teamBuilder),
      ('Trivia', AppRoutes.trivia),
      ('Ajustes', AppRoutes.settings),
    ];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          for (final (label, route) in destinations)
            FilledButton.tonal(
              onPressed: () => context.go(route),
              child: Text(label),
            ),
        ],
      ),
    );
  }
}

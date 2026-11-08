import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/favorites/presentation/favorites_page.dart';
import '../features/pokemon/presentation/catalog_page.dart';
import '../features/team_builder/presentation/team_builder_page.dart';
import '../features/trivia/presentation/trivia_page.dart';
import 'app_shell.dart';
import 'home_page.dart';
import 'routes.dart';

/// Router raíz: un shell común y Inicio como pantalla de entrada.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: AppRoutes.catalog,
            builder: (context, state) => const CatalogPage(),
          ),
          GoRoute(
            path: AppRoutes.favorites,
            builder: (context, state) => const FavoritesPage(),
          ),
          GoRoute(
            path: AppRoutes.teamBuilder,
            builder: (context, state) => const TeamBuilderPage(),
          ),
          GoRoute(
            path: AppRoutes.trivia,
            builder: (context, state) => const TriviaPage(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

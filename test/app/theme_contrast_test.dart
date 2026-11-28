// Contraste AA (4.5:1, o 3:1 en texto grande) de las pantallas reales en los
// doce temas (RF-TEM-04, PA-19).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/app.dart';
import 'package:regi_dex/app/favorite_pins.dart';
import 'package:regi_dex/app/image_providers.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/app/router.dart';
import 'package:regi_dex/core/sync/sync_status.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon.dart';
import 'package:regi_dex/features/settings/presentation/appearance_controller.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

import '../core/connectivity/connectivity_fakes.dart';
import '../core/database/database_test_helpers.dart';
import '../features/pokemon/fake_pokemon_repository.dart';
import '../helpers/fake_image_cache.dart';
import '../helpers/ui_test_helpers.dart';

class _Catalog extends FakePokemonRepository {
  @override
  Stream<List<Pokemon>> watchPokemon(query) => Stream.value(const [
    Pokemon(
      id: 1,
      name: 'bulbasaur',
      baseStatTotal: 318,
      types: [PokemonTypeRef(id: 12, name: 'grass', nameEs: 'Planta')],
    ),
  ]);
}

void main() {
  for (final variant in RegiVariant.values) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${variant.displayName} ${mode.name} cumple AA', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        useScreen(tester, const Size(390, 1600));
        reduceMotion(tester);
        final db = createTestDatabase();
        addTearDown(db.close);
        await seedReference(db);
        await upsertBulbasaur(db);
        await db.preferenceDao.setValue(themePreferenceKey, variant.name);
        await db.preferenceDao.setValue(themeModePreferenceKey, mode.name);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              networkSourceProvider.overrideWithValue(FakeNetworkSource()),
              healthCheckerProvider.overrideWithValue(FakeHealthChecker()),
              pokemonRepositoryProvider.overrideWithValue(_Catalog()),
              pokemonDetailRefreshProvider(1).overrideWith((ref) => true),
              imageCacheManagerProvider.overrideWithValue(FakeImageCache()),
              favoritePinsProvider.overrideWithValue(null),
              favoriteIdsProvider.overrideWith((ref) => Stream.value({1})),
              syncStatusProvider.overrideWith(
                (ref) => Stream.value(SyncStatus.inactiva),
              ),
            ],
            child: const RegiDexApp(),
          ),
        );
        await tester.pumpAndSettle();
        final router = ProviderScope.containerOf(
          tester.element(find.byType(RegiDexApp)),
        ).read(routerProvider);

        for (final route in ['/', '/catalog', '/favorites', '/pokemon/1']) {
          router.go(route);
          await tester.pumpAndSettle();
          await expectLater(
            tester,
            meetsGuideline(textContrastGuideline),
            reason: route,
          );
        }
        router.go('/');
        await tester.pumpAndSettle();
        await tester.tap(find.text('AJUSTES'));
        await tester.pumpAndSettle();
        await expectLater(
          tester,
          meetsGuideline(textContrastGuideline),
          reason: 'Ajustes',
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        semantics.dispose();
      });
    }
  }
}

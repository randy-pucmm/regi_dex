import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/image_providers.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/features/favorites/presentation/favorites_page.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon.dart';

import '../../core/database/database_test_helpers.dart';
import '../../helpers/fake_image_cache.dart';
import '../../helpers/ui_test_helpers.dart';
import '../pokemon/fake_pokemon_repository.dart';

class _Catalog extends FakePokemonRepository {
  @override
  Stream<List<Pokemon>> watchPokemon(query) => Stream.value(const [
    Pokemon(id: 1, name: 'bulbasaur', baseStatTotal: 318, types: []),
    Pokemon(id: 4, name: 'charmander', baseStatTotal: 309, types: []),
  ]);
}

void main() {
  testWidgets('lista los favoritos y quitar el último avisa que no hay', (
    tester,
  ) async {
    final db = createTestDatabase();
    addTearDown(db.close);
    await db.favoriteDao.addFavorite(4);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          pokemonRepositoryProvider.overrideWithValue(_Catalog()),
          imageCacheManagerProvider.overrideWithValue(FakeImageCache()),
        ],
        child: regiHost(const FavoritesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Charmander'), findsOneWidget);
    expect(find.text('Bulbasaur'), findsNothing);

    await tester.tap(find.byTooltip('Quitar de favoritos'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no tienes favoritos'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

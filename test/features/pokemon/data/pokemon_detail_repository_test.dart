import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_detail_repository_impl.dart';

import '../../../core/database/database_test_helpers.dart';

void main() {
  late AppDatabase db;
  late PokemonDetailRepositoryImpl repository;

  setUp(() {
    db = createTestDatabase();
    repository = PokemonDetailRepositoryImpl(catalog: db.catalogDao);
    addTearDown(db.close);
  });

  test('entrega tipos, stats y habilidades del Pokémon guardado', () async {
    await seedReference(db);
    await upsertBulbasaur(db);

    final detail = (await repository.watchDetail(1).first)!;

    expect(detail.pokemon.name, 'Bulbasaur');
    expect([for (final t in detail.pokemon.types) t.name], ['grass', 'poison']);
    expect(detail.stats, {1: 45, 2: 49, 3: 49});
    expect(
      [for (final a in detail.abilities) a.name],
      ['overgrow', 'chlorophyll'],
    );
    expect([for (final a in detail.abilities) a.isHidden], [false, true]);
  });

  test('un id fuera del catálogo emite null', () async {
    expect(await repository.watchDetail(999).first, isNull);
  });
}

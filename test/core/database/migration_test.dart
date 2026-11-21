import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/database/app_database.dart';

import '../../generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test(
    'de v1 a v2 el esquema queda igual al actual y conserva los datos',
    () async {
      final schema = await verifier.schemaAt(1);
      schema.rawDatabase
        ..execute(
          "INSERT INTO generation (id, name) VALUES (1, 'generation-i')",
        )
        ..execute(
          "INSERT INTO species (id, name, generation_id) VALUES (1, 'bulbasaur', 1)",
        )
        ..execute(
          'INSERT INTO pokemon (id, species_id, name, base_stat_total, light_synced_at) '
          "VALUES (1, 1, 'bulbasaur', 318, 1762164000)",
        );

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 2);

      final row = await db.catalogDao.getPokemon(1);
      expect(row?.name, 'bulbasaur');
      expect(row?.baseStatTotal, 318);
      expect(row?.spriteShinyUrl, isNull);
      expect(row?.artworkShinyUrl, isNull);
      expect(row?.detailSyncedAt, isNull);
      await db.close();
    },
  );
}

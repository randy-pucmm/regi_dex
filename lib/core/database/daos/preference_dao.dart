import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/user_tables.dart';

part 'preference_dao.g.dart';

/// Acceso a las preferencias del usuario (pares clave/valor).
@DriftAccessor(tables: [UserPreferences])
class PreferenceDao extends DatabaseAccessor<AppDatabase>
    with _$PreferenceDaoMixin {
  PreferenceDao(super.attachedDatabase);

  /// Valor guardado para [key], o null si no existe.
  Future<String?> getValue(String key) async => (await (select(
    userPreferences,
  )..where((p) => p.key.equals(key))).getSingleOrNull())?.value;

  /// Valor de [key] como flujo; null mientras no exista.
  Stream<String?> watchValue(String key) =>
      (select(userPreferences)..where((p) => p.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  /// Guarda [value] en [key], reemplazando el anterior.
  Future<void> setValue(String key, String value) => into(userPreferences)
      .insertOnConflictUpdate(
        UserPreferencesCompanion.insert(key: key, value: value),
      );

  /// Elimina la preferencia [key].
  Future<void> remove(String key) =>
      (delete(userPreferences)..where((p) => p.key.equals(key))).go();
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';

/// Base de datos local, única para toda la app. Las pruebas la sobrescriben
/// con una base en memoria.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.open();
  ref.onDispose(database.close);
  return database;
});

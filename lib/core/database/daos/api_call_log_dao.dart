import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sync_tables.dart';

part 'api_call_log_dao.g.dart';

/// Acceso al registro de llamadas a PokéAPI (base del presupuesto por ventana).
@DriftAccessor(tables: [ApiCallLogs])
class ApiCallLogDao extends DatabaseAccessor<AppDatabase>
    with _$ApiCallLogDaoMixin {
  ApiCallLogDao(super.attachedDatabase);

  /// Registra una llamada de [operation] y devuelve su id.
  /// [calledAt] es el instante de la llamada (por defecto, ahora).
  Future<int> record(String operation, {DateTime? calledAt, int? httpStatus}) {
    return into(apiCallLogs).insert(
      ApiCallLogsCompanion.insert(
        operation: operation,
        calledAt: calledAt ?? DateTime.now(),
        httpStatus: Value(httpStatus),
      ),
    );
  }

  /// Guarda el estado HTTP de la llamada [id] cuando termina.
  Future<void> setHttpStatus(int id, int? httpStatus) =>
      (update(apiCallLogs)..where((l) => l.id.equals(id))).write(
        ApiCallLogsCompanion(httpStatus: Value(httpStatus)),
      );

  /// Cantidad de llamadas hechas desde [since] (inclusive).
  Future<int> countSince(DateTime since) {
    final count = apiCallLogs.id.count();
    return (selectOnly(apiCallLogs)
          ..addColumns([count])
          ..where(apiCallLogs.calledAt.isBiggerOrEqualValue(since)))
        .map((row) => row.read(count)!)
        .getSingle();
  }

  /// Instante de la llamada más antigua desde [since], o null si no hay ninguna.
  Future<DateTime?> oldestSince(DateTime since) {
    final oldest = apiCallLogs.calledAt.min();
    return (selectOnly(apiCallLogs)
          ..addColumns([oldest])
          ..where(apiCallLogs.calledAt.isBiggerOrEqualValue(since)))
        .map((row) => row.read(oldest))
        .getSingle();
  }

  /// Borra las llamadas anteriores a [cutoff] y devuelve cuántas eran.
  Future<int> purgeBefore(DateTime cutoff) => (delete(
    apiCallLogs,
  )..where((l) => l.calledAt.isSmallerThanValue(cutoff))).go();
}

import 'package:drift/drift.dart';

// Metadatos de sincronización (D11).

/// Estado de sync por recurso: `reference`, `catalog`, `detail:{id}` o `champions`.
/// `cursorOffset` guarda el avance confirmado de la carga por lotes (PS-07).
@DataClassName('SyncMetadataRow')
class SyncMetadataEntries extends Table {
  @override
  String get tableName => 'sync_metadata';

  TextColumn get resourceKey => text()();
  TextColumn get status => text()();
  DateTimeColumn get lastSuccessAt => dateTime().nullable()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  IntColumn get cursorOffset => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {resourceKey};
}

/// Registro de llamadas a PokéAPI para el presupuesto de la ventana móvil (ADR-005).
@DataClassName('ApiCallLogRow')
@TableIndex(name: 'idx_api_call_log_called_at', columns: {#calledAt})
class ApiCallLogs extends Table {
  @override
  String get tableName => 'api_call_log';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get operation => text()();
  DateTimeColumn get calledAt => dateTime()();
  IntColumn get httpStatus => integer().nullable()();
}

import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/connectivity/budgeted_health_checker.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/core/sync/api_budget.dart';

import '../database/database_test_helpers.dart';
import 'connectivity_fakes.dart';

void main() {
  late AppDatabase db;
  late ApiBudget budget;
  late FakeHealthChecker inner;
  late BudgetedHealthChecker checker;

  setUp(() {
    db = createTestDatabase();
    budget = ApiBudget(log: db.apiCallLogDao, limit: 3);
    inner = FakeHealthChecker();
    checker = BudgetedHealthChecker(inner: inner, budget: budget);
  });
  tearDown(() => db.close());

  test(
    'cada ping gasta una llamada del presupuesto y guarda su estado',
    () async {
      await checker.check();

      final row = await db.select(db.apiCallLogs).getSingle();
      expect(row.operation, 'HealthCheck');
      expect(row.httpStatus, 200);
      expect(await budget.used(), 1);
    },
  );

  test('pasa el número de intento al health-check real', () async {
    await checker.check(attempt: 4);

    expect(inner.attempts, [4]);
  });

  test(
    'un fallo del health-check se propaga y consume igualmente el cupo',
    () async {
      inner.failure = const ServiceUnavailableFailure('caída', statusCode: 503);

      await expectLater(
        checker.check(),
        throwsA(isA<ServiceUnavailableFailure>()),
      );

      final row = await db.select(db.apiCallLogs).getSingle();
      expect(row.httpStatus, 503);
      expect(await budget.used(), 1);
    },
  );

  test('sin cupo lanza BudgetExhaustedFailure y no llama a la API', () async {
    for (var i = 0; i < 3; i++) {
      await checker.check();
    }

    await expectLater(checker.check(), throwsA(isA<BudgetExhaustedFailure>()));

    expect(inner.calls, 3);
    expect(await budget.used(), 3);
  });
}

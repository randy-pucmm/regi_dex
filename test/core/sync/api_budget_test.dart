import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/core/database/app_database.dart';
import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/core/sync/api_budget.dart';

import '../database/database_test_helpers.dart';
import 'fake_time.dart';

void main() {
  late AppDatabase db;
  late FakeTime time;
  late ApiBudget budget;

  setUp(() {
    db = createTestDatabase();
    time = FakeTime();
    budget = ApiBudget(log: db.apiCallLogDao);
  });
  tearDown(() => db.close());

  Future<int> acquireMany(int count) async {
    var granted = 0;
    for (var i = 0; i < count; i++) {
      if (await budget.tryAcquire('GetPokemonPage') != null) granted++;
    }
    return granted;
  }

  group('ventana de 60 min', () {
    test(
      'permite 90 llamadas y bloquea la 91',
      () => time.run(() async {
        expect(await acquireMany(90), 90);

        expect(await budget.tryAcquire('GetPokemonPage'), isNull);
        expect(await budget.used(), 90);
        expect(await rowCount(db, 'api_call_log'), 90);
      }),
    );

    test(
      'la llamada 91 sigue bloqueada justo antes de cumplirse la ventana',
      () => time.run(() async {
        await acquireMany(90);

        time.advance(const Duration(minutes: 59, seconds: 59));
        expect(await budget.tryAcquire('A'), isNull);
      }),
    );

    test(
      'el cupo vuelve cuando las llamadas salen de la ventana',
      () => time.run(() async {
        await acquireMany(90);

        time.advance(const Duration(minutes: 60, seconds: 1));

        expect(await budget.used(), 0);
        expect(await acquireMany(90), 90);
        expect(await budget.tryAcquire('A'), isNull);
      }),
    );

    test(
      'la ventana es móvil: el cupo se libera de a poco',
      () => time.run(() async {
        await acquireMany(45);
        time.advance(const Duration(minutes: 30));
        await acquireMany(45);

        time.advance(const Duration(minutes: 31)); // salen las primeras 45

        expect(await budget.used(), 45);
        expect(await acquireMany(50), 45);
      }),
    );

    test(
      'las reservas simultáneas nunca superan el límite',
      () => time.run(() async {
        final results = await Future.wait([
          for (var i = 0; i < 120; i++) budget.tryAcquire('GetPokemonPage'),
        ]);

        expect(results.where((permit) => permit != null), hasLength(90));
        expect(await rowCount(db, 'api_call_log'), 90);
      }),
    );

    test(
      'el consumo sobrevive a un reinicio de la app',
      () => time.run(() async {
        await acquireMany(90);

        final restarted = ApiBudget(log: db.apiCallLogDao);

        expect(await restarted.used(), 90);
        expect(await restarted.tryAcquire('A'), isNull);
      }),
    );

    test(
      'un límite y una ventana distintos se respetan',
      () => time.run(() async {
        final small = ApiBudget(
          log: db.apiCallLogDao,
          limit: 3,
          window: const Duration(minutes: 10),
        );

        for (var i = 0; i < 3; i++) {
          expect(await small.tryAcquire('A'), isNotNull);
        }
        expect(await small.tryAcquire('A'), isNull);

        time.advance(const Duration(minutes: 10, seconds: 1));
        expect(await small.tryAcquire('A'), isNotNull);
      }),
    );
  });

  group('registro', () {
    test(
      'cada reserva se guarda con su operación y su instante',
      () => time.run(() async {
        await budget.tryAcquire('HealthCheck');

        final row = await db.select(db.apiCallLogs).getSingle();
        expect(row.operation, 'HealthCheck');
        expect(row.calledAt, time.now);
        expect(row.httpStatus, isNull);
      }),
    );

    test(
      'el permiso guarda el estado HTTP al completarse',
      () => time.run(() async {
        final permit = await budget.tryAcquire('HealthCheck');

        await permit!.complete(200);

        final row = await db.select(db.apiCallLogs).getSingle();
        expect(row.httpStatus, 200);
      }),
    );

    test(
      'poda las filas de más de 24 h y conserva las recientes',
      () => time.run(() async {
        await budget.tryAcquire('Vieja');
        time.advance(const Duration(hours: 25));
        await budget.tryAcquire('Reciente');

        final rows = await db.select(db.apiCallLogs).get();
        expect(rows.map((row) => row.operation), ['Reciente']);
      }),
    );
  });

  group('timeUntilAvailable', () {
    test(
      'es cero mientras hay cupo',
      () => time.run(() async {
        await acquireMany(10);
        expect(await budget.timeUntilAvailable(), Duration.zero);
      }),
    );

    test(
      'con el cupo agotado es lo que falta para que salga la más antigua',
      () => time.run(() async {
        await acquireMany(90);
        time.advance(const Duration(minutes: 20));

        expect(await budget.timeUntilAvailable(), const Duration(minutes: 40));
      }),
    );
  });

  group('guard', () {
    test(
      'ejecuta la llamada y guarda el estado HTTP 200',
      () => time.run(() async {
        final result = await budget.guard(
          'GetReferenceData',
          () async => 'datos',
        );

        expect(result, 'datos');
        final row = await db.select(db.apiCallLogs).getSingle();
        expect(row.operation, 'GetReferenceData');
        expect(row.httpStatus, 200);
      }),
    );

    test(
      'sin cupo lanza BudgetExhaustedFailure y no ejecuta la llamada',
      () => time.run(() async {
        await acquireMany(90);
        time.advance(const Duration(minutes: 20));
        var called = false;

        await expectLater(
          budget.guard('A', () async {
            called = true;
            return 1;
          }),
          throwsA(
            isA<BudgetExhaustedFailure>().having(
              (f) => f.retryAfter,
              'retryAfter',
              const Duration(minutes: 40),
            ),
          ),
        );

        expect(called, isFalse);
        expect(await rowCount(db, 'api_call_log'), 90);
      }),
    );

    test(
      'un fallo del servicio guarda su estado HTTP y se propaga',
      () => time.run(() async {
        await expectLater(
          budget.guard(
            'A',
            () async =>
                throw const ServiceUnavailableFailure('caída', statusCode: 503),
          ),
          throwsA(isA<ServiceUnavailableFailure>()),
        );

        final row = await db.select(db.apiCallLogs).getSingle();
        expect(row.httpStatus, 503);
      }),
    );

    test(
      'cualquier otro error se propaga y deja el estado HTTP vacío',
      () => time.run(() async {
        await expectLater(
          budget.guard('A', () async => throw const TimeoutFailure()),
          throwsA(isA<TimeoutFailure>()),
        );

        final row = await db.select(db.apiCallLogs).getSingle();
        expect(row.httpStatus, isNull);
      }),
    );

    test(
      'un 429 pausa el presupuesto hasta Retry-After',
      () => time.run(() async {
        await expectLater(
          budget.guard(
            'A',
            () async => throw const RateLimitFailure(
              '429',
              retryAfter: Duration(seconds: 120),
            ),
          ),
          throwsA(isA<RateLimitFailure>()),
        );
        final row = await db.select(db.apiCallLogs).getSingle();
        expect(row.httpStatus, 429);

        expect(await budget.tryAcquire('B'), isNull);
        expect(await budget.timeUntilAvailable(), const Duration(seconds: 120));

        time.advance(const Duration(seconds: 119));
        expect(await budget.tryAcquire('B'), isNull);

        time.advance(const Duration(seconds: 1));
        expect(await budget.tryAcquire('B'), isNotNull);
      }),
    );
  });
}

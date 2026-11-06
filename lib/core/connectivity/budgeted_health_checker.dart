import '../sync/api_budget.dart';
import 'health_checker.dart';

/// Health-check dentro del presupuesto de llamadas (ADR-005): cada ping gasta
/// una de las 90 llamadas por hora. Sin cupo lanza `BudgetExhaustedFailure` y
/// no llama a PokéAPI.
class BudgetedHealthChecker implements HealthChecker {
  const BudgetedHealthChecker({required this._inner, required this._budget});

  final HealthChecker _inner;
  final ApiBudget _budget;

  @override
  Future<void> check({int attempt = 1}) =>
      _budget.guard('HealthCheck', () => _inner.check(attempt: attempt));
}

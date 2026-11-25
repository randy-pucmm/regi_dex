import 'dart:async';

/// Combina dos flujos: emite `combine(a, b)` cada vez que cualquiera de los dos
/// emite, a partir de que ambos tienen al menos un valor. Termina cuando
/// terminan los dos; un error de cualquiera se reenvía. Al cancelar la
/// suscripción se cancelan ambos.
Stream<R> combineLatest2<A, B, R>(
  Stream<A> first,
  Stream<B> second,
  R Function(A a, B b) combine,
) {
  late StreamController<R> controller;
  StreamSubscription<A>? firstSub;
  StreamSubscription<B>? secondSub;
  A? latestA;
  B? latestB;
  var hasA = false;
  var hasB = false;
  var open = 2;

  void emit() {
    if (hasA && hasB) controller.add(combine(latestA as A, latestB as B));
  }

  void done() {
    if (--open == 0) unawaited(controller.close());
  }

  controller = StreamController<R>(
    onListen: () {
      firstSub = first.listen(
        (value) {
          latestA = value;
          hasA = true;
          emit();
        },
        onError: controller.addError,
        onDone: done,
      );
      secondSub = second.listen(
        (value) {
          latestB = value;
          hasB = true;
          emit();
        },
        onError: controller.addError,
        onDone: done,
      );
    },
    onPause: () {
      firstSub?.pause();
      secondSub?.pause();
    },
    onResume: () {
      firstSub?.resume();
      secondSub?.resume();
    },
    // Sin esperar: la cancelación de un flujo de Drift puede depender de un
    // temporizador y no debe bloquear a quien cancela este.
    onCancel: () {
      unawaited(firstSub?.cancel());
      unawaited(secondSub?.cancel());
    },
  );
  return controller.stream;
}

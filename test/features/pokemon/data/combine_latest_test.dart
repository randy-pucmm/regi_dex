import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/features/pokemon/data/combine_latest.dart';

void main() {
  late StreamController<int> a;
  late StreamController<String> b;
  late List<String> out;

  setUp(() {
    a = StreamController<int>();
    b = StreamController<String>();
    out = [];
  });
  // Sin esperar: cerrar un controlador que nadie escuchó no termina nunca.
  tearDown(() {
    unawaited(a.close());
    unawaited(b.close());
  });

  Stream<String> combined() =>
      combineLatest2(a.stream, b.stream, (x, y) => '$x$y');

  test('no emite hasta que ambos tienen un valor', () async {
    final sub = combined().listen(out.add);

    a.add(1);
    await pumpEventQueue();
    expect(out, isEmpty);

    b.add('x');
    await pumpEventQueue();
    expect(out, ['1x']);
    await sub.cancel();
  });

  test('cada valor nuevo combina con el último del otro', () async {
    final sub = combined().listen(out.add);

    a.add(1);
    b.add('x');
    a.add(2);
    b.add('y');
    await pumpEventQueue();

    expect(out, ['1x', '2x', '2y']);
    await sub.cancel();
  });

  test('admite un valor nulo como valor', () async {
    final nullable = StreamController<String?>();
    final sub = combineLatest2(
      a.stream,
      nullable.stream,
      (x, y) => '$x$y',
    ).listen(out.add);

    a.add(1);
    nullable.add(null);
    await pumpEventQueue();

    expect(out, ['1null']);
    await sub.cancel();
    unawaited(nullable.close());
  });

  test('termina cuando terminan los dos', () async {
    var done = false;
    final sub = combined().listen(out.add, onDone: () => done = true);

    a.add(1);
    b.add('x');
    await a.close();
    await pumpEventQueue();
    expect(done, isFalse);

    await b.close();
    await pumpEventQueue();
    expect(done, isTrue);
    await sub.cancel();
  });

  test('un error de cualquiera se reenvía', () async {
    final errors = <Object>[];
    final sub = combined().listen(out.add, onError: errors.add);

    b.addError('falló');
    await pumpEventQueue();

    expect(errors, ['falló']);
    await sub.cancel();
  });

  test('al cancelar se sueltan los dos flujos', () async {
    final sub = combined().listen(out.add);
    await pumpEventQueue();
    expect(a.hasListener && b.hasListener, isTrue);

    await sub.cancel();

    expect(a.hasListener, isFalse);
    expect(b.hasListener, isFalse);
  });
}

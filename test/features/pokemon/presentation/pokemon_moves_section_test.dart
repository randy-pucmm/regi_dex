import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/app/providers.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon_move.dart';
import 'package:regi_dex/features/pokemon/presentation/pokemon_moves_section.dart';

import '../../../helpers/ui_test_helpers.dart';

const _total = 25;

Future<List<MovesRequest>> _open(WidgetTester tester) async {
  useScreen(tester, const Size(390, 2000));
  final requests = <MovesRequest>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pokemonMovesProvider.overrideWith((ref, request) async {
          requests.add(request);
          final all = [
            for (var i = 1; i <= _total; i++)
              PokemonMove(
                id: i,
                name: 'move-$i',
                level: i,
                category: MoveCategory.values[i % 3],
              ),
          ];
          return MovePage(
            moves: all
                .skip(request.page * movesPageSize)
                .take(movesPageSize)
                .toList(),
            page: request.page,
            totalPages: (_total / movesPageSize).ceil(),
          );
        }),
      ],
      child: regiHost(
        const SingleChildScrollView(child: PokemonMovesSection(pokemonId: 1)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return requests;
}

Future<void> _tap(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byTooltip(tooltip));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra 10 movimientos y la página 1 de 3', (tester) async {
    await _open(tester);

    expect(find.text('Move 10'), findsOneWidget);
    expect(find.text('Move 11'), findsNothing);
    expect(find.text('Página 1 de 3'), findsOneWidget);
  });

  testWidgets('siguiente y anterior cambian de página', (tester) async {
    await _open(tester);

    await _tap(tester, 'Página siguiente');
    expect(find.text('Move 11'), findsOneWidget);
    expect(find.text('Move 10'), findsNothing);
    expect(find.text('Página 2 de 3'), findsOneWidget);

    await _tap(tester, 'Página anterior');
    expect(find.text('Move 1'), findsOneWidget);
  });

  testWidgets('en los extremos el botón correspondiente se desactiva', (
    tester,
  ) async {
    await _open(tester);
    IconButton button(String tooltip) => tester.widget(
      find.widgetWithIcon(
        IconButton,
        tooltip == 'prev' ? Icons.chevron_left : Icons.chevron_right,
      ),
    );

    expect(button('prev').onPressed, isNull);
    await _tap(tester, 'Página siguiente');
    await _tap(tester, 'Página siguiente');
    expect(find.text('Página 3 de 3'), findsOneWidget);
    expect(find.text('Move 25'), findsOneWidget);
    expect(button('next').onPressed, isNull);
  });

  testWidgets('cambiar de método vuelve a la primera página', (tester) async {
    final requests = await _open(tester);

    await _tap(tester, 'Página siguiente');
    await tester.tap(find.text('MT'));
    await tester.pumpAndSettle();

    expect(requests.last.method, MoveMethod.machine);
    expect(requests.last.page, 0);
    expect(find.text('Página 1 de 3'), findsOneWidget);
  });

  testWidgets('cada movimiento lleva el icono de su clase de daño', (
    tester,
  ) async {
    await _open(tester);

    expect(find.byIcon(Icons.sports_martial_arts), findsWidgets);
    expect(find.byIcon(Icons.auto_awesome), findsWidgets);
    expect(find.byIcon(Icons.trending_up), findsWidgets);
    expect(find.byTooltip('Especial'), findsWidgets);
  });

  testWidgets('sin movimientos y sin poder descargar avisa de la conexión', (
    tester,
  ) async {
    useScreen(tester, const Size(390, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pokemonDetailRefreshProvider(1).overrideWith((ref) => false),
          pokemonMovesProvider.overrideWith(
            (ref, request) => const MovePage(moves: [], page: 0, totalPages: 0),
          ),
        ],
        child: regiHost(const PokemonMovesSection(pokemonId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('se descargan con conexión'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/features/pokemon/domain/pokemon.dart';
import 'package:regi_dex/features/pokemon/presentation/pokemon_tile.dart';
import 'package:regi_dex/ui/components/pokemon_image.dart';
import 'package:regi_dex/ui/components/type_chip.dart';
import 'package:regi_dex/ui/tokens/regi_colors.dart';

import '../../../helpers/fake_image_cache.dart';
import '../../../helpers/ui_test_helpers.dart';

const _regirock = Pokemon(
  id: 377,
  name: 'regirock',
  baseStatTotal: 580,
  spriteUrl: 'https://example.test/377.png',
  types: [PokemonTypeRef(id: 6, name: 'rock', nameEs: 'Roca')],
);

Widget _tile(Pokemon pokemon, {double width = 400, double textScale = 1}) =>
    regiHost(
      SizedBox(
        width: width,
        child: PokemonTile(pokemon: pokemon, cacheManager: FakeImageCache()),
      ),
      textScale: textScale,
    );

void main() {
  testWidgets('muestra nombre, número y tipos', (tester) async {
    await tester.pumpWidget(_tile(_regirock));

    expect(find.text('Regirock'), findsOneWidget);
    expect(find.text('N.º 0377'), findsOneWidget);
    expect(find.text('ROCA'), findsOneWidget);
  });

  testWidgets('el tipo sale en inglés si la referencia no trae español', (
    tester,
  ) async {
    const bulbasaur = Pokemon(
      id: 1,
      name: 'bulbasaur',
      baseStatTotal: 318,
      types: [
        PokemonTypeRef(id: 12, name: 'grass'),
        PokemonTypeRef(id: 4, name: 'poison', nameEs: 'Veneno'),
      ],
    );
    await tester.pumpWidget(_tile(bulbasaur));

    expect(find.byType(TypeChip), findsNWidgets(2));
    expect(find.text('GRASS'), findsOneWidget);
    expect(find.text('VENENO'), findsOneWidget);
  });

  testWidgets('la placa de la imagen lleva el color del primer tipo', (
    tester,
  ) async {
    await tester.pumpWidget(_tile(_regirock));

    final image = tester.widget<PokemonImage>(find.byType(PokemonImage));
    expect(image.plateColor, RegiTypeColors.of('rock'));
    expect(image.url, _regirock.spriteUrl);
  });

  testWidgets('se anuncia entera como un solo elemento', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_tile(_regirock));

    expect(
      find.bySemanticsLabel('Regirock, número 377, tipo Roca'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('no desborda estrecho y con el texto al 200 %', (tester) async {
    await tester.pumpWidget(_tile(_regirock, width: 300, textScale: 2));

    expect(tester.takeException(), isNull);
  });
}

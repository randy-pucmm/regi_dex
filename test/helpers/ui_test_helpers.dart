import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regi_dex/ui/themes/regi_themes.dart';
import 'package:regi_dex/ui/tokens/regi_palette.dart';

// Un mismo ThemeData por brillo: si cada llamada creara uno nuevo, volver a
// montar el widget animaría el cambio de tema.
final _themes = <Brightness, ThemeData>{};

/// App mínima con el tema Regi para probar un widget suelto.
Widget regiHost(
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Color? background,
}) {
  return MaterialApp(
    theme: _themes.putIfAbsent(
      brightness,
      () => RegiThemes.build(RegiVariant.regirock, brightness),
    ),
    // copyWith: conserva lo que ponga la plataforma, como «reducir movimiento».
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: app!,
    ),
    home: Scaffold(
      backgroundColor: background,
      body: Center(child: child),
    ),
  );
}

/// Pantalla de [size] (y texto a [textScale]) hasta que termine el test.
void useScreen(WidgetTester tester, Size size, {double textScale = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Activa «reducir movimiento» hasta que termine el test. Sin esto, los ojos
/// del LED animan sin parar y `pumpAndSettle` no termina.
void reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/themes/regi_themes.dart';
import '../../../ui/tokens/regi_palette.dart';

/// Tema Regi y modo (claro u oscuro) elegidos por el usuario.
@immutable
class Appearance {
  const Appearance({
    this.variant = RegiThemes.defaultVariant,
    this.mode = ThemeMode.light,
  });

  final RegiVariant variant;
  final ThemeMode mode;

  Appearance copyWith({RegiVariant? variant, ThemeMode? mode}) =>
      Appearance(variant: variant ?? this.variant, mode: mode ?? this.mode);

  @override
  bool operator ==(Object other) =>
      other is Appearance && other.variant == variant && other.mode == mode;

  @override
  int get hashCode => Object.hash(variant, mode);
}

/// Estado de apariencia de la app.
///
/// TODO(RD-34): hoy vive solo en memoria; guardarlo con `PreferenceDao` para
/// que persista entre sesiones (RF-TEM-03).
class AppearanceController extends Notifier<Appearance> {
  @override
  Appearance build() => const Appearance();

  void selectVariant(RegiVariant variant) =>
      state = state.copyWith(variant: variant);

  void selectMode(ThemeMode mode) => state = state.copyWith(mode: mode);
}

final appearanceProvider = NotifierProvider<AppearanceController, Appearance>(
  AppearanceController.new,
);

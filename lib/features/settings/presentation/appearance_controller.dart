import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../ui/themes/regi_themes.dart';
import '../../../ui/tokens/regi_palette.dart';

/// Tema Regi y modo elegidos por el usuario.
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

const themePreferenceKey = 'theme';
const themeModePreferenceKey = 'theme_mode';

/// Guarda el tema y el modo en `user_preference` y los restaura al abrir la
/// app (RF-TEM-03).
class AppearanceController extends Notifier<Appearance> {
  var _touched = false;

  @override
  Appearance build() {
    _restore();
    return const Appearance();
  }

  Future<void> _restore() async {
    final preferences = ref.read(appDatabaseProvider).preferenceDao;
    final variant = await preferences.getValue(themePreferenceKey);
    final mode = await preferences.getValue(themeModePreferenceKey);
    if (_touched || !ref.mounted) return;
    state = Appearance(
      variant: RegiVariant.values.asNameMap()[variant] ?? state.variant,
      mode: ThemeMode.values.asNameMap()[mode] ?? state.mode,
    );
  }

  void selectVariant(RegiVariant variant) {
    _touched = true;
    state = state.copyWith(variant: variant);
    ref
        .read(appDatabaseProvider)
        .preferenceDao
        .setValue(themePreferenceKey, variant.name);
  }

  void selectMode(ThemeMode mode) {
    _touched = true;
    state = state.copyWith(mode: mode);
    ref
        .read(appDatabaseProvider)
        .preferenceDao
        .setValue(themeModePreferenceKey, mode.name);
  }
}

final appearanceProvider = NotifierProvider<AppearanceController, Appearance>(
  AppearanceController.new,
);

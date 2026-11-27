import 'package:flutter/services.dart';

/// Envuelve [onPressed] para dar un toque háptico leve antes de ejecutarlo.
/// Devuelve `null` si [onPressed] es `null`, así el botón sigue deshabilitado
/// y no vibra.
VoidCallback? hapticTap(VoidCallback? onPressed) {
  if (onPressed == null) return null;
  return () {
    HapticFeedback.lightImpact();
    onPressed();
  };
}

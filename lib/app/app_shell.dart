import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/components/pokedex_shell.dart';
import '../ui/components/status_led.dart';
import '../ui/components/status_popover.dart';
import '../ui/themes/regi_theme.dart';
import 'routes.dart';
import 'shell_status.dart';
import 'sync_now.dart';

/// Carcasa común de las pantallas. El texto del estado no está fijo: baja como
/// un desplegable al tocar el LED.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regi = RegiTheme.of(context);
    final status = ref.watch(shellStatusProvider);
    final atHome = GoRouterState.of(context).uri.path == AppRoutes.home;

    return PokedexShell(
      updatedLabel: status.updatedLabel,
      indicators: [
        for (final indicator in status.indicators)
          ShellIndicator(
            label: indicator.label,
            glyph: indicator.glyph,
            color: indicator.tone == null
                ? regi.onShell
                : regi.ledColor(indicator.tone!),
            semanticsLabel: indicator.semantics,
          ),
      ],
      lens: StatusLed(
        state: status.led,
        semanticsLabel: status.semanticsLabel,
        details: StatusDetails(
          title: status.title,
          subtitle: status.subtitle,
          message: status.message,
          rows: status.rows,
          syncing: status.isSyncing,
          onSyncNow: status.canSyncNow
              ? () => unawaited(ref.read(syncNowProvider)())
              : null,
        ),
      ),
      bottomBar: atHome
          ? null
          : ShellHomeButton(onPressed: () => context.go(AppRoutes.home)),
      child: child,
    );
  }
}

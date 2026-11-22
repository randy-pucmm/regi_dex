import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/themes/regi_theme.dart';
import 'catalog_search.dart';

/// Campo de búsqueda del catálogo: nombre («pika») o número nacional («25»,
/// «#025»). Cada cambio llega a [CatalogSearch] con su debounce de 350 ms; el
/// botón de borrar limpia la búsqueda al instante.
class CatalogSearchField extends ConsumerStatefulWidget {
  const CatalogSearchField({super.key});

  @override
  ConsumerState<CatalogSearchField> createState() => _CatalogSearchFieldState();
}

class _CatalogSearchFieldState extends ConsumerState<CatalogSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Si ya había una búsqueda vigente (se volvió a la pantalla) se retoma.
    _controller = TextEditingController(
      text: ref.read(catalogQueryProvider).search,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    ref.read(catalogQueryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: regi.frame, width: 1.5),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: TextField(
          controller: _controller,
          onChanged: ref.read(catalogQueryProvider.notifier).setText,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          enableSuggestions: false,
          style: TextStyle(color: regi.onScreen),
          cursorColor: regi.onScreen,
          decoration: InputDecoration(
            labelText: 'Buscar por nombre o número',
            hintText: 'pika, 25 o #025',
            labelStyle: TextStyle(color: regi.onScreen),
            hintStyle: TextStyle(color: regi.onScreen.withValues(alpha: 0.7)),
            prefixIcon: Icon(Icons.search, color: regi.onScreen),
            suffixIcon: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => _controller.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Borrar búsqueda',
                      icon: Icon(Icons.close, color: regi.onScreen),
                      onPressed: _clear,
                    ),
            ),
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(color: regi.accent, width: 2.5),
            ),
            border: border,
          ),
        ),
      ),
    );
  }
}

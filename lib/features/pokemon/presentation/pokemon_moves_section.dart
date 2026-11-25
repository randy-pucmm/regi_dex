import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../ui/components/type_chip.dart';
import '../../../ui/themes/regi_theme.dart';
import '../../../ui/tokens/contrast.dart';
import '../../../ui/tokens/regi_colors.dart';
import '../domain/pokemon_move.dart';

class PokemonMovesSection extends ConsumerStatefulWidget {
  const PokemonMovesSection({super.key, required this.pokemonId});

  final int pokemonId;

  @override
  ConsumerState<PokemonMovesSection> createState() =>
      _PokemonMovesSectionState();
}

class _PokemonMovesSectionState extends ConsumerState<PokemonMovesSection> {
  var _method = MoveMethod.all;
  var _page = 0;
  int? _versionGroup;

  void _selectMethod(MoveMethod method) => setState(() {
    _method = method;
    _page = 0;
  });

  void _selectGame(int versionGroup) => setState(() {
    _versionGroup = versionGroup;
    _page = 0;
  });

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    final text = Theme.of(context).textTheme;
    final downloaded = ref
        .watch(pokemonDetailRefreshProvider(widget.pokemonId))
        .value;
    final games = ref.watch(pokemonMoveGamesProvider(widget.pokemonId)).value;
    final versionGroup = _versionGroup ?? games?.defaultId;
    final page = versionGroup == null
        ? null
        : ref
              .watch(
                pokemonMovesProvider((
                  pokemonId: widget.pokemonId,
                  method: _method,
                  versionGroupId: versionGroup,
                  page: _page,
                )),
              )
              .value;
    final muted = text.bodySmall?.copyWith(color: regi.onShellMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          'Movimientos',
          style: text.titleSmall?.copyWith(color: regi.onShell),
        ),
        if (games == null)
          const Center(child: CircularProgressIndicator())
        else if (games.games.isEmpty)
          Text(
            downloaded == false
                ? 'Los movimientos se descargan con conexión.'
                : 'Sin movimientos.',
            style: muted,
          )
        else ...[
          _GamePicker(
            games: games.games,
            selected: versionGroup,
            onChanged: _selectGame,
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final method in MoveMethod.values)
                ChoiceChip(
                  label: Text(method.label),
                  selected: method == _method,
                  onSelected: (_) => _selectMethod(method),
                  showCheckmark: false,
                  color: WidgetStatePropertyAll(
                    method == _method ? regi.accent : RegiInk.shell,
                  ),
                  side: BorderSide(color: regi.onShellMuted),
                  labelStyle: TextStyle(
                    color: method == _method
                        ? readableOn(regi.accent)
                        : regi.onShell,
                  ),
                ),
            ],
          ),
          if (page == null)
            const Center(child: CircularProgressIndicator())
          else if (page.moves.isEmpty)
            Text('Sin movimientos de este tipo en este juego.', style: muted)
          else ...[
            for (final move in page.moves)
              _MoveRow(move: move, showLevel: _method == MoveMethod.levelUp),
            if (page.totalPages > 1)
              _Pager(
                page: page,
                onPrevious: () => setState(() => _page--),
                onNext: () => setState(() => _page++),
              ),
          ],
        ],
      ],
    );
  }
}

class _GamePicker extends StatelessWidget {
  const _GamePicker({
    required this.games,
    required this.selected,
    required this.onChanged,
  });

  final List<MoveGame> games;
  final int? selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    return Semantics(
      label: 'Juego',
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: regi.onShellMuted),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: selected,
              dropdownColor: RegiInk.shell,
              iconEnabledColor: regi.onShell,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: regi.onShell),
              onChanged: (id) {
                if (id != null) onChanged(id);
              },
              items: [
                for (final game in games)
                  DropdownMenuItem(value: game.id, child: Text(game.label)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.onPrevious,
    required this.onNext,
  });

  final MovePage page;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 8,
      children: [
        IconButton(
          tooltip: 'Página anterior',
          color: regi.onShell,
          onPressed: page.hasPrevious ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          'Página ${page.page + 1} de ${page.totalPages}',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: regi.onShell),
        ),
        IconButton(
          tooltip: 'Página siguiente',
          color: regi.onShell,
          onPressed: page.hasNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _MoveRow extends StatelessWidget {
  const _MoveRow({required this.move, required this.showLevel});

  final PokemonMove move;
  final bool showLevel;

  static const _icons = {
    MoveCategory.physical: Icons.sports_martial_arts,
    MoveCategory.special: Icons.auto_awesome,
    MoveCategory.status: Icons.trending_up,
  };

  @override
  Widget build(BuildContext context) {
    final regi = RegiTheme.of(context);
    final text = Theme.of(context).textTheme;
    final type = move.typeName;
    final category = move.category;
    final stats = [
      if (move.power != null) 'Pot. ${move.power}',
      if (move.accuracy != null) 'Prec. ${move.accuracy}',
      if (move.pp != null) 'PP ${move.pp}',
    ].join(' · ');

    return Semantics(
      container: true,
      child: Row(
        spacing: 8,
        children: [
          if (showLevel)
            SizedBox(
              width: 44,
              child: Text(
                'Nv. ${move.level}',
                style: text.labelSmall?.copyWith(color: regi.onShellMuted),
              ),
            ),
          if (category != null)
            Tooltip(
              message: category.label,
              child: Icon(
                _icons[category],
                color: regi.onShell,
                semanticLabel: category.label,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label(move.name),
                  style: text.bodyMedium?.copyWith(color: regi.onShell),
                ),
                if (stats.isNotEmpty)
                  Text(
                    stats,
                    style: text.labelSmall?.copyWith(color: regi.onShellMuted),
                  ),
              ],
            ),
          ),
          if (type != null)
            TypeChip(typeKey: type, label: move.typeNameEs ?? type),
        ],
      ),
    );
  }

  static String _label(String name) {
    final spaced = name.replaceAll('-', ' ');
    return spaced.isEmpty
        ? spaced
        : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }
}

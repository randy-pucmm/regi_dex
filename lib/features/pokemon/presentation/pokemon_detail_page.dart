import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/image_providers.dart';
import '../../../app/providers.dart';
import '../../../ui/components/pokemon_image.dart';
import '../../../ui/components/stat_bar.dart';
import '../../../ui/components/type_chip.dart';
import '../../../ui/tokens/regi_colors.dart';
import '../domain/pokemon.dart';
import '../domain/pokemon_detail.dart';
import 'pokemon_evolutions_section.dart';
import 'pokemon_matchups_section.dart';
import 'pokemon_moves_section.dart';

class PokemonDetailPage extends ConsumerStatefulWidget {
  const PokemonDetailPage({super.key, required this.id, this.preview});

  final int id;
  final Pokemon? preview;

  @override
  ConsumerState<PokemonDetailPage> createState() => _PokemonDetailPageState();
}

class _PokemonDetailPageState extends ConsumerState<PokemonDetailPage> {
  late var _formId = widget.id;
  var _shiny = false;
  var _female = false;

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final preview = widget.preview;
    ref.watch(pokemonDetailRefreshProvider(id));
    final base = ref.watch(pokemonDetailProvider(id));
    // Mientras no se descargue la forma elegida se sigue viendo la base.
    var form = base.value;
    var missingForm = false;
    if (_formId != id) {
      final downloaded = ref.watch(pokemonDetailRefreshProvider(_formId)).value;
      final selected = ref.watch(pokemonDetailProvider(_formId)).value;
      form = selected ?? form;
      missingForm = selected == null && downloaded == false;
    }
    final shown =
        form ?? (preview == null ? null : PokemonDetail.preview(preview));
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Volver',
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        Expanded(
          child: switch (base) {
            _ when shown != null => _Detail(
              heroId: id,
              detail: shown,
              forms: base.value?.forms ?? const [],
              formId: _formId,
              missingForm: missingForm,
              shiny: _shiny,
              female: _female,
              onForm: (formId) => setState(() => _formId = formId),
              onShiny: () => setState(() => _shiny = !_shiny),
              onGender: () => setState(() => _female = !_female),
            ),
            AsyncData() => const _Notice(
              'Este Pokémon no está en el catálogo.',
            ),
            AsyncError() => const _Notice('No se pudo leer el Pokémon.'),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ],
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({
    required this.heroId,
    required this.detail,
    required this.forms,
    required this.formId,
    required this.missingForm,
    required this.shiny,
    required this.female,
    required this.onForm,
    required this.onShiny,
    required this.onGender,
  });

  final int heroId;
  final PokemonDetail detail;
  final List<PokemonFormRef> forms;
  final int formId;
  final bool missingForm;
  final bool shiny;
  final bool female;
  final ValueChanged<int> onForm;
  final VoidCallback onShiny;
  final VoidCallback onGender;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pokemon = detail.pokemon;
    final text = Theme.of(context).textTheme;
    final name = _capitalize(pokemon.name);
    final number =
        'N.º ${(detail.speciesId ?? pokemon.id).toString().padLeft(4, '0')}';
    final isFavorite =
        ref.watch(favoriteIdsProvider).value?.contains(heroId) ?? false;
    final artwork = pokemon.artworkUrl ?? pokemon.spriteUrl;
    final art = detail.genderArt;
    final shownFemale = female && art != null;
    final image = art == null
        ? (shiny ? detail.shinyUrl : null)
        : shownFemale
        ? (shiny ? art.femaleShiny : art.female)
        : (shiny ? art.maleShiny : art.male);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Center(
          child: Hero(
            tag: PokemonImage.heroTag(heroId),
            child: PokemonImage(
              url: image ?? artwork,
              size: 220,
              label: [
                name,
                if (shownFemale) 'hembra',
                if (shiny) 'shiny',
              ].join(' '),
              cacheManager: ref.watch(imageCacheManagerProvider),
              plateColor: pokemon.types.isEmpty
                  ? null
                  : RegiTypeColors.of(pokemon.types.first.name),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: isFavorite
                  ? 'Quitar de favoritos'
                  : 'Agregar a favoritos',
              isSelected: isFavorite,
              icon: const Icon(Icons.favorite_border),
              selectedIcon: const Icon(Icons.favorite),
              onPressed: () {
                final favorites = ref.read(appDatabaseProvider).favoriteDao;
                isFavorite
                    ? favorites.removeFavorite(heroId)
                    : favorites.addFavorite(heroId);
              },
            ),
            IconButton(
              tooltip: shiny ? 'Ver color normal' : 'Ver shiny',
              isSelected: shiny,
              icon: const Icon(Icons.auto_awesome_outlined),
              selectedIcon: const Icon(Icons.auto_awesome),
              onPressed: detail.shinyUrl == null ? null : onShiny,
            ),
            if (art != null)
              IconButton(
                tooltip: female ? 'Ver macho' : 'Ver hembra',
                isSelected: female,
                icon: const Icon(Icons.male),
                selectedIcon: const Icon(Icons.female),
                onPressed: onGender,
              ),
            IconButton(
              tooltip: 'Compartir',
              icon: const Icon(Icons.share),
              onPressed: () {
                final types = [
                  for (final t in pokemon.types)
                    _capitalize(t.nameEs ?? t.name),
                ].join('/');
                ref.read(shareTextProvider)(
                  '$name ($number) · Tipo: $types · RegiDex',
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(number, textAlign: TextAlign.center, style: text.labelMedium),
        Text(name, textAlign: TextAlign.center, style: text.headlineMedium),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          children: [
            for (final type in pokemon.types)
              TypeChip(typeKey: type.name, label: type.nameEs ?? type.name),
          ],
        ),
        if (forms.length > 1) ...[
          const SizedBox(height: 12),
          _Forms(forms: forms, formId: formId, onForm: onForm),
          if (missingForm)
            const _Notice('Esta forma se descarga con conexión.'),
        ],
        const SizedBox(height: 20),
        _Panel(child: _Profile(detail: detail)),
        const SizedBox(height: 12),
        _Panel(child: _Stats(stats: detail.stats)),
        const SizedBox(height: 12),
        _Panel(child: _Abilities(abilities: detail.abilities)),
        const SizedBox(height: 12),
        _Panel(child: PokemonEvolutionsSection(pokemonId: pokemon.id)),
        const SizedBox(height: 12),
        _Panel(child: PokemonMatchupsSection(types: pokemon.types)),
        const SizedBox(height: 12),
        _Panel(
          child: PokemonMovesSection(
            key: ValueKey(pokemon.id),
            pokemonId: pokemon.id,
          ),
        ),
      ],
    );
  }
}

/// Un selector cambia de región y otro de disfraz; los chips muestran las demás
/// formas de la región elegida.
class _Forms extends StatelessWidget {
  const _Forms({
    required this.forms,
    required this.formId,
    required this.onForm,
  });

  final List<PokemonFormRef> forms;
  final int formId;
  final ValueChanged<int> onForm;

  @override
  Widget build(BuildContext context) {
    final bases = <String?, PokemonFormRef>{};
    for (final form in forms) {
      bases.putIfAbsent(form.region, () => form);
    }
    final region = forms.where((f) => f.id == formId).firstOrNull?.region;
    final base = bases[region]!;
    final others = [
      for (final form in forms)
        if (form.region == region && form != base) form,
    ];
    final costumes = [
      for (final form in others)
        if (form.isCostume) form,
    ];
    final worn = costumes.where((f) => f.id == formId).firstOrNull;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        if (bases.length > 1)
          _selector(bases.values, base.label, base.id == formId)
        else
          _chip(base),
        if (costumes.isNotEmpty)
          _selector(costumes, worn?.label ?? 'Disfraces', worn != null),
        for (final form in others)
          if (!form.isCostume) _chip(form),
      ],
    );
  }

  Widget _chip(PokemonFormRef form) => ChoiceChip(
    label: Text(form.label),
    selected: form.id == formId,
    onSelected: (_) => onForm(form.id),
  );

  Widget _selector(
    Iterable<PokemonFormRef> options,
    String label,
    bool selected,
  ) => MenuAnchor(
    menuChildren: [
      for (final form in options)
        MenuItemButton(
          onPressed: () => onForm(form.id),
          child: Text(form.label),
        ),
    ],
    builder: (context, menu, _) => ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Text(label), const Icon(Icons.arrow_drop_down, size: 18)],
      ),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => menu.isOpen ? menu.close() : menu.open(),
    ),
  );
}

/// Tarjeta oscura: los textos y las barras de las secciones están pensados
/// para fondo oscuro.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: RegiInk.shell,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: RegiInk.onShellMuted),
    ),
    child: Padding(padding: const EdgeInsets.all(14), child: child),
  );
}

class _Profile extends StatelessWidget {
  const _Profile({required this.detail});

  final PokemonDetail detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final eggGroups = detail.eggGroups.map(_capitalize).join(', ');
    // PokéAPI da decímetros y hectogramos; 0 es que aún no se descargó.
    String measure(int tenths, String unit) => tenths == 0
        ? '—'
        : '${(tenths / 10).toStringAsFixed(1).replaceAll('.', ',')} $unit';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        for (final (label, value) in [
          ('Altura', measure(detail.height, 'm')),
          ('Peso', measure(detail.weight, 'kg')),
          ('Grupos huevo', eggGroups.isEmpty ? '—' : eggGroups),
        ])
          Expanded(
            child: Semantics(
              container: true,
              child: Column(
                children: [
                  Text(
                    label,
                    style: text.labelSmall?.copyWith(
                      color: RegiInk.onShellMuted,
                    ),
                  ),
                  Text(
                    value,
                    textAlign: TextAlign.center,
                    style: text.titleSmall?.copyWith(color: RegiInk.onShell),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.stats});

  final Map<int, int> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const _Notice('Las estadísticas se descargan con conexión.');
    }
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 12,
      children: [
        for (final stat in RegiStat.values)
          SizedBox(
            width: 96,
            child: StatBar(stat: stat, value: stats[stat.index + 1] ?? 0),
          ),
      ],
    );
  }
}

class _Abilities extends StatelessWidget {
  const _Abilities({required this.abilities});

  final List<PokemonAbilityRef> abilities;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        for (final ability in abilities)
          Semantics(
            container: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_capitalize(ability.nameEs ?? ability.name)}'
                  '${ability.isHidden ? ' · Oculta' : ''}',
                  style: text.titleSmall?.copyWith(color: RegiInk.onShell),
                ),
                if (ability.summary != null)
                  Text(
                    ability.summary!,
                    style: text.bodySmall?.copyWith(
                      color: RegiInk.onShellMuted,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: RegiInk.onShellMuted),
      ),
    ),
  );
}

String _capitalize(String name) =>
    name.isEmpty ? name : '${name[0].toUpperCase()}${name.substring(1)}';

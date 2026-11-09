import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/image_providers.dart';
import '../../../app/providers.dart';
import '../../../ui/components/hub_buttons.dart';
import '../../../ui/tokens/regi_colors.dart';
import '../domain/pokemon.dart';
import 'catalog_state.dart';
import 'pokemon_tile.dart';

class CatalogPage extends ConsumerWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void retry() => ref.read(refreshCatalogProvider)().ignore();

    return switch (ref.watch(catalogStateProvider)) {
      CatalogLoaded(:final pokemon) => _PokemonList(
        pokemon: pokemon,
        cacheManager: ref.watch(imageCacheManagerProvider),
      ),
      CatalogLoading() => const _Message(
        title: 'Descargando el catálogo…',
        body: 'La primera vez tarda unos segundos.',
      ),
      CatalogEmpty() => _Message(
        title: 'Aún no hay catálogo',
        body:
            'Conéctate a Internet una vez para descargarlo. '
            'Después funciona sin conexión.',
        onRetry: retry,
      ),
      CatalogError() => _Message(
        title: 'No se pudo descargar el catálogo',
        body:
            'PokéAPI no respondió. La app lo reintenta sola; también puedes '
            'hacerlo ahora.',
        onRetry: retry,
      ),
    };
  }
}

class _PokemonList extends StatelessWidget {
  const _PokemonList({required this.pokemon, required this.cacheManager});

  final List<Pokemon> pokemon;
  final BaseCacheManager cacheManager;

  static const _tileWidth = 420.0;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / _tileWidth).floor().clamp(1, 3);
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: (pokemon.length / columns).ceil(),
          itemBuilder: (context, row) => Padding(
            padding: const EdgeInsets.only(bottom: _gap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: _gap,
              children: [
                for (var i = row * columns; i < (row + 1) * columns; i++)
                  Expanded(
                    child: i < pokemon.length
                        ? PokemonTile(
                            pokemon: pokemon[i],
                            cacheManager: cacheManager,
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body, this.onRetry});

  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: text.titleLarge,
                ),
              ),
              Text(body, textAlign: TextAlign.center, style: text.bodyMedium),
              if (onRetry != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: 200,
                    child: HexButton(
                      label: 'Reintentar',
                      color: RegiInk.onShell,
                      onPressed: onRetry,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

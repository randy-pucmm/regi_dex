import 'package:flutter/services.dart';

import 'graphql_operation.dart';

/// Carga los documentos `.graphql` desde los assets y los guarda en memoria.
class OperationLoader {
  OperationLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final _cache = <GraphqlOperation, String>{};

  /// Devuelve el documento completo de [operation]; si usa `PokemonLight`,
  /// le añade el fragmento.
  Future<String> load(GraphqlOperation operation) async {
    final cached = _cache[operation];
    if (cached != null) return cached;

    final body = await _bundle.loadString(operation.assetPath);
    final document = operation.usesPokemonLight
        ? '$body\n${await _bundle.loadString(GraphqlOperation.pokemonLightAssetPath)}'
        : body;
    return _cache[operation] = document;
  }
}

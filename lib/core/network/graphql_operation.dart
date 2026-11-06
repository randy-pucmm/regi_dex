/// Operaciones GraphQL de PokéAPI (documento de arquitectura §6.2).
/// Cada una vive en `lib/core/network/operations/<operationName>.graphql`.
enum GraphqlOperation {
  healthCheck('HealthCheck'),
  getReferenceData('GetReferenceData'),
  getPokemonPage('GetPokemonPage', usesPokemonLight: true),
  getPokemonDetail('GetPokemonDetail'),
  getPokemonsByIds('GetPokemonsByIds', usesPokemonLight: true),
  searchPokemonRemote('SearchPokemonRemote', usesPokemonLight: true);

  const GraphqlOperation(this.operationName, {this.usesPokemonLight = false});

  /// Nombre de la operación en el documento y en los registros de consola.
  final String operationName;

  /// Indica si el documento usa el fragmento `PokemonLight`.
  final bool usesPokemonLight;

  /// Ruta del asset con el documento de la operación.
  String get assetPath => '$assetDirectory/$operationName.graphql';

  /// Directorio de los assets `.graphql`.
  static const assetDirectory = 'lib/core/network/operations';

  /// Ruta del asset con el fragmento `PokemonLight`.
  static const pokemonLightAssetPath = '$assetDirectory/PokemonLight.graphql';
}

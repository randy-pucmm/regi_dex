import 'pokemon_repository.dart';

/// Caso de uso: sincronizar el catálogo con PokéAPI ahora.
class RefreshCatalog {
  const RefreshCatalog(this._repository);

  final PokemonRepository _repository;

  Future<void> call() => _repository.refresh();
}

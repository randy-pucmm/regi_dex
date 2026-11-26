import 'package:regi_dex/core/error/failure.dart';
import 'package:regi_dex/features/pokemon/data/pokemon_remote_source.dart';

import 'catalog_test_data.dart';

/// Remoto falso: sirve páginas sintéticas y registra qué se le pidió.
class FakePokemonRemote implements PokemonRemoteSource {
  FakePokemonRemote({this.total = 450});

  final int total;
  var referenceCalls = 0;
  final pageOffsets = <int>[];

  /// Offset en el que la llamada falla con [NetworkFailure].
  int? failAtOffset;

  /// Permite alterar la página antes de entregarla.
  void Function(Map<String, dynamic> page)? tamper;

  /// Búsquedas pedidas con [searchPokemon], en orden: `nombre:x` o `numero:n`.
  final searches = <String>[];

  /// Ids que devuelve [searchPokemon] (el Pokémon sintético de cada id).
  var searchResultIds = <int>[];

  /// Falla [searchPokemon] con [NetworkFailure] mientras sea true.
  var failSearch = false;

  @override
  Future<Map<String, dynamic>> searchPokemon({
    String? name,
    int? number,
    int limit = PokemonRemoteSource.searchLimit,
  }) async {
    searches.add(name != null ? 'nombre:$name' : 'numero:$number');
    if (failSearch) throw const NetworkFailure();
    return {
      'pokemon': [for (final id in searchResultIds) syntheticPokemon(id)],
    };
  }

  /// Lotes pedidos con [fetchByIds], en orden.
  final idBatches = <List<int>>[];

  /// Falla [fetchByIds] con [NetworkFailure] mientras sea true.
  var failByIds = false;

  /// Permite alterar la respuesta de [fetchByIds] (la versión «remota»).
  void Function(Map<String, dynamic> page)? tamperByIds;

  @override
  Future<Map<String, dynamic>> fetchByIds(List<int> ids) async {
    idBatches.add([...ids]);
    if (failByIds) throw const NetworkFailure();
    final page = {
      'pokemon': [for (final id in ids) syntheticPokemon(id)],
    };
    tamperByIds?.call(page);
    return page;
  }

  /// Ids pedidos con [fetchDetail], en orden.
  final detailIds = <int>[];

  /// Falla [fetchDetail] con [NetworkFailure] mientras sea true.
  var failDetail = false;

  /// Permite alterar el detalle antes de entregarlo.
  void Function(Map<String, dynamic> detail)? tamperDetail;

  @override
  Future<Map<String, dynamic>> fetchDetail(int id) async {
    detailIds.add(id);
    if (failDetail) throw const NetworkFailure();
    final detail = syntheticDetail(id);
    tamperDetail?.call(detail);
    return detail;
  }

  @override
  Future<Map<String, dynamic>> fetchReference() async {
    referenceCalls++;
    return syntheticReference(total: total);
  }

  @override
  Future<Map<String, dynamic>> fetchPage({
    required int offset,
    required int limit,
  }) async {
    pageOffsets.add(offset);
    if (offset == failAtOffset) throw const NetworkFailure();
    final page = syntheticPage(offset: offset, limit: limit, total: total);
    tamper?.call(page);
    return page;
  }
}

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

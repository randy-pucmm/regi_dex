/// Criterios para consultar el catálogo.
///
/// La consulta vacía devuelve todo el catálogo ordenado por número nacional.
/// [search] filtra por nombre o número nacional (RD-26); los filtros y el orden
/// (RD-27) se agregarán sin cambiar el contrato del repositorio.
class PokemonQuery {
  const PokemonQuery({this.search = ''});

  /// Texto que escribió la persona, sin normalizar. Vacío = sin búsqueda.
  final String search;

  /// Término interpretado de [search], o null si no hay búsqueda.
  SearchTerm? get term => SearchTerm.parse(search);

  /// Copia con los campos indicados cambiados.
  PokemonQuery copyWith({String? search}) =>
      PokemonQuery(search: search ?? this.search);

  @override
  bool operator ==(Object other) =>
      other is PokemonQuery && other.search == search;

  @override
  int get hashCode => Object.hash(PokemonQuery, search);
}

/// Texto de búsqueda ya interpretado: o un número nacional exacto o un trozo
/// del nombre. «25», «#025» y «#0378» son números; «pika» es un nombre.
sealed class SearchTerm {
  const SearchTerm();

  /// Interpreta [raw]: recorta, pasa a minúsculas y quita un `#` inicial. Si
  /// queda solo dígitos es [SearchNumber] (los ceros a la izquierda no cuentan);
  /// si queda otro texto, [SearchName]. Devuelve null si no queda nada.
  static SearchTerm? parse(String raw) {
    var text = raw.trim().toLowerCase();
    if (text.startsWith('#')) text = text.substring(1).trim();
    if (text.isEmpty) return null;
    if (RegExp(r'^\d+$').hasMatch(text)) {
      final number = int.tryParse(text);
      // Un número desbordado no es un Pokémon: se busca como nombre.
      if (number != null) return SearchNumber(number);
    }
    return SearchName(text);
  }
}

/// Número nacional de la Pokédex.
final class SearchNumber extends SearchTerm {
  const SearchNumber(this.number);

  final int number;

  @override
  bool operator ==(Object other) =>
      other is SearchNumber && other.number == number;

  @override
  int get hashCode => Object.hash(SearchNumber, number);
}

/// Trozo del nombre (en minúsculas, sin `%` ni `_` escapados).
final class SearchName extends SearchTerm {
  const SearchName(this.text);

  final String text;

  @override
  bool operator ==(Object other) => other is SearchName && other.text == text;

  @override
  int get hashCode => Object.hash(SearchName, text);
}

import 'dart:convert';

/// Campo por el que se ordena el catálogo (RF-FIL-03).
enum PokemonSort {
  /// Número nacional.
  number,

  /// Nombre, sin distinguir mayúsculas.
  name,

  /// Suma de las estadísticas base.
  baseTotal,
}

/// Criterios para consultar el catálogo.
///
/// La consulta vacía devuelve todo el catálogo ordenado por número nacional.
/// [search] filtra por nombre o número nacional (RD-26). Los filtros por tipo,
/// generación, grupo huevo y habilidad (RD-27) se **combinan**: debe cumplirse
/// cada categoría con algún valor, y dentro de una categoría basta uno de los
/// valores elegidos (p. ej. tipo Roca **o** Tierra, **y** grupo huevo Mineral).
class PokemonQuery {
  const PokemonQuery({
    this.search = '',
    this.types = const {},
    this.generations = const {},
    this.eggGroups = const {},
    this.abilities = const {},
    this.sort = PokemonSort.number,
    this.descending = false,
  });

  /// Texto que escribió la persona, sin normalizar. Vacío = sin búsqueda.
  final String search;

  /// Ids de tipo, de generación, de grupo huevo y de habilidad elegidos. Vacío =
  /// no se filtra por esa categoría.
  final Set<int> types;
  final Set<int> generations;
  final Set<int> eggGroups;
  final Set<int> abilities;

  final PokemonSort sort;

  /// Orden de mayor a menor.
  final bool descending;

  /// Término interpretado de [search], o null si no hay búsqueda.
  SearchTerm? get term => SearchTerm.parse(search);

  /// Cuántos filtros de categoría hay activos (de 0 a 4), sin contar la búsqueda.
  int get activeFilterCount => [
    types,
    generations,
    eggGroups,
    abilities,
  ].where((ids) => ids.isNotEmpty).length;

  /// Hay algún filtro de categoría activo.
  bool get hasFilters => activeFilterCount > 0;

  /// Mismos filtros con la búsqueda y el orden por defecto: sirve para saber
  /// si quitar la búsqueda cambia algo.
  bool get isDefault =>
      search.trim().isEmpty &&
      !hasFilters &&
      sort == PokemonSort.number &&
      !descending;

  /// Copia con los campos indicados cambiados.
  PokemonQuery copyWith({
    String? search,
    Set<int>? types,
    Set<int>? generations,
    Set<int>? eggGroups,
    Set<int>? abilities,
    PokemonSort? sort,
    bool? descending,
  }) => PokemonQuery(
    search: search ?? this.search,
    types: _frozen(types) ?? this.types,
    generations: _frozen(generations) ?? this.generations,
    eggGroups: _frozen(eggGroups) ?? this.eggGroups,
    abilities: _frozen(abilities) ?? this.abilities,
    sort: sort ?? this.sort,
    descending: descending ?? this.descending,
  );

  /// Copia sin ningún filtro de categoría; conserva la búsqueda y el orden.
  PokemonQuery withoutFilters() =>
      PokemonQuery(search: search, sort: sort, descending: descending);

  /// Mapa listo para guardar como JSON (RF-FIL-04).
  Map<String, Object> toJson() => {
    'search': search,
    'types': types.toList()..sort(),
    'generations': generations.toList()..sort(),
    'eggGroups': eggGroups.toList()..sort(),
    'abilities': abilities.toList()..sort(),
    'sort': sort.name,
    'descending': descending,
  };

  /// Texto JSON de [toJson].
  String encode() => jsonEncode(toJson());

  /// Lee una consulta guardada. Tolerante: un texto que no es JSON o un campo
  /// con otro tipo o un valor desconocido se ignora y queda el valor por
  /// defecto, para que una preferencia vieja o dañada nunca rompa el arranque.
  factory PokemonQuery.decode(String? source) {
    if (source == null) return const PokemonQuery();
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException {
      return const PokemonQuery();
    }
    if (json is! Map<String, dynamic>) return const PokemonQuery();
    final search = json['search'];
    final sortName = json['sort'];
    return PokemonQuery(
      search: search is String ? search : '',
      types: _ids(json['types']),
      generations: _ids(json['generations']),
      eggGroups: _ids(json['eggGroups']),
      abilities: _ids(json['abilities']),
      sort: PokemonSort.values.firstWhere(
        (value) => value.name == sortName,
        orElse: () => PokemonSort.number,
      ),
      descending: json['descending'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PokemonQuery &&
      other.search == search &&
      _sameIds(other.types, types) &&
      _sameIds(other.generations, generations) &&
      _sameIds(other.eggGroups, eggGroups) &&
      _sameIds(other.abilities, abilities) &&
      other.sort == sort &&
      other.descending == descending;

  @override
  int get hashCode => Object.hash(
    PokemonQuery,
    search,
    Object.hashAllUnordered(types),
    Object.hashAllUnordered(generations),
    Object.hashAllUnordered(eggGroups),
    Object.hashAllUnordered(abilities),
    sort,
    descending,
  );
}

Set<int>? _frozen(Set<int>? ids) => ids == null ? null : Set.unmodifiable(ids);

bool _sameIds(Set<int> a, Set<int> b) =>
    a.length == b.length && a.containsAll(b);

/// Ids enteros de [value] (una lista JSON); ignora lo que no sea entero.
Set<int> _ids(Object? value) =>
    value is List ? Set.unmodifiable(value.whereType<int>()) : const {};

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

/// Trozo del nombre, ya en minúsculas.
final class SearchName extends SearchTerm {
  const SearchName(this.text);

  final String text;

  @override
  bool operator ==(Object other) => other is SearchName && other.text == text;

  @override
  int get hashCode => Object.hash(SearchName, text);
}

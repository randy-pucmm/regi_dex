import '../../../../core/error/failure.dart';

/// Lectura validada de un objeto JSON para los DTO: un campo ausente o de otro
/// tipo lanza [ValidationFailure] y el lote entero se descarta (OF-04).
class JsonReader {
  const JsonReader(this.json, this.context);

  final Map<String, dynamic> json;

  /// Ruta del objeto dentro de la respuesta, para los mensajes de error.
  final String context;

  int integer(String key) => switch (json[key]) {
    final int value => value,
    _ => throw _invalid(key, 'un entero'),
  };

  int? integerOrNull(String key) => switch (json[key]) {
    null => null,
    final int value => value,
    _ => throw _invalid(key, 'un entero o null'),
  };

  String string(String key) => switch (json[key]) {
    final String value => value,
    _ => throw _invalid(key, 'un texto'),
  };

  String? stringOrNull(String key) => switch (json[key]) {
    null => null,
    final String value => value,
    _ => throw _invalid(key, 'un texto o null'),
  };

  bool boolean(String key, {bool defaultValue = false}) => switch (json[key]) {
    null => defaultValue,
    final bool value => value,
    _ => throw _invalid(key, 'un booleano'),
  };

  /// Objeto anidado obligatorio.
  JsonReader object(String key) => switch (json[key]) {
    final Map<String, dynamic> value => JsonReader(value, '$context.$key'),
    _ => throw _invalid(key, 'un objeto'),
  };

  /// Lista obligatoria de objetos.
  List<JsonReader> objects(String key) => switch (json[key]) {
    final List<dynamic> values => [
      for (final (index, value) in values.indexed)
        switch (value) {
          final Map<String, dynamic> item => JsonReader(
            item,
            '$context.$key[$index]',
          ),
          _ => throw _invalid('$key[$index]', 'un objeto'),
        },
    ],
    _ => throw _invalid(key, 'una lista'),
  };

  /// Nombre en [language] dentro de la lista [key] de `{name, language: {name}}`,
  /// o null si no hay traducción.
  String? localizedName(String key, String language) {
    for (final item in objects(key)) {
      if (item.object('language').string('name') == language) {
        return item.string('name');
      }
    }
    return null;
  }

  ValidationFailure _invalid(String key, String expected) => ValidationFailure(
    '$context.$key: se esperaba $expected y llegó ${json[key.split('[').first]}',
  );
}

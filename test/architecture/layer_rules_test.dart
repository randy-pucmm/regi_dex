// Verifica las reglas de dependencia entre capas (D03/D04) leyendo los imports de lib/.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _importPattern = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

/// Devuelve los imports de cada archivo Dart de `lib/` cuyo path contiene [layer].
Map<String, List<String>> _importsOfLayer(String layer) {
  final result = <String, List<String>>{};
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    if (!path.contains('/$layer/')) continue;
    result[path] = [
      for (final line in file.readAsLinesSync())
        if (_importPattern.firstMatch(line) case final match?) match.group(1)!,
    ];
  }
  return result;
}

/// Lista «archivo → import» de los imports que contienen alguno de [forbidden].
List<String> _violations(String layer, List<String> forbidden) => [
  for (final entry in _importsOfLayer(layer).entries)
    for (final import in entry.value)
      if (forbidden.any(import.contains)) '${entry.key} → $import',
];

void main() {
  test(
    'domain no importa Flutter, Riverpod, Drift, GraphQL ni otras capas',
    () {
      final violations = _violations('domain', [
        'package:flutter/',
        'package:flutter_riverpod',
        'package:go_router',
        'package:drift',
        'package:graphql',
        '/data/',
        '/presentation/',
      ]);
      expect(violations, isEmpty);
    },
  );

  test('presentation no importa GraphQL, Drift ni DTOs', () {
    final violations = _violations('presentation', [
      'package:graphql',
      'package:drift',
      '/dto/',
      'core/network/',
      'core/database/',
    ]);
    expect(violations, isEmpty);
  });
}

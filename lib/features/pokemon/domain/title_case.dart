/// Nombre de PokéAPI con cada palabra en mayúscula: `red-blue` → `Red Blue`.
String titleCase(String slug) => slug
    .split('-')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

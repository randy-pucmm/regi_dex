import '../../../../core/error/failure.dart';
import '../../../pokemon/data/dto/json_reader.dart';

/// Índice de Champions (`GET /api`). Solo se leen los campos que usa la app;
/// el resto de las ~18 MB (`battleSummary`, `battleDataCsvs`) se ignora.
class ChampionsIndexDto {
  const ChampionsIndexDto({
    required this.dataVersion,
    required this.generatedAt,
    required this.defaultSeason,
    required this.pokemon,
  });

  /// Valida [json]; un campo ausente o de otro tipo lanza [ValidationFailure].
  factory ChampionsIndexDto.fromJson(Map<String, dynamic> json) {
    final reader = JsonReader(json, 'index');
    final generatedAt = DateTime.tryParse(reader.string('generatedAt'));
    if (generatedAt == null) {
      throw const ValidationFailure('index.generatedAt: no es una fecha');
    }
    return ChampionsIndexDto(
      dataVersion: reader.string('dataVersion'),
      generatedAt: generatedAt,
      defaultSeason: reader.string('defaultSeason'),
      pokemon: [
        for (final item in reader.objects('pokemon'))
          ChampionsPokemonDto.fromReader(item),
      ],
    );
  }

  final String dataVersion;
  final DateTime generatedAt;
  final String defaultSeason;
  final List<ChampionsPokemonDto> pokemon;
}

/// Un Pokémon del índice.
class ChampionsPokemonDto {
  const ChampionsPokemonDto({
    required this.showdownId,
    required this.name,
    required this.showdownName,
    required this.types,
    required this.abilities,
    required this.hiddenAbility,
    required this.hp,
    required this.attack,
    required this.defense,
    required this.spAttack,
    required this.spDefense,
    required this.speed,
    required this.sprite,
    required this.learnableMoves,
  });

  factory ChampionsPokemonDto.fromReader(JsonReader reader) {
    final summary = reader.object('summary');
    final stats = summary.object('baseStats');
    final primary = summary.object('primary');
    final abilities = primary.string('abilities');
    final hidden = primary.stringOrNull('hidden_ability');
    return ChampionsPokemonDto(
      showdownId: reader.string('showdownId'),
      name: reader.string('name'),
      showdownName: reader.string('showdownName'),
      types: summary.strings('types'),
      abilities: [
        for (final ability in abilities.split('|'))
          if (ability.trim().isNotEmpty) ability.trim(),
      ],
      hiddenAbility: hidden == null || hidden.trim().isEmpty
          ? null
          : hidden.trim(),
      hp: stats.integer('hp'),
      attack: stats.integer('attack'),
      defense: stats.integer('defense'),
      spAttack: stats.integer('sp_attack'),
      spDefense: stats.integer('sp_defense'),
      speed: stats.integer('speed'),
      sprite: summary.string('sprite'),
      learnableMoves: reader.strings('learnableMoveNames'),
    );
  }

  final String showdownId;
  final String name;
  final String showdownName;
  final List<String> types;
  final List<String> abilities;
  final String? hiddenAbility;
  final int hp;
  final int attack;
  final int defense;
  final int spAttack;
  final int spDefense;
  final int speed;

  /// Ruta relativa de la imagen (`pokemon_champions_assets/pokemon/X.png`).
  final String sprite;
  final List<String> learnableMoves;
}

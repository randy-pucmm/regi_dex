import 'json_reader.dart';

/// Datos de referencia de GetReferenceData: tipos, generaciones, grupos huevo,
/// eficacias, version groups, habilidades y movimientos.
class ReferenceDataDto {
  const ReferenceDataDto({
    required this.types,
    required this.generations,
    required this.eggGroups,
    required this.typeEfficacies,
    required this.versionGroups,
    required this.abilities,
    required this.moves,
    required this.totalPokemon,
  });

  /// Valida y convierte el `data` de GetReferenceData. Los nombres en español
  /// salen de la traducción `es`; si falta, quedan en null.
  /// Lanza [ValidationFailure] si falta un campo o tiene otro tipo.
  factory ReferenceDataDto.fromData(Map<String, dynamic> data) {
    final reader = JsonReader(data, 'data');
    return ReferenceDataDto(
      types: [
        for (final type in reader.objects('type'))
          NamedDto(
            id: type.integer('id'),
            name: type.string('name'),
            nameEs: type.localizedName('typenames', 'es'),
          ),
      ],
      generations: [
        for (final generation in reader.objects('generation'))
          GenerationDto(
            id: generation.integer('id'),
            name: generation.string('name'),
            region: _regionName(generation),
          ),
      ],
      eggGroups: [
        for (final group in reader.objects('egggroup'))
          NamedDto(
            id: group.integer('id'),
            name: group.string('name'),
            nameEs: group.localizedName('egggroupnames', 'es'),
          ),
      ],
      typeEfficacies: [
        for (final efficacy in reader.objects('typeefficacy'))
          TypeEfficacyDto(
            attackingTypeId: efficacy.integer('damage_type_id'),
            defendingTypeId: efficacy.integer('target_type_id'),
            factor: efficacy.integer('damage_factor'),
          ),
      ],
      versionGroups: [
        for (final group in reader.objects('versiongroup'))
          VersionGroupDto(
            id: group.integer('id'),
            name: group.string('name'),
            generationId: group.integerOrNull('generation_id'),
          ),
      ],
      abilities: [
        for (final ability in reader.objects('ability'))
          NamedDto(id: ability.integer('id'), name: ability.string('name')),
      ],
      moves: [
        for (final move in reader.objects('move'))
          MoveDto(
            id: move.integer('id'),
            name: move.string('name'),
            typeId: move.integerOrNull('type_id'),
            power: move.integerOrNull('power'),
            accuracy: move.integerOrNull('accuracy'),
            pp: move.integerOrNull('pp'),
            priority: move.integerOrNull('priority') ?? 0,
            damageClassId: move.integerOrNull('move_damage_class_id'),
          ),
      ],
      totalPokemon: reader
          .object('pokemon_aggregate')
          .object('aggregate')
          .integer('count'),
    );
  }

  final List<NamedDto> types;
  final List<GenerationDto> generations;
  final List<NamedDto> eggGroups;
  final List<TypeEfficacyDto> typeEfficacies;
  final List<VersionGroupDto> versionGroups;
  final List<NamedDto> abilities;
  final List<MoveDto> moves;

  /// Total de Pokémon por defecto, para saber si el catálogo local está completo.
  final int totalPokemon;

  static String? _regionName(JsonReader generation) {
    final region = generation.json['region'];
    if (region == null) return null;
    return generation.object('region').string('name');
  }
}

/// Elemento de referencia con nombre en inglés y, si existe, en español.
class NamedDto {
  const NamedDto({required this.id, required this.name, this.nameEs});

  final int id;
  final String name;
  final String? nameEs;
}

class GenerationDto {
  const GenerationDto({required this.id, required this.name, this.region});

  final int id;
  final String name;
  final String? region;
}

class TypeEfficacyDto {
  const TypeEfficacyDto({
    required this.attackingTypeId,
    required this.defendingTypeId,
    required this.factor,
  });

  final int attackingTypeId;
  final int defendingTypeId;

  /// Porcentaje de daño: 0, 50, 100 o 200.
  final int factor;
}

class VersionGroupDto {
  const VersionGroupDto({
    required this.id,
    required this.name,
    this.generationId,
  });

  final int id;
  final String name;
  final int? generationId;
}

class MoveDto {
  const MoveDto({
    required this.id,
    required this.name,
    this.typeId,
    this.power,
    this.accuracy,
    this.pp,
    this.priority = 0,
    this.damageClassId,
  });

  final int id;
  final String name;
  final int? typeId;
  final int? power;
  final int? accuracy;
  final int? pp;
  final int priority;
  final int? damageClassId;
}

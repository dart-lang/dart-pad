// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meta.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Meta _$MetaFromJson(Map json) {
  return $checkedNew('Meta', json, () {
    $checkKeys(json,
        allowedKeys: const ['name', 'type', 'steps'],
        requiredKeys: const ['name', 'steps']);
    final val = Meta(
      $checkedConvert(json, 'name', (v) => v as String?),
      $checkedConvert(
          json,
          'steps',
          (v) => (v as List<dynamic>?)
              ?.map((e) => StepConfiguration.fromJson(e as Map))
              .toList()),
      type: $checkedConvert(json, 'type',
              (v) => _$enumDecodeNullable(_$WorkshopTypeEnumMap, v)) ??
          WorkshopType.dart,
    );
    return val;
  });
}

Map<String, dynamic> _$MetaToJson(Meta instance) => <String, dynamic>{
      'name': instance.name,
      'type': _$WorkshopTypeEnumMap[instance.type],
      'steps': instance.steps,
    };

K _$enumDecode<K, V>(
  Map<K, V> enumValues,
  Object? source, {
  K? unknownValue,
}) {
  if (source == null) {
    throw ArgumentError(
      'A value must be provided. Supported values: '
      '${enumValues.values.join(', ')}',
    );
  }

  return enumValues.entries.singleWhere(
    (e) => e.value == source,
    orElse: () {
      if (unknownValue == null) {
        throw ArgumentError(
          '`$source` is not one of the supported values: '
          '${enumValues.values.join(', ')}',
        );
      }
      return MapEntry(unknownValue, enumValues.values.first);
    },
  ).key;
}

K? _$enumDecodeNullable<K, V>(
  Map<K, V> enumValues,
  dynamic source, {
  K? unknownValue,
}) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<K, V>(enumValues, source, unknownValue: unknownValue);
}

const _$WorkshopTypeEnumMap = {
  WorkshopType.dart: 'dart',
  WorkshopType.flutter: 'flutter',
};

StepConfiguration _$StepConfigurationFromJson(Map json) {
  return $checkedNew('StepConfiguration', json, () {
    $checkKeys(json, allowedKeys: const ['name', 'directory', 'has_solution']);
    final val = StepConfiguration(
      name: $checkedConvert(json, 'name', (v) => v as String),
      directory: $checkedConvert(json, 'directory', (v) => v as String),
      hasSolution: $checkedConvert(json, 'has_solution', (v) => v as bool),
    );
    return val;
  }, fieldKeyMap: const {'hasSolution': 'has_solution'});
}

Map<String, dynamic> _$StepConfigurationToJson(StepConfiguration instance) =>
    <String, dynamic>{
      'name': instance.name,
      'directory': instance.directory,
      'has_solution': instance.hasSolution,
    };

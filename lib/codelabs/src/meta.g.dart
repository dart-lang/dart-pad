// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meta.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Meta _$MetaFromJson(Map json) {
  return $checkedNew('Meta', json, () {
    $checkKeys(json,
        allowedKeys: const ['name', 'steps'], requiredKeys: const ['name']);
    final val = Meta(
      $checkedConvert(json, 'name', (v) => v as String),
      $checkedConvert(
          json,
          'steps',
          (v) => (v as List)
              ?.map((e) =>
                  e == null ? null : StepConfiguration.fromJson(e as Map))
              ?.toList()),
    );
    return val;
  });
}

Map<String, dynamic> _$MetaToJson(Meta instance) => <String, dynamic>{
      'name': instance.name,
      'steps': instance.steps,
    };

StepConfiguration _$StepConfigurationFromJson(Map json) {
  return $checkedNew('StepConfiguration', json, () {
    $checkKeys(json, allowedKeys: const ['name', 'has_solution']);
    final val = StepConfiguration(
      name: $checkedConvert(json, 'name', (v) => v as String),
      hasSolution: $checkedConvert(json, 'has_solution', (v) => v as bool),
    );
    return val;
  }, fieldKeyMap: const {'hasSolution': 'has_solution'});
}

Map<String, dynamic> _$StepConfigurationToJson(StepConfiguration instance) =>
    <String, dynamic>{
      'name': instance.name,
      'has_solution': instance.hasSolution,
    };

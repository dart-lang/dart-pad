import 'package:json_annotation/json_annotation.dart';

import 'workshop.dart';

part 'meta.g.dart';

@JsonSerializable(
  anyMap: true,
  checked: true,
  disallowUnrecognizedKeys: true,
  fieldRename: FieldRename.snake,
)
class Meta {
  final String name;

  final WorkshopType type;

  final List<StepConfiguration> steps;

  Meta(this.name, this.steps, {this.type = WorkshopType.dart});

  factory Meta.fromJson(Map json) => _$MetaFromJson(json);

  Map<String, dynamic> toJson() => _$MetaToJson(this);

  @override
  String toString() => '<Meta> name: $name steps: $steps';
}

@JsonSerializable(
  anyMap: true,
  checked: true,
  disallowUnrecognizedKeys: true,
  fieldRename: FieldRename.snake,
)
class StepConfiguration {
  final String name;
  final String directory;
  final bool hasSolution;

  StepConfiguration({
    required this.name,
    required this.directory,
    this.hasSolution = false,
  });

  factory StepConfiguration.fromJson(Map json) =>
      _$StepConfigurationFromJson(json);

  Map<String, dynamic> toJson() => _$StepConfigurationToJson(this);

  @override
  String toString() =>
      '<StepConfiguration> name: $name has_solution: $hasSolution';
}

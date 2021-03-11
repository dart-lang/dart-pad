import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'meta.g.dart';

@JsonSerializable(
  anyMap: true,
  checked: true,
  disallowUnrecognizedKeys: true,
  fieldRename: FieldRename.snake,
)
class Meta {
  @JsonKey(required: true)
  final String name;
  final List<StepConfiguration> steps;

  Meta(this.name, this.steps);

  factory Meta.fromJson(Map json) => _$MetaFromJson(json);

  Map<String, dynamic> toJson() => _$MetaToJson(this);

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
  final bool hasSolution;

  StepConfiguration({
    @required this.name,
    this.hasSolution = false,
  });

  factory StepConfiguration.fromJson(Map json) =>
      _$StepConfigurationFromJson(json);

  Map<String, dynamic> toJson() => _$StepConfigurationToJson(this);

  String toString() =>
      '<StepConfiguration> name: $name has_solution: $hasSolution';
}

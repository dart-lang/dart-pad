import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'codelab.dart';

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

  @JsonKey(
    required: false,
    defaultValue: CodelabType.dart,
  )
  final CodelabType type;

  @JsonKey(required: true)
  final List<StepConfiguration> steps;

  Meta(this.name, this.steps, {this.type});

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
    @required this.name,
    @required this.directory,
    this.hasSolution = false,
  });

  factory StepConfiguration.fromJson(Map json) =>
      _$StepConfigurationFromJson(json);

  Map<String, dynamic> toJson() => _$StepConfigurationToJson(this);

  @override
  String toString() =>
      '<StepConfiguration> name: $name has_solution: $hasSolution';
}

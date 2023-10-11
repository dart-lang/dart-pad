// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';

part 'model.g.dart';

@JsonSerializable()
class SourceRequest {
  final String source;
  final int? offset;

  SourceRequest({required this.source, this.offset});

  factory SourceRequest.fromJson(Map<String, dynamic> json) =>
      _$SourceRequestFromJson(json);

  Map<String, dynamic> toJson() => _$SourceRequestToJson(this);

  @override
  String toString() => 'SourceRequest[source=$source,offset=$offset]';
}

@JsonSerializable()
class AnalysisResponse {
  final List<AnalysisIssue> issues;

  AnalysisResponse({this.issues = const []});

  factory AnalysisResponse.fromJson(Map<String, dynamic> json) =>
      _$AnalysisResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AnalysisResponseToJson(this);
}

@JsonSerializable()
class AnalysisIssue {
  final String kind;
  final String message;
  final String? correction;
  final int charStart;
  final int charLength;
  final int line;
  final int column;

  AnalysisIssue({
    required this.kind,
    required this.message,
    this.correction,
    this.charStart = -1,
    this.charLength = 0,
    this.line = -1,
    this.column = -1,
  });

  factory AnalysisIssue.fromJson(Map<String, dynamic> json) =>
      _$AnalysisIssueFromJson(json);

  Map<String, dynamic> toJson() => _$AnalysisIssueToJson(this);

  @override
  String toString() => '[$kind] $message';
}

@JsonSerializable()
class CompileRequest {
  final String source;

  CompileRequest({required this.source});

  factory CompileRequest.fromJson(Map<String, dynamic> json) =>
      _$CompileRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CompileRequestToJson(this);
}

@JsonSerializable()
class CompileResponse {
  final String result;

  CompileResponse({required this.result});

  factory CompileResponse.fromJson(Map<String, dynamic> json) =>
      _$CompileResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CompileResponseToJson(this);
}

@JsonSerializable()
class FormatResponse {
  final String source;
  final int? offset;

  FormatResponse({
    required this.source,
    required this.offset,
  });

  factory FormatResponse.fromJson(Map<String, dynamic> json) =>
      _$FormatResponseFromJson(json);

  Map<String, dynamic> toJson() => _$FormatResponseToJson(this);

  @override
  String toString() => 'FormatResponse[source=$source,offset=$offset]';
}

@JsonSerializable()
class FlutterBuildResponse {
  final Map<String, String> artifacts;

  FlutterBuildResponse({required this.artifacts});

  factory FlutterBuildResponse.fromJson(Map<String, dynamic> json) =>
      _$FlutterBuildResponseFromJson(json);

  Map<String, dynamic> toJson() => _$FlutterBuildResponseToJson(this);
}

@JsonSerializable()
class CompleteResponse {
  final int replacementOffset;
  final int replacementLength;
  final List<CompletionSuggestion> suggestions;

  CompleteResponse({
    required this.replacementOffset,
    required this.replacementLength,
    required this.suggestions,
  });

  factory CompleteResponse.fromJson(Map<String, dynamic> json) =>
      _$CompleteResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CompleteResponseToJson(this);
}

@JsonSerializable()
class CompletionSuggestion {
  final String kind;
  final int relevance;
  final String completion;
  final bool deprecated;
  final String? displayText;
  final String? returnType;
  final String? elementKind;

  CompletionSuggestion({
    required this.kind,
    required this.relevance,
    required this.completion,
    required this.deprecated,
    required this.displayText,
    required this.returnType,
    required this.elementKind,
  });

  factory CompletionSuggestion.fromJson(Map<String, dynamic> json) =>
      _$CompletionSuggestionFromJson(json);

  Map<String, dynamic> toJson() => _$CompletionSuggestionToJson(this);

  @override
  String toString() => '[$relevance] [$kind] $completion';
}

@JsonSerializable()
class VersionResponse {
  final String dartVersion;
  final String flutterVersion;
  final List<String> experiments;
  final List<PackageInfo> packages;

  VersionResponse({
    required this.dartVersion,
    required this.flutterVersion,
    required this.experiments,
    required this.packages,
  });

  factory VersionResponse.fromJson(Map<String, dynamic> json) =>
      _$VersionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$VersionResponseToJson(this);
}

@JsonSerializable()
class PackageInfo {
  final String name;
  final String version;
  final bool supported;

  PackageInfo({
    required this.name,
    required this.version,
    required this.supported,
  });

  factory PackageInfo.fromJson(Map<String, dynamic> json) =>
      _$PackageInfoFromJson(json);

  Map<String, dynamic> toJson() => _$PackageInfoToJson(this);
}

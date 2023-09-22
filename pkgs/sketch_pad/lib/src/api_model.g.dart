// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SourceRequest _$SourceRequestFromJson(Map<String, dynamic> json) =>
    SourceRequest(
      source: json['source'] as String,
      offset: json['offset'] as int?,
    );

Map<String, dynamic> _$SourceRequestToJson(SourceRequest instance) =>
    <String, dynamic>{
      'source': instance.source,
      'offset': instance.offset,
    };

AnalysisResponse _$AnalysisResponseFromJson(Map<String, dynamic> json) =>
    AnalysisResponse(
      issues: (json['issues'] as List<dynamic>?)
              ?.map((e) => AnalysisIssue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$AnalysisResponseToJson(AnalysisResponse instance) =>
    <String, dynamic>{
      'issues': instance.issues,
    };

AnalysisIssue _$AnalysisIssueFromJson(Map<String, dynamic> json) =>
    AnalysisIssue(
      kind: json['kind'] as String,
      message: json['message'] as String,
      correction: json['correction'] as String?,
      charStart: json['charStart'] as int? ?? -1,
      charLength: json['charLength'] as int? ?? 0,
      line: json['line'] as int? ?? -1,
      column: json['column'] as int? ?? -1,
    );

Map<String, dynamic> _$AnalysisIssueToJson(AnalysisIssue instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'message': instance.message,
      'correction': instance.correction,
      'charStart': instance.charStart,
      'charLength': instance.charLength,
      'line': instance.line,
      'column': instance.column,
    };

CompileRequest _$CompileRequestFromJson(Map<String, dynamic> json) =>
    CompileRequest(
      source: json['source'] as String,
    );

Map<String, dynamic> _$CompileRequestToJson(CompileRequest instance) =>
    <String, dynamic>{
      'source': instance.source,
    };

CompileResponse _$CompileResponseFromJson(Map<String, dynamic> json) =>
    CompileResponse(
      result: json['result'] as String,
    );

Map<String, dynamic> _$CompileResponseToJson(CompileResponse instance) =>
    <String, dynamic>{
      'result': instance.result,
    };

FormatResponse _$FormatResponseFromJson(Map<String, dynamic> json) =>
    FormatResponse(
      newString: json['newString'] as String,
      offset: json['offset'] as int?,
    );

Map<String, dynamic> _$FormatResponseToJson(FormatResponse instance) =>
    <String, dynamic>{
      'newString': instance.newString,
      'offset': instance.offset,
    };

FlutterBuildResponse _$FlutterBuildResponseFromJson(
        Map<String, dynamic> json) =>
    FlutterBuildResponse(
      artifacts: Map<String, String>.from(json['artifacts'] as Map),
    );

Map<String, dynamic> _$FlutterBuildResponseToJson(
        FlutterBuildResponse instance) =>
    <String, dynamic>{
      'artifacts': instance.artifacts,
    };

CompleteResponse _$CompleteResponseFromJson(Map<String, dynamic> json) =>
    CompleteResponse(
      replacementOffset: json['replacementOffset'] as int,
      replacementLength: json['replacementLength'] as int,
      suggestions: (json['suggestions'] as List<dynamic>)
          .map((e) => CompletionSuggestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CompleteResponseToJson(CompleteResponse instance) =>
    <String, dynamic>{
      'replacementOffset': instance.replacementOffset,
      'replacementLength': instance.replacementLength,
      'suggestions': instance.suggestions,
    };

CompletionSuggestion _$CompletionSuggestionFromJson(
        Map<String, dynamic> json) =>
    CompletionSuggestion(
      kind: json['kind'] as String,
      relevance: json['relevance'] as int,
      completion: json['completion'] as String,
      selectionOffset: json['selectionOffset'] as int,
      deprecated: json['deprecated'] as bool,
      displayText: json['displayText'] as String?,
      parameterNames: (json['parameterNames'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      element: json['element'] == null
          ? null
          : CompletionElement.fromJson(json['element'] as Map<String, dynamic>),
      returnType: json['returnType'] as String?,
    );

Map<String, dynamic> _$CompletionSuggestionToJson(
        CompletionSuggestion instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'relevance': instance.relevance,
      'completion': instance.completion,
      'selectionOffset': instance.selectionOffset,
      'deprecated': instance.deprecated,
      'displayText': instance.displayText,
      'parameterNames': instance.parameterNames,
      'element': instance.element,
      'returnType': instance.returnType,
    };

CompletionElement _$CompletionElementFromJson(Map<String, dynamic> json) =>
    CompletionElement(
      kind: json['kind'] as String,
      parameters: json['parameters'] as String?,
    );

Map<String, dynamic> _$CompletionElementToJson(CompletionElement instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'parameters': instance.parameters,
    };

VersionResponse _$VersionResponseFromJson(Map<String, dynamic> json) =>
    VersionResponse(
      dartVersion: json['dartVersion'] as String,
      flutterVersion: json['flutterVersion'] as String,
      experiments: (json['experiments'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      packages: (json['packages'] as List<dynamic>)
          .map((e) => PackageInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$VersionResponseToJson(VersionResponse instance) =>
    <String, dynamic>{
      'dartVersion': instance.dartVersion,
      'flutterVersion': instance.flutterVersion,
      'experiments': instance.experiments,
      'packages': instance.packages,
    };

PackageInfo _$PackageInfoFromJson(Map<String, dynamic> json) => PackageInfo(
      name: json['name'] as String,
      version: json['version'] as String,
      supported: json['supported'] as bool,
    );

Map<String, dynamic> _$PackageInfoToJson(PackageInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'version': instance.version,
      'supported': instance.supported,
    };

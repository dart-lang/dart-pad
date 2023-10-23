// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

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
      issues: (json['issues'] as List<dynamic>)
          .map((e) => AnalysisIssue.fromJson(e as Map<String, dynamic>))
          .toList(),
      packageImports: (json['packageImports'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$AnalysisResponseToJson(AnalysisResponse instance) =>
    <String, dynamic>{
      'issues': instance.issues,
      'packageImports': instance.packageImports,
    };

AnalysisIssue _$AnalysisIssueFromJson(Map<String, dynamic> json) =>
    AnalysisIssue(
      kind: json['kind'] as String,
      message: json['message'] as String,
      correction: json['correction'] as String?,
      url: json['url'] as String?,
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
      'url': instance.url,
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

CompileDDCResponse _$CompileDDCResponseFromJson(Map<String, dynamic> json) =>
    CompileDDCResponse(
      result: json['result'] as String,
      modulesBaseUrl: json['modulesBaseUrl'] as String,
    );

Map<String, dynamic> _$CompileDDCResponseToJson(CompileDDCResponse instance) =>
    <String, dynamic>{
      'result': instance.result,
      'modulesBaseUrl': instance.modulesBaseUrl,
    };

FormatResponse _$FormatResponseFromJson(Map<String, dynamic> json) =>
    FormatResponse(
      source: json['source'] as String,
      offset: json['offset'] as int?,
    );

Map<String, dynamic> _$FormatResponseToJson(FormatResponse instance) =>
    <String, dynamic>{
      'source': instance.source,
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

FixesResponse _$FixesResponseFromJson(Map<String, dynamic> json) =>
    FixesResponse(
      fixes: (json['fixes'] as List<dynamic>)
          .map((e) => SourceChange.fromJson(e as Map<String, dynamic>))
          .toList(),
      assists: (json['assists'] as List<dynamic>)
          .map((e) => SourceChange.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$FixesResponseToJson(FixesResponse instance) =>
    <String, dynamic>{
      'fixes': instance.fixes,
      'assists': instance.assists,
    };

SourceChange _$SourceChangeFromJson(Map<String, dynamic> json) => SourceChange(
      message: json['message'] as String,
      edits: (json['edits'] as List<dynamic>)
          .map((e) => SourceEdit.fromJson(e as Map<String, dynamic>))
          .toList(),
      linkedEditGroups: (json['linkedEditGroups'] as List<dynamic>)
          .map((e) => LinkedEditGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
      selectionOffset: json['selectionOffset'] as int?,
    );

Map<String, dynamic> _$SourceChangeToJson(SourceChange instance) =>
    <String, dynamic>{
      'message': instance.message,
      'edits': instance.edits,
      'linkedEditGroups': instance.linkedEditGroups,
      'selectionOffset': instance.selectionOffset,
    };

SourceEdit _$SourceEditFromJson(Map<String, dynamic> json) => SourceEdit(
      offset: json['offset'] as int,
      length: json['length'] as int,
      replacement: json['replacement'] as String,
    );

Map<String, dynamic> _$SourceEditToJson(SourceEdit instance) =>
    <String, dynamic>{
      'offset': instance.offset,
      'length': instance.length,
      'replacement': instance.replacement,
    };

LinkedEditGroup _$LinkedEditGroupFromJson(Map<String, dynamic> json) =>
    LinkedEditGroup(
      offsets: (json['offsets'] as List<dynamic>).map((e) => e as int).toList(),
      length: json['length'] as int,
      suggestions: (json['suggestions'] as List<dynamic>)
          .map((e) => LinkedEditSuggestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$LinkedEditGroupToJson(LinkedEditGroup instance) =>
    <String, dynamic>{
      'offsets': instance.offsets,
      'length': instance.length,
      'suggestions': instance.suggestions,
    };

LinkedEditSuggestion _$LinkedEditSuggestionFromJson(
        Map<String, dynamic> json) =>
    LinkedEditSuggestion(
      value: json['value'] as String,
      kind: json['kind'] as String,
    );

Map<String, dynamic> _$LinkedEditSuggestionToJson(
        LinkedEditSuggestion instance) =>
    <String, dynamic>{
      'value': instance.value,
      'kind': instance.kind,
    };

DocumentResponse _$DocumentResponseFromJson(Map<String, dynamic> json) =>
    DocumentResponse(
      dartdoc: json['dartdoc'] as String?,
      elementKind: json['elementKind'] as String?,
      elementDescription: json['elementDescription'] as String?,
      containingLibraryName: json['containingLibraryName'] as String?,
      deprecated: json['deprecated'] as bool?,
      propagatedType: json['propagatedType'] as String?,
    );

Map<String, dynamic> _$DocumentResponseToJson(DocumentResponse instance) =>
    <String, dynamic>{
      'dartdoc': instance.dartdoc,
      'elementKind': instance.elementKind,
      'elementDescription': instance.elementDescription,
      'containingLibraryName': instance.containingLibraryName,
      'deprecated': instance.deprecated,
      'propagatedType': instance.propagatedType,
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
      deprecated: json['deprecated'] as bool,
      selectionOffset: json['selectionOffset'] as int,
      displayText: json['displayText'] as String?,
      parameterNames: (json['parameterNames'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      returnType: json['returnType'] as String?,
      elementKind: json['elementKind'] as String?,
      elementParameters: json['elementParameters'] as String?,
    );

Map<String, dynamic> _$CompletionSuggestionToJson(
        CompletionSuggestion instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'relevance': instance.relevance,
      'completion': instance.completion,
      'deprecated': instance.deprecated,
      'selectionOffset': instance.selectionOffset,
      'displayText': instance.displayText,
      'parameterNames': instance.parameterNames,
      'returnType': instance.returnType,
      'elementKind': instance.elementKind,
      'elementParameters': instance.elementParameters,
    };

VersionResponse _$VersionResponseFromJson(Map<String, dynamic> json) =>
    VersionResponse(
      dartVersion: json['dartVersion'] as String,
      flutterVersion: json['flutterVersion'] as String,
      engineVersion: json['engineVersion'] as String,
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
      'engineVersion': instance.engineVersion,
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

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SourceRequest _$SourceRequestFromJson(Map<String, dynamic> json) =>
    SourceRequest(
      source: json['source'] as String,
      offset: (json['offset'] as num?)?.toInt(),
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
    );

Map<String, dynamic> _$AnalysisResponseToJson(AnalysisResponse instance) =>
    <String, dynamic>{
      'issues': instance.issues,
    };

AnalysisIssue _$AnalysisIssueFromJson(Map<String, dynamic> json) =>
    AnalysisIssue(
      kind: json['kind'] as String,
      message: json['message'] as String,
      location: Location.fromJson(json['location'] as Map<String, dynamic>),
      code: json['code'] as String?,
      correction: json['correction'] as String?,
      url: json['url'] as String?,
      contextMessages: (json['contextMessages'] as List<dynamic>?)
          ?.map((e) => DiagnosticMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AnalysisIssueToJson(AnalysisIssue instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'message': instance.message,
      'location': instance.location,
      'code': instance.code,
      'correction': instance.correction,
      'url': instance.url,
      'contextMessages': instance.contextMessages,
    };

Location _$LocationFromJson(Map<String, dynamic> json) => Location(
      charStart: (json['charStart'] as num?)?.toInt() ?? -1,
      charLength: (json['charLength'] as num?)?.toInt() ?? 0,
      line: (json['line'] as num?)?.toInt() ?? -1,
      column: (json['column'] as num?)?.toInt() ?? -1,
    );

Map<String, dynamic> _$LocationToJson(Location instance) => <String, dynamic>{
      'charStart': instance.charStart,
      'charLength': instance.charLength,
      'line': instance.line,
      'column': instance.column,
    };

DiagnosticMessage _$DiagnosticMessageFromJson(Map<String, dynamic> json) =>
    DiagnosticMessage(
      message: json['message'] as String,
      location: Location.fromJson(json['location'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DiagnosticMessageToJson(DiagnosticMessage instance) =>
    <String, dynamic>{
      'message': instance.message,
      'location': instance.location,
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
      modulesBaseUrl: json['modulesBaseUrl'] as String?,
    );

Map<String, dynamic> _$CompileDDCResponseToJson(CompileDDCResponse instance) =>
    <String, dynamic>{
      'result': instance.result,
      'modulesBaseUrl': instance.modulesBaseUrl,
    };

FormatResponse _$FormatResponseFromJson(Map<String, dynamic> json) =>
    FormatResponse(
      source: json['source'] as String,
      offset: (json['offset'] as num?)?.toInt(),
    );

Map<String, dynamic> _$FormatResponseToJson(FormatResponse instance) =>
    <String, dynamic>{
      'source': instance.source,
      'offset': instance.offset,
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
      selectionOffset: (json['selectionOffset'] as num?)?.toInt(),
    );

Map<String, dynamic> _$SourceChangeToJson(SourceChange instance) =>
    <String, dynamic>{
      'message': instance.message,
      'edits': instance.edits,
      'linkedEditGroups': instance.linkedEditGroups,
      'selectionOffset': instance.selectionOffset,
    };

SourceEdit _$SourceEditFromJson(Map<String, dynamic> json) => SourceEdit(
      offset: (json['offset'] as num).toInt(),
      length: (json['length'] as num).toInt(),
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
      offsets: (json['offsets'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      length: (json['length'] as num).toInt(),
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
      replacementOffset: (json['replacementOffset'] as num).toInt(),
      replacementLength: (json['replacementLength'] as num).toInt(),
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
      relevance: (json['relevance'] as num).toInt(),
      completion: json['completion'] as String,
      deprecated: json['deprecated'] as bool,
      selectionOffset: (json['selectionOffset'] as num).toInt(),
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
      serverRevision: json['serverRevision'] as String?,
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
      'serverRevision': instance.serverRevision,
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

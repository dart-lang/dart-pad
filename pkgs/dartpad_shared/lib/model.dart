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

  factory SourceRequest.fromJson(Map<String, Object?> json) =>
      _$SourceRequestFromJson(json);

  Map<String, Object?> toJson() => _$SourceRequestToJson(this);

  @override
  String toString() => 'SourceRequest[source=$source,offset=$offset]';
}

@JsonSerializable()
class AnalysisResponse {
  final List<AnalysisIssue> issues;

  AnalysisResponse({
    required this.issues,
  });

  factory AnalysisResponse.fromJson(Map<String, Object?> json) =>
      _$AnalysisResponseFromJson(json);

  Map<String, Object?> toJson() => _$AnalysisResponseToJson(this);
}

@JsonSerializable()
class AnalysisIssue {
  final String kind;
  final String message;
  final Location location;
  final String? code;
  final String? correction;
  final String? url;
  final List<DiagnosticMessage>? contextMessages;

  /// A hint to indicate to interested clients that this error has an associated
  /// fix (or fixes). The absence of this field implies there are not known to
  /// be fixes.
  final bool? hasFix;

  AnalysisIssue({
    required this.kind,
    required this.message,
    required this.location,
    this.code,
    this.correction,
    this.url,
    this.contextMessages,
    this.hasFix,
  });

  factory AnalysisIssue.fromJson(Map<String, Object?> json) =>
      _$AnalysisIssueFromJson(json);

  Map<String, Object?> toJson() => _$AnalysisIssueToJson(this);

  int get severity {
    return switch (kind) {
      'error' => 3,
      'warning' => 2,
      'info' => 1,
      _ => 0,
    };
  }

  @override
  String toString() => '[$kind] $message';
}

@JsonSerializable()
class Location {
  final int charStart;
  final int charLength;
  final int line;
  final int column;

  Location({
    this.charStart = -1,
    this.charLength = 0,
    this.line = -1,
    this.column = -1,
  });

  factory Location.fromJson(Map<String, Object?> json) =>
      _$LocationFromJson(json);

  Map<String, Object?> toJson() => _$LocationToJson(this);
}

@JsonSerializable()
class DiagnosticMessage {
  final String message;
  final Location location;

  DiagnosticMessage({
    required this.message,
    required this.location,
  });

  factory DiagnosticMessage.fromJson(Map<String, Object?> json) =>
      _$DiagnosticMessageFromJson(json);

  Map<String, Object?> toJson() => _$DiagnosticMessageToJson(this);
}

@JsonSerializable()
class CompileRequest {
  final String source;
  final String? deltaDill;

  CompileRequest({required this.source, this.deltaDill});

  factory CompileRequest.fromJson(Map<String, Object?> json) =>
      _$CompileRequestFromJson(json);

  Map<String, Object?> toJson() => _$CompileRequestToJson(this);
}

@JsonSerializable()
class CompileResponse {
  final String result;

  CompileResponse({required this.result});

  factory CompileResponse.fromJson(Map<String, Object?> json) =>
      _$CompileResponseFromJson(json);

  Map<String, Object?> toJson() => _$CompileResponseToJson(this);
}

@JsonSerializable()
class CompileDDCResponse {
  final String result;
  final String? deltaDill;
  final String? modulesBaseUrl;

  CompileDDCResponse({
    required this.result,
    required this.deltaDill,
    required this.modulesBaseUrl,
  });

  factory CompileDDCResponse.fromJson(Map<String, Object?> json) =>
      _$CompileDDCResponseFromJson(json);

  Map<String, Object?> toJson() => _$CompileDDCResponseToJson(this);
}

@JsonSerializable()
class FormatResponse {
  final String source;
  final int? offset;

  FormatResponse({
    required this.source,
    required this.offset,
  });

  factory FormatResponse.fromJson(Map<String, Object?> json) =>
      _$FormatResponseFromJson(json);

  Map<String, Object?> toJson() => _$FormatResponseToJson(this);

  @override
  String toString() => 'FormatResponse[source=$source,offset=$offset]';
}

@JsonSerializable()
class FixesResponse {
  static final FixesResponse empty = FixesResponse(
    fixes: [],
    assists: [],
  );

  final List<SourceChange> fixes;
  final List<SourceChange> assists;

  FixesResponse({
    required this.fixes,
    required this.assists,
  });

  factory FixesResponse.fromJson(Map<String, Object?> json) =>
      _$FixesResponseFromJson(json);

  Map<String, Object?> toJson() => _$FixesResponseToJson(this);
}

@JsonSerializable()
class SourceChange {
  final String message;
  final List<SourceEdit> edits;
  final List<LinkedEditGroup> linkedEditGroups;
  final int? selectionOffset;

  SourceChange({
    required this.message,
    required this.edits,
    required this.linkedEditGroups,
    this.selectionOffset,
  });

  factory SourceChange.fromJson(Map<String, Object?> json) =>
      _$SourceChangeFromJson(json);

  Map<String, Object?> toJson() => _$SourceChangeToJson(this);

  @override
  String toString() => 'SourceChange [$message]';
}

@JsonSerializable()
class SourceEdit {
  final int offset;
  final int length;
  final String replacement;

  SourceEdit({
    required this.offset,
    required this.length,
    required this.replacement,
  });

  factory SourceEdit.fromJson(Map<String, Object?> json) =>
      _$SourceEditFromJson(json);

  Map<String, Object?> toJson() => _$SourceEditToJson(this);

  @override
  String toString() => 'SourceEdit [$offset,$length,$replacement]';
}

@JsonSerializable()
class LinkedEditGroup {
  final List<int> offsets;
  final int length;
  final List<LinkedEditSuggestion> suggestions;

  LinkedEditGroup({
    required this.offsets,
    required this.length,
    required this.suggestions,
  });

  factory LinkedEditGroup.fromJson(Map<String, Object?> json) =>
      _$LinkedEditGroupFromJson(json);

  Map<String, Object?> toJson() => _$LinkedEditGroupToJson(this);
}

@JsonSerializable()
class LinkedEditSuggestion {
  final String value;
  final String kind;

  LinkedEditSuggestion({
    required this.value,
    required this.kind,
  });

  factory LinkedEditSuggestion.fromJson(Map<String, Object?> json) =>
      _$LinkedEditSuggestionFromJson(json);

  Map<String, Object?> toJson() => _$LinkedEditSuggestionToJson(this);
}

@JsonSerializable()
class DocumentResponse {
  final String? dartdoc;
  final String? elementKind;
  final String? elementDescription;
  final String? containingLibraryName;
  final bool? deprecated;
  final String? propagatedType;

  DocumentResponse({
    this.dartdoc,
    this.elementKind,
    this.elementDescription,
    this.containingLibraryName,
    this.deprecated,
    this.propagatedType,
  });

  factory DocumentResponse.fromJson(Map<String, Object?> json) =>
      _$DocumentResponseFromJson(json);

  Map<String, Object?> toJson() => _$DocumentResponseToJson(this);
}

@JsonSerializable()
class CompleteResponse {
  static final CompleteResponse empty = CompleteResponse(
    replacementLength: 0,
    replacementOffset: 0,
    suggestions: [],
  );

  final int replacementOffset;
  final int replacementLength;
  final List<CompletionSuggestion> suggestions;

  CompleteResponse({
    required this.replacementOffset,
    required this.replacementLength,
    required this.suggestions,
  });

  factory CompleteResponse.fromJson(Map<String, Object?> json) =>
      _$CompleteResponseFromJson(json);

  Map<String, Object?> toJson() => _$CompleteResponseToJson(this);
}

@JsonSerializable()
class CompletionSuggestion {
  final String kind;
  final int relevance;
  final String completion;
  final bool deprecated;
  final int selectionOffset;
  final String? displayText;
  final List<String>? parameterNames;
  final String? returnType;
  final String? elementKind;
  final String? elementParameters;

  CompletionSuggestion({
    required this.kind,
    required this.relevance,
    required this.completion,
    required this.deprecated,
    required this.selectionOffset,
    required this.displayText,
    required this.parameterNames,
    required this.returnType,
    required this.elementKind,
    required this.elementParameters,
  });

  factory CompletionSuggestion.fromJson(Map<String, Object?> json) =>
      _$CompletionSuggestionFromJson(json);

  Map<String, Object?> toJson() => _$CompletionSuggestionToJson(this);

  @override
  String toString() => '[$relevance] [$kind] $completion';
}

@JsonSerializable()
class VersionResponse {
  final String dartVersion;
  final String flutterVersion;
  final String engineVersion;
  final String? serverRevision;
  final List<String> experiments;
  final List<PackageInfo> packages;

  VersionResponse({
    required this.dartVersion,
    required this.flutterVersion,
    required this.engineVersion,
    this.serverRevision,
    required this.experiments,
    required this.packages,
  });

  factory VersionResponse.fromJson(Map<String, Object?> json) =>
      _$VersionResponseFromJson(json);

  Map<String, Object?> toJson() => _$VersionResponseToJson(this);
}

@JsonSerializable()
class OpenInIdxRequest {
  final String code;

  OpenInIdxRequest({
    required this.code,
  });

  factory OpenInIdxRequest.fromJson(Map<String, Object?> json) =>
      _$OpenInIdxRequestFromJson(json);

  Map<String, Object?> toJson() => _$OpenInIdxRequestToJson(this);

  @override
  String toString() => 'OpenInIdxRequest [${code.substring(0, 10)} (...)';
}

@JsonSerializable()
class OpenInIdxResponse {
  final String idxUrl;

  OpenInIdxResponse({
    required this.idxUrl,
  });

  factory OpenInIdxResponse.fromJson(Map<String, Object?> json) =>
      _$OpenInIdxResponseFromJson(json);

  Map<String, Object?> toJson() => _$OpenInIdxResponseToJson(this);

  @override
  String toString() => 'OpenInIdxResponse [$idxUrl]';
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

  factory PackageInfo.fromJson(Map<String, Object?> json) =>
      _$PackageInfoFromJson(json);

  Map<String, Object?> toJson() => _$PackageInfoToJson(this);
}

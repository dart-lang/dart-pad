///
//  Generated code. Do not modify.
//  source: protos/dart_services.proto
//
// @dart = 2.3
// ignore_for_file: camel_case_types,non_constant_identifier_names,library_prefixes,unused_import,unused_shown_name,return_of_invalid_type

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class CompileRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('CompileRequest', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..aOS(1, 'source')
    ..aOB(2, 'returnSourceMap', protoName: 'returnSourceMap')
    ..hasRequiredFields = false
  ;

  CompileRequest._() : super();
  factory CompileRequest() => create();
  factory CompileRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CompileRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  CompileRequest clone() => CompileRequest()..mergeFromMessage(this);
  CompileRequest copyWith(void Function(CompileRequest) updates) => super.copyWith((message) => updates(message as CompileRequest));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static CompileRequest create() => CompileRequest._();
  CompileRequest createEmptyInstance() => create();
  static $pb.PbList<CompileRequest> createRepeated() => $pb.PbList<CompileRequest>();
  @$core.pragma('dart2js:noInline')
  static CompileRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CompileRequest>(create);
  static CompileRequest _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get source => $_getSZ(0);
  @$pb.TagNumber(1)
  set source($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSource() => $_has(0);
  @$pb.TagNumber(1)
  void clearSource() => clearField(1);

  @$pb.TagNumber(2)
  $core.bool get returnSourceMap => $_getBF(1);
  @$pb.TagNumber(2)
  set returnSourceMap($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasReturnSourceMap() => $_has(1);
  @$pb.TagNumber(2)
  void clearReturnSourceMap() => clearField(2);
}

class SourceRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('SourceRequest', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..aOS(1, 'source')
    ..a<$core.int>(2, 'offset', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  SourceRequest._() : super();
  factory SourceRequest() => create();
  factory SourceRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SourceRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  SourceRequest clone() => SourceRequest()..mergeFromMessage(this);
  SourceRequest copyWith(void Function(SourceRequest) updates) => super.copyWith((message) => updates(message as SourceRequest));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static SourceRequest create() => SourceRequest._();
  SourceRequest createEmptyInstance() => create();
  static $pb.PbList<SourceRequest> createRepeated() => $pb.PbList<SourceRequest>();
  @$core.pragma('dart2js:noInline')
  static SourceRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SourceRequest>(create);
  static SourceRequest _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get source => $_getSZ(0);
  @$pb.TagNumber(1)
  set source($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSource() => $_has(0);
  @$pb.TagNumber(1)
  void clearSource() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get offset => $_getIZ(1);
  @$pb.TagNumber(2)
  set offset($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasOffset() => $_has(1);
  @$pb.TagNumber(2)
  void clearOffset() => clearField(2);
}

class AnalysisResults extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('AnalysisResults', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..pc<AnalysisIssue>(1, 'issues', $pb.PbFieldType.PM, subBuilder: AnalysisIssue.create)
    ..pPS(2, 'packageImports', protoName: 'packageImports')
    ..aOM<ErrorMessage>(99, 'error', subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false
  ;

  AnalysisResults._() : super();
  factory AnalysisResults() => create();
  factory AnalysisResults.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AnalysisResults.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  AnalysisResults clone() => AnalysisResults()..mergeFromMessage(this);
  AnalysisResults copyWith(void Function(AnalysisResults) updates) => super.copyWith((message) => updates(message as AnalysisResults));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static AnalysisResults create() => AnalysisResults._();
  AnalysisResults createEmptyInstance() => create();
  static $pb.PbList<AnalysisResults> createRepeated() => $pb.PbList<AnalysisResults>();
  @$core.pragma('dart2js:noInline')
  static AnalysisResults getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AnalysisResults>(create);
  static AnalysisResults _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<AnalysisIssue> get issues => $_getList(0);

  @$pb.TagNumber(2)
  $core.List<$core.String> get packageImports => $_getList(1);

  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(2);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) { setField(99, v); }
  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(2);
}

class AnalysisIssue extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('AnalysisIssue', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..aOS(1, 'kind')
    ..a<$core.int>(2, 'line', $pb.PbFieldType.O3)
    ..aOS(3, 'message')
    ..aOS(4, 'sourceName', protoName: 'sourceName')
    ..aOB(5, 'hasFixes', protoName: 'hasFixes')
    ..a<$core.int>(6, 'charStart', $pb.PbFieldType.O3, protoName: 'charStart')
    ..a<$core.int>(7, 'charLength', $pb.PbFieldType.O3, protoName: 'charLength')
    ..hasRequiredFields = false
  ;

  AnalysisIssue._() : super();
  factory AnalysisIssue() => create();
  factory AnalysisIssue.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AnalysisIssue.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  AnalysisIssue clone() => AnalysisIssue()..mergeFromMessage(this);
  AnalysisIssue copyWith(void Function(AnalysisIssue) updates) => super.copyWith((message) => updates(message as AnalysisIssue));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static AnalysisIssue create() => AnalysisIssue._();
  AnalysisIssue createEmptyInstance() => create();
  static $pb.PbList<AnalysisIssue> createRepeated() => $pb.PbList<AnalysisIssue>();
  @$core.pragma('dart2js:noInline')
  static AnalysisIssue getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AnalysisIssue>(create);
  static AnalysisIssue _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get kind => $_getSZ(0);
  @$pb.TagNumber(1)
  set kind($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get line => $_getIZ(1);
  @$pb.TagNumber(2)
  set line($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasLine() => $_has(1);
  @$pb.TagNumber(2)
  void clearLine() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get message => $_getSZ(2);
  @$pb.TagNumber(3)
  set message($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasMessage() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessage() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get sourceName => $_getSZ(3);
  @$pb.TagNumber(4)
  set sourceName($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasSourceName() => $_has(3);
  @$pb.TagNumber(4)
  void clearSourceName() => clearField(4);

  @$pb.TagNumber(5)
  $core.bool get hasFixes => $_getBF(4);
  @$pb.TagNumber(5)
  set hasFixes($core.bool v) { $_setBool(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasHasFixes() => $_has(4);
  @$pb.TagNumber(5)
  void clearHasFixes() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get charStart => $_getIZ(5);
  @$pb.TagNumber(6)
  set charStart($core.int v) { $_setSignedInt32(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasCharStart() => $_has(5);
  @$pb.TagNumber(6)
  void clearCharStart() => clearField(6);

  @$pb.TagNumber(7)
  $core.int get charLength => $_getIZ(6);
  @$pb.TagNumber(7)
  set charLength($core.int v) { $_setSignedInt32(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasCharLength() => $_has(6);
  @$pb.TagNumber(7)
  void clearCharLength() => clearField(7);
}

class VersionRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('VersionRequest', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  VersionRequest._() : super();
  factory VersionRequest() => create();
  factory VersionRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory VersionRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  VersionRequest clone() => VersionRequest()..mergeFromMessage(this);
  VersionRequest copyWith(void Function(VersionRequest) updates) => super.copyWith((message) => updates(message as VersionRequest));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static VersionRequest create() => VersionRequest._();
  VersionRequest createEmptyInstance() => create();
  static $pb.PbList<VersionRequest> createRepeated() => $pb.PbList<VersionRequest>();
  @$core.pragma('dart2js:noInline')
  static VersionRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<VersionRequest>(create);
  static VersionRequest _defaultInstance;
}

class CompileResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('CompileResponse', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..aOS(1, 'result')
    ..aOS(2, 'sourceMap', protoName: 'sourceMap')
    ..aOM<ErrorMessage>(99, 'error', subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false
  ;

  CompileResponse._() : super();
  factory CompileResponse() => create();
  factory CompileResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CompileResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  CompileResponse clone() => CompileResponse()..mergeFromMessage(this);
  CompileResponse copyWith(void Function(CompileResponse) updates) => super.copyWith((message) => updates(message as CompileResponse));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static CompileResponse create() => CompileResponse._();
  CompileResponse createEmptyInstance() => create();
  static $pb.PbList<CompileResponse> createRepeated() => $pb.PbList<CompileResponse>();
  @$core.pragma('dart2js:noInline')
  static CompileResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CompileResponse>(create);
  static CompileResponse _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get result => $_getSZ(0);
  @$pb.TagNumber(1)
  set result($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasResult() => $_has(0);
  @$pb.TagNumber(1)
  void clearResult() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get sourceMap => $_getSZ(1);
  @$pb.TagNumber(2)
  set sourceMap($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSourceMap() => $_has(1);
  @$pb.TagNumber(2)
  void clearSourceMap() => clearField(2);

  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(2);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) { setField(99, v); }
  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(2);
}

class CompileDDCResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('CompileDDCResponse', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..aOS(1, 'result')
    ..aOS(2, 'modulesBaseUrl', protoName: 'modulesBaseUrl')
    ..aOM<ErrorMessage>(99, 'error', subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false
  ;

  CompileDDCResponse._() : super();
  factory CompileDDCResponse() => create();
  factory CompileDDCResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CompileDDCResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  CompileDDCResponse clone() => CompileDDCResponse()..mergeFromMessage(this);
  CompileDDCResponse copyWith(void Function(CompileDDCResponse) updates) => super.copyWith((message) => updates(message as CompileDDCResponse));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static CompileDDCResponse create() => CompileDDCResponse._();
  CompileDDCResponse createEmptyInstance() => create();
  static $pb.PbList<CompileDDCResponse> createRepeated() => $pb.PbList<CompileDDCResponse>();
  @$core.pragma('dart2js:noInline')
  static CompileDDCResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CompileDDCResponse>(create);
  static CompileDDCResponse _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get result => $_getSZ(0);
  @$pb.TagNumber(1)
  set result($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasResult() => $_has(0);
  @$pb.TagNumber(1)
  void clearResult() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get modulesBaseUrl => $_getSZ(1);
  @$pb.TagNumber(2)
  set modulesBaseUrl($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasModulesBaseUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearModulesBaseUrl() => clearField(2);

  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(2);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) { setField(99, v); }
  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(2);
}

class DocumentResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('DocumentResponse', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, 'info', entryClassName: 'DocumentResponse.InfoEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('dart_services.api'))
    ..aOM<ErrorMessage>(99, 'error', subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false
  ;

  DocumentResponse._() : super();
  factory DocumentResponse() => create();
  factory DocumentResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DocumentResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  DocumentResponse clone() => DocumentResponse()..mergeFromMessage(this);
  DocumentResponse copyWith(void Function(DocumentResponse) updates) => super.copyWith((message) => updates(message as DocumentResponse));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static DocumentResponse create() => DocumentResponse._();
  DocumentResponse createEmptyInstance() => create();
  static $pb.PbList<DocumentResponse> createRepeated() => $pb.PbList<DocumentResponse>();
  @$core.pragma('dart2js:noInline')
  static DocumentResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DocumentResponse>(create);
  static DocumentResponse _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get info => $_getMap(0);

  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(1);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) { setField(99, v); }
  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(1);
}

class CompleteResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('CompleteResponse', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..a<$core.int>(1, 'replacementOffset', $pb.PbFieldType.O3, protoName: 'replacementOffset')
    ..a<$core.int>(2, 'replacementLength', $pb.PbFieldType.O3, protoName: 'replacementLength')
    ..pc<Completion>(3, 'completions', $pb.PbFieldType.PM, subBuilder: Completion.create)
    ..aOM<ErrorMessage>(99, 'error', subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false
  ;

  CompleteResponse._() : super();
  factory CompleteResponse() => create();
  factory CompleteResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CompleteResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  CompleteResponse clone() => CompleteResponse()..mergeFromMessage(this);
  CompleteResponse copyWith(void Function(CompleteResponse) updates) => super.copyWith((message) => updates(message as CompleteResponse));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static CompleteResponse create() => CompleteResponse._();
  CompleteResponse createEmptyInstance() => create();
  static $pb.PbList<CompleteResponse> createRepeated() => $pb.PbList<CompleteResponse>();
  @$core.pragma('dart2js:noInline')
  static CompleteResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CompleteResponse>(create);
  static CompleteResponse _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get replacementOffset => $_getIZ(0);
  @$pb.TagNumber(1)
  set replacementOffset($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasReplacementOffset() => $_has(0);
  @$pb.TagNumber(1)
  void clearReplacementOffset() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get replacementLength => $_getIZ(1);
  @$pb.TagNumber(2)
  set replacementLength($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasReplacementLength() => $_has(1);
  @$pb.TagNumber(2)
  void clearReplacementLength() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<Completion> get completions => $_getList(2);

  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(3);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) { setField(99, v); }
  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(3);
}

class Completion extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('Completion', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, 'completion', entryClassName: 'Completion.CompletionEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('dart_services.api'))
    ..hasRequiredFields = false
  ;

  Completion._() : super();
  factory Completion() => create();
  factory Completion.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Completion.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  Completion clone() => Completion()..mergeFromMessage(this);
  Completion copyWith(void Function(Completion) updates) => super.copyWith((message) => updates(message as Completion));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static Completion create() => Completion._();
  Completion createEmptyInstance() => create();
  static $pb.PbList<Completion> createRepeated() => $pb.PbList<Completion>();
  @$core.pragma('dart2js:noInline')
  static Completion getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Completion>(create);
  static Completion _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get completion => $_getMap(0);
}

class FixesResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('FixesResponse', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..pc<ProblemAndFixes>(1, 'fixes', $pb.PbFieldType.PM, subBuilder: ProblemAndFixes.create)
    ..aOM<ErrorMessage>(99, 'error', subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false
  ;

  FixesResponse._() : super();
  factory FixesResponse() => create();
  factory FixesResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FixesResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  FixesResponse clone() => FixesResponse()..mergeFromMessage(this);
  FixesResponse copyWith(void Function(FixesResponse) updates) => super.copyWith((message) => updates(message as FixesResponse));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static FixesResponse create() => FixesResponse._();
  FixesResponse createEmptyInstance() => create();
  static $pb.PbList<FixesResponse> createRepeated() => $pb.PbList<FixesResponse>();
  @$core.pragma('dart2js:noInline')
  static FixesResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FixesResponse>(create);
  static FixesResponse _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<ProblemAndFixes> get fixes => $_getList(0);

  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(1);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) { setField(99, v); }
  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(1);
}

class ProblemAndFixes extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('ProblemAndFixes', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..pc<CandidateFix>(1, 'fixes', $pb.PbFieldType.PM, subBuilder: CandidateFix.create)
    ..aOS(2, 'problemMessage', protoName: 'problemMessage')
    ..a<$core.int>(3, 'offset', $pb.PbFieldType.O3)
    ..a<$core.int>(4, 'length', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  ProblemAndFixes._() : super();
  factory ProblemAndFixes() => create();
  factory ProblemAndFixes.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ProblemAndFixes.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  ProblemAndFixes clone() => ProblemAndFixes()..mergeFromMessage(this);
  ProblemAndFixes copyWith(void Function(ProblemAndFixes) updates) => super.copyWith((message) => updates(message as ProblemAndFixes));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static ProblemAndFixes create() => ProblemAndFixes._();
  ProblemAndFixes createEmptyInstance() => create();
  static $pb.PbList<ProblemAndFixes> createRepeated() => $pb.PbList<ProblemAndFixes>();
  @$core.pragma('dart2js:noInline')
  static ProblemAndFixes getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProblemAndFixes>(create);
  static ProblemAndFixes _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<CandidateFix> get fixes => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get problemMessage => $_getSZ(1);
  @$pb.TagNumber(2)
  set problemMessage($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasProblemMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearProblemMessage() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get offset => $_getIZ(2);
  @$pb.TagNumber(3)
  set offset($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasOffset() => $_has(2);
  @$pb.TagNumber(3)
  void clearOffset() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get length => $_getIZ(3);
  @$pb.TagNumber(4)
  set length($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasLength() => $_has(3);
  @$pb.TagNumber(4)
  void clearLength() => clearField(4);
}

class CandidateFix extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('CandidateFix', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..aOS(1, 'message')
    ..pc<SourceEdit>(2, 'edits', $pb.PbFieldType.PM, subBuilder: SourceEdit.create)
    ..a<$core.int>(3, 'selectionOffset', $pb.PbFieldType.O3, protoName: 'selectionOffset')
    ..pc<LinkedEditGroup>(4, 'linkedEditGroups', $pb.PbFieldType.PM, protoName: 'linkedEditGroups', subBuilder: LinkedEditGroup.create)
    ..hasRequiredFields = false
  ;

  CandidateFix._() : super();
  factory CandidateFix() => create();
  factory CandidateFix.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CandidateFix.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  CandidateFix clone() => CandidateFix()..mergeFromMessage(this);
  CandidateFix copyWith(void Function(CandidateFix) updates) => super.copyWith((message) => updates(message as CandidateFix));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static CandidateFix create() => CandidateFix._();
  CandidateFix createEmptyInstance() => create();
  static $pb.PbList<CandidateFix> createRepeated() => $pb.PbList<CandidateFix>();
  @$core.pragma('dart2js:noInline')
  static CandidateFix getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CandidateFix>(create);
  static CandidateFix _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get message => $_getSZ(0);
  @$pb.TagNumber(1)
  set message($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<SourceEdit> get edits => $_getList(1);

  @$pb.TagNumber(3)
  $core.int get selectionOffset => $_getIZ(2);
  @$pb.TagNumber(3)
  set selectionOffset($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSelectionOffset() => $_has(2);
  @$pb.TagNumber(3)
  void clearSelectionOffset() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<LinkedEditGroup> get linkedEditGroups => $_getList(3);
}

class SourceEdit extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('SourceEdit', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..a<$core.int>(1, 'offset', $pb.PbFieldType.O3)
    ..a<$core.int>(2, 'length', $pb.PbFieldType.O3)
    ..aOS(3, 'replacement')
    ..hasRequiredFields = false
  ;

  SourceEdit._() : super();
  factory SourceEdit() => create();
  factory SourceEdit.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SourceEdit.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  SourceEdit clone() => SourceEdit()..mergeFromMessage(this);
  SourceEdit copyWith(void Function(SourceEdit) updates) => super.copyWith((message) => updates(message as SourceEdit));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static SourceEdit create() => SourceEdit._();
  SourceEdit createEmptyInstance() => create();
  static $pb.PbList<SourceEdit> createRepeated() => $pb.PbList<SourceEdit>();
  @$core.pragma('dart2js:noInline')
  static SourceEdit getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SourceEdit>(create);
  static SourceEdit _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get offset => $_getIZ(0);
  @$pb.TagNumber(1)
  set offset($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasOffset() => $_has(0);
  @$pb.TagNumber(1)
  void clearOffset() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get length => $_getIZ(1);
  @$pb.TagNumber(2)
  set length($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasLength() => $_has(1);
  @$pb.TagNumber(2)
  void clearLength() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get replacement => $_getSZ(2);
  @$pb.TagNumber(3)
  set replacement($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasReplacement() => $_has(2);
  @$pb.TagNumber(3)
  void clearReplacement() => clearField(3);
}

class LinkedEditGroup extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('LinkedEditGroup', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..p<$core.int>(1, 'positions', $pb.PbFieldType.P3)
    ..a<$core.int>(2, 'length', $pb.PbFieldType.O3)
    ..pc<LinkedEditSuggestion>(3, 'suggestions', $pb.PbFieldType.PM, subBuilder: LinkedEditSuggestion.create)
    ..hasRequiredFields = false
  ;

  LinkedEditGroup._() : super();
  factory LinkedEditGroup() => create();
  factory LinkedEditGroup.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LinkedEditGroup.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  LinkedEditGroup clone() => LinkedEditGroup()..mergeFromMessage(this);
  LinkedEditGroup copyWith(void Function(LinkedEditGroup) updates) => super.copyWith((message) => updates(message as LinkedEditGroup));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static LinkedEditGroup create() => LinkedEditGroup._();
  LinkedEditGroup createEmptyInstance() => create();
  static $pb.PbList<LinkedEditGroup> createRepeated() => $pb.PbList<LinkedEditGroup>();
  @$core.pragma('dart2js:noInline')
  static LinkedEditGroup getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LinkedEditGroup>(create);
  static LinkedEditGroup _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get positions => $_getList(0);

  @$pb.TagNumber(2)
  $core.int get length => $_getIZ(1);
  @$pb.TagNumber(2)
  set length($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasLength() => $_has(1);
  @$pb.TagNumber(2)
  void clearLength() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<LinkedEditSuggestion> get suggestions => $_getList(2);
}

class LinkedEditSuggestion extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('LinkedEditSuggestion', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..aOS(1, 'value')
    ..aOS(2, 'kind')
    ..hasRequiredFields = false
  ;

  LinkedEditSuggestion._() : super();
  factory LinkedEditSuggestion() => create();
  factory LinkedEditSuggestion.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LinkedEditSuggestion.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  LinkedEditSuggestion clone() => LinkedEditSuggestion()..mergeFromMessage(this);
  LinkedEditSuggestion copyWith(void Function(LinkedEditSuggestion) updates) => super.copyWith((message) => updates(message as LinkedEditSuggestion));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static LinkedEditSuggestion create() => LinkedEditSuggestion._();
  LinkedEditSuggestion createEmptyInstance() => create();
  static $pb.PbList<LinkedEditSuggestion> createRepeated() => $pb.PbList<LinkedEditSuggestion>();
  @$core.pragma('dart2js:noInline')
  static LinkedEditSuggestion getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LinkedEditSuggestion>(create);
  static LinkedEditSuggestion _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get kind => $_getSZ(1);
  @$pb.TagNumber(2)
  set kind($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => clearField(2);
}

class FormatResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('FormatResponse', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..aOS(1, 'newString', protoName: 'newString')
    ..a<$core.int>(2, 'offset', $pb.PbFieldType.O3)
    ..aOM<ErrorMessage>(99, 'error', subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false
  ;

  FormatResponse._() : super();
  factory FormatResponse() => create();
  factory FormatResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FormatResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  FormatResponse clone() => FormatResponse()..mergeFromMessage(this);
  FormatResponse copyWith(void Function(FormatResponse) updates) => super.copyWith((message) => updates(message as FormatResponse));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static FormatResponse create() => FormatResponse._();
  FormatResponse createEmptyInstance() => create();
  static $pb.PbList<FormatResponse> createRepeated() => $pb.PbList<FormatResponse>();
  @$core.pragma('dart2js:noInline')
  static FormatResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FormatResponse>(create);
  static FormatResponse _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get newString => $_getSZ(0);
  @$pb.TagNumber(1)
  set newString($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasNewString() => $_has(0);
  @$pb.TagNumber(1)
  void clearNewString() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get offset => $_getIZ(1);
  @$pb.TagNumber(2)
  set offset($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasOffset() => $_has(1);
  @$pb.TagNumber(2)
  void clearOffset() => clearField(2);

  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(2);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) { setField(99, v); }
  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(2);
}

class AssistsResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('AssistsResponse', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..pc<CandidateFix>(1, 'assists', $pb.PbFieldType.PM, subBuilder: CandidateFix.create)
    ..aOM<ErrorMessage>(99, 'error', subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false
  ;

  AssistsResponse._() : super();
  factory AssistsResponse() => create();
  factory AssistsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AssistsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  AssistsResponse clone() => AssistsResponse()..mergeFromMessage(this);
  AssistsResponse copyWith(void Function(AssistsResponse) updates) => super.copyWith((message) => updates(message as AssistsResponse));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static AssistsResponse create() => AssistsResponse._();
  AssistsResponse createEmptyInstance() => create();
  static $pb.PbList<AssistsResponse> createRepeated() => $pb.PbList<AssistsResponse>();
  @$core.pragma('dart2js:noInline')
  static AssistsResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AssistsResponse>(create);
  static AssistsResponse _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<CandidateFix> get assists => $_getList(0);

  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(1);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) { setField(99, v); }
  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(1);
}

class VersionResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('VersionResponse', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..aOS(1, 'sdkVersion', protoName: 'sdkVersion')
    ..aOS(2, 'sdkVersionFull', protoName: 'sdkVersionFull')
    ..aOS(3, 'runtimeVersion', protoName: 'runtimeVersion')
    ..aOS(4, 'appEngineVersion', protoName: 'appEngineVersion')
    ..aOS(5, 'servicesVersion', protoName: 'servicesVersion')
    ..aOS(6, 'flutterVersion', protoName: 'flutterVersion')
    ..aOS(7, 'flutterDartVersion', protoName: 'flutterDartVersion')
    ..aOS(8, 'flutterDartVersionFull', protoName: 'flutterDartVersionFull')
    ..aOM<ErrorMessage>(99, 'error', subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false
  ;

  VersionResponse._() : super();
  factory VersionResponse() => create();
  factory VersionResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory VersionResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  VersionResponse clone() => VersionResponse()..mergeFromMessage(this);
  VersionResponse copyWith(void Function(VersionResponse) updates) => super.copyWith((message) => updates(message as VersionResponse));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static VersionResponse create() => VersionResponse._();
  VersionResponse createEmptyInstance() => create();
  static $pb.PbList<VersionResponse> createRepeated() => $pb.PbList<VersionResponse>();
  @$core.pragma('dart2js:noInline')
  static VersionResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<VersionResponse>(create);
  static VersionResponse _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sdkVersion => $_getSZ(0);
  @$pb.TagNumber(1)
  set sdkVersion($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSdkVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearSdkVersion() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get sdkVersionFull => $_getSZ(1);
  @$pb.TagNumber(2)
  set sdkVersionFull($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSdkVersionFull() => $_has(1);
  @$pb.TagNumber(2)
  void clearSdkVersionFull() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get runtimeVersion => $_getSZ(2);
  @$pb.TagNumber(3)
  set runtimeVersion($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasRuntimeVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearRuntimeVersion() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get appEngineVersion => $_getSZ(3);
  @$pb.TagNumber(4)
  set appEngineVersion($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasAppEngineVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearAppEngineVersion() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get servicesVersion => $_getSZ(4);
  @$pb.TagNumber(5)
  set servicesVersion($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasServicesVersion() => $_has(4);
  @$pb.TagNumber(5)
  void clearServicesVersion() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get flutterVersion => $_getSZ(5);
  @$pb.TagNumber(6)
  set flutterVersion($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasFlutterVersion() => $_has(5);
  @$pb.TagNumber(6)
  void clearFlutterVersion() => clearField(6);

  @$pb.TagNumber(7)
  $core.String get flutterDartVersion => $_getSZ(6);
  @$pb.TagNumber(7)
  set flutterDartVersion($core.String v) { $_setString(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasFlutterDartVersion() => $_has(6);
  @$pb.TagNumber(7)
  void clearFlutterDartVersion() => clearField(7);

  @$pb.TagNumber(8)
  $core.String get flutterDartVersionFull => $_getSZ(7);
  @$pb.TagNumber(8)
  set flutterDartVersionFull($core.String v) { $_setString(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasFlutterDartVersionFull() => $_has(7);
  @$pb.TagNumber(8)
  void clearFlutterDartVersionFull() => clearField(8);

  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(8);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) { setField(99, v); }
  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(8);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(8);
}

class BadRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('BadRequest', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..aOM<ErrorMessage>(99, 'error', subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false
  ;

  BadRequest._() : super();
  factory BadRequest() => create();
  factory BadRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BadRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  BadRequest clone() => BadRequest()..mergeFromMessage(this);
  BadRequest copyWith(void Function(BadRequest) updates) => super.copyWith((message) => updates(message as BadRequest));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static BadRequest create() => BadRequest._();
  BadRequest createEmptyInstance() => create();
  static $pb.PbList<BadRequest> createRepeated() => $pb.PbList<BadRequest>();
  @$core.pragma('dart2js:noInline')
  static BadRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BadRequest>(create);
  static BadRequest _defaultInstance;

  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(0);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) { setField(99, v); }
  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(0);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(0);
}

class ErrorMessage extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo('ErrorMessage', package: const $pb.PackageName('dart_services.api'), createEmptyInstance: create)
    ..aOS(1, 'message')
    ..hasRequiredFields = false
  ;

  ErrorMessage._() : super();
  factory ErrorMessage() => create();
  factory ErrorMessage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ErrorMessage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  ErrorMessage clone() => ErrorMessage()..mergeFromMessage(this);
  ErrorMessage copyWith(void Function(ErrorMessage) updates) => super.copyWith((message) => updates(message as ErrorMessage));
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static ErrorMessage create() => ErrorMessage._();
  ErrorMessage createEmptyInstance() => create();
  static $pb.PbList<ErrorMessage> createRepeated() => $pb.PbList<ErrorMessage>();
  @$core.pragma('dart2js:noInline')
  static ErrorMessage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ErrorMessage>(create);
  static ErrorMessage _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get message => $_getSZ(0);
  @$pb.TagNumber(1)
  set message($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => clearField(1);
}


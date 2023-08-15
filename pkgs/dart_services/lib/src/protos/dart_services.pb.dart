//
//  Generated code. Do not modify.
//  source: protos/dart_services.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class CompileRequest extends $pb.GeneratedMessage {
  factory CompileRequest({
    $core.String? source,
    $core.bool? returnSourceMap,
  }) {
    final $result = create();
    if (source != null) {
      $result.source = source;
    }
    if (returnSourceMap != null) {
      $result.returnSourceMap = returnSourceMap;
    }
    return $result;
  }
  CompileRequest._() : super();
  factory CompileRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CompileRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompileRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'source')
    ..aOB(2, _omitFieldNames ? '' : 'returnSourceMap',
        protoName: 'returnSourceMap')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CompileRequest clone() => CompileRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CompileRequest copyWith(void Function(CompileRequest) updates) =>
      super.copyWith((message) => updates(message as CompileRequest))
          as CompileRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompileRequest create() => CompileRequest._();
  CompileRequest createEmptyInstance() => create();
  static $pb.PbList<CompileRequest> createRepeated() =>
      $pb.PbList<CompileRequest>();
  @$core.pragma('dart2js:noInline')
  static CompileRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompileRequest>(create);
  static CompileRequest? _defaultInstance;

  /// The Dart source.
  @$pb.TagNumber(1)
  $core.String get source => $_getSZ(0);
  @$pb.TagNumber(1)
  set source($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasSource() => $_has(0);
  @$pb.TagNumber(1)
  void clearSource() => clearField(1);

  /// Return the Dart to JS source map; optional (defaults to false).
  @$pb.TagNumber(2)
  $core.bool get returnSourceMap => $_getBF(1);
  @$pb.TagNumber(2)
  set returnSourceMap($core.bool v) {
    $_setBool(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasReturnSourceMap() => $_has(1);
  @$pb.TagNumber(2)
  void clearReturnSourceMap() => clearField(2);
}

/// / Compile request for a multiple file set.
class CompileFilesRequest extends $pb.GeneratedMessage {
  factory CompileFilesRequest({
    $core.Map<$core.String, $core.String>? files,
    $core.bool? returnSourceMap,
  }) {
    final $result = create();
    if (files != null) {
      $result.files.addAll(files);
    }
    if (returnSourceMap != null) {
      $result.returnSourceMap = returnSourceMap;
    }
    return $result;
  }
  CompileFilesRequest._() : super();
  factory CompileFilesRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CompileFilesRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompileFilesRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, _omitFieldNames ? '' : 'files',
        entryClassName: 'CompileFilesRequest.FilesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('dart_services.api'))
    ..aOB(2, _omitFieldNames ? '' : 'returnSourceMap',
        protoName: 'returnSourceMap')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CompileFilesRequest clone() => CompileFilesRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CompileFilesRequest copyWith(void Function(CompileFilesRequest) updates) =>
      super.copyWith((message) => updates(message as CompileFilesRequest))
          as CompileFilesRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompileFilesRequest create() => CompileFilesRequest._();
  CompileFilesRequest createEmptyInstance() => create();
  static $pb.PbList<CompileFilesRequest> createRepeated() =>
      $pb.PbList<CompileFilesRequest>();
  @$core.pragma('dart2js:noInline')
  static CompileFilesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompileFilesRequest>(create);
  static CompileFilesRequest? _defaultInstance;

  /// The Dart source files set. map of { filename1:sourcecode1 .. filenameN:sourcecodeN }
  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get files => $_getMap(0);

  /// Return the Dart to JS source map; optional (defaults to false).
  @$pb.TagNumber(2)
  $core.bool get returnSourceMap => $_getBF(1);
  @$pb.TagNumber(2)
  set returnSourceMap($core.bool v) {
    $_setBool(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasReturnSourceMap() => $_has(1);
  @$pb.TagNumber(2)
  void clearReturnSourceMap() => clearField(2);
}

class CompileDDCRequest extends $pb.GeneratedMessage {
  factory CompileDDCRequest({
    $core.String? source,
  }) {
    final $result = create();
    if (source != null) {
      $result.source = source;
    }
    return $result;
  }
  CompileDDCRequest._() : super();
  factory CompileDDCRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CompileDDCRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompileDDCRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'source')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CompileDDCRequest clone() => CompileDDCRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CompileDDCRequest copyWith(void Function(CompileDDCRequest) updates) =>
      super.copyWith((message) => updates(message as CompileDDCRequest))
          as CompileDDCRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompileDDCRequest create() => CompileDDCRequest._();
  CompileDDCRequest createEmptyInstance() => create();
  static $pb.PbList<CompileDDCRequest> createRepeated() =>
      $pb.PbList<CompileDDCRequest>();
  @$core.pragma('dart2js:noInline')
  static CompileDDCRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompileDDCRequest>(create);
  static CompileDDCRequest? _defaultInstance;

  /// The Dart source.
  @$pb.TagNumber(1)
  $core.String get source => $_getSZ(0);
  @$pb.TagNumber(1)
  set source($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasSource() => $_has(0);
  @$pb.TagNumber(1)
  void clearSource() => clearField(1);
}

/// / DDC Compile request for a multiple file set.
class CompileFilesDDCRequest extends $pb.GeneratedMessage {
  factory CompileFilesDDCRequest({
    $core.Map<$core.String, $core.String>? files,
  }) {
    final $result = create();
    if (files != null) {
      $result.files.addAll(files);
    }
    return $result;
  }
  CompileFilesDDCRequest._() : super();
  factory CompileFilesDDCRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CompileFilesDDCRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompileFilesDDCRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, _omitFieldNames ? '' : 'files',
        entryClassName: 'CompileFilesDDCRequest.FilesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('dart_services.api'))
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CompileFilesDDCRequest clone() =>
      CompileFilesDDCRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CompileFilesDDCRequest copyWith(
          void Function(CompileFilesDDCRequest) updates) =>
      super.copyWith((message) => updates(message as CompileFilesDDCRequest))
          as CompileFilesDDCRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompileFilesDDCRequest create() => CompileFilesDDCRequest._();
  CompileFilesDDCRequest createEmptyInstance() => create();
  static $pb.PbList<CompileFilesDDCRequest> createRepeated() =>
      $pb.PbList<CompileFilesDDCRequest>();
  @$core.pragma('dart2js:noInline')
  static CompileFilesDDCRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompileFilesDDCRequest>(create);
  static CompileFilesDDCRequest? _defaultInstance;

  /// The Dart source files set. map of { filename1:sourcecode1 .. filenameN:sourcecodeN }
  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get files => $_getMap(0);
}

class FlutterBuildRequest extends $pb.GeneratedMessage {
  factory FlutterBuildRequest({
    $core.String? source,
  }) {
    final $result = create();
    if (source != null) {
      $result.source = source;
    }
    return $result;
  }
  FlutterBuildRequest._() : super();
  factory FlutterBuildRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FlutterBuildRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FlutterBuildRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'source')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  FlutterBuildRequest clone() => FlutterBuildRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  FlutterBuildRequest copyWith(void Function(FlutterBuildRequest) updates) =>
      super.copyWith((message) => updates(message as FlutterBuildRequest))
          as FlutterBuildRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FlutterBuildRequest create() => FlutterBuildRequest._();
  FlutterBuildRequest createEmptyInstance() => create();
  static $pb.PbList<FlutterBuildRequest> createRepeated() =>
      $pb.PbList<FlutterBuildRequest>();
  @$core.pragma('dart2js:noInline')
  static FlutterBuildRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FlutterBuildRequest>(create);
  static FlutterBuildRequest? _defaultInstance;

  /// The Dart source.
  @$pb.TagNumber(1)
  $core.String get source => $_getSZ(0);
  @$pb.TagNumber(1)
  set source($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasSource() => $_has(0);
  @$pb.TagNumber(1)
  void clearSource() => clearField(1);
}

class FlutterBuildResponse extends $pb.GeneratedMessage {
  factory FlutterBuildResponse({
    $core.Map<$core.String, $core.String>? artifacts,
    ErrorMessage? error,
  }) {
    final $result = create();
    if (artifacts != null) {
      $result.artifacts.addAll(artifacts);
    }
    if (error != null) {
      $result.error = error;
    }
    return $result;
  }
  FlutterBuildResponse._() : super();
  factory FlutterBuildResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FlutterBuildResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FlutterBuildResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, _omitFieldNames ? '' : 'artifacts',
        entryClassName: 'FlutterBuildResponse.ArtifactsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('dart_services.api'))
    ..aOM<ErrorMessage>(99, _omitFieldNames ? '' : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  FlutterBuildResponse clone() =>
      FlutterBuildResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  FlutterBuildResponse copyWith(void Function(FlutterBuildResponse) updates) =>
      super.copyWith((message) => updates(message as FlutterBuildResponse))
          as FlutterBuildResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FlutterBuildResponse create() => FlutterBuildResponse._();
  FlutterBuildResponse createEmptyInstance() => create();
  static $pb.PbList<FlutterBuildResponse> createRepeated() =>
      $pb.PbList<FlutterBuildResponse>();
  @$core.pragma('dart2js:noInline')
  static FlutterBuildResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FlutterBuildResponse>(create);
  static FlutterBuildResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get artifacts => $_getMap(0);

  /// Make this response compatible with BadRequest
  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(1);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) {
    setField(99, v);
  }

  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(1);
}

class SourceRequest extends $pb.GeneratedMessage {
  factory SourceRequest({
    $core.String? source,
    $core.int? offset,
  }) {
    final $result = create();
    if (source != null) {
      $result.source = source;
    }
    if (offset != null) {
      $result.offset = offset;
    }
    return $result;
  }
  SourceRequest._() : super();
  factory SourceRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory SourceRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SourceRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'source')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'offset', $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  SourceRequest clone() => SourceRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  SourceRequest copyWith(void Function(SourceRequest) updates) =>
      super.copyWith((message) => updates(message as SourceRequest))
          as SourceRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SourceRequest create() => SourceRequest._();
  SourceRequest createEmptyInstance() => create();
  static $pb.PbList<SourceRequest> createRepeated() =>
      $pb.PbList<SourceRequest>();
  @$core.pragma('dart2js:noInline')
  static SourceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SourceRequest>(create);
  static SourceRequest? _defaultInstance;

  /// The Dart source.
  @$pb.TagNumber(1)
  $core.String get source => $_getSZ(0);
  @$pb.TagNumber(1)
  set source($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasSource() => $_has(0);
  @$pb.TagNumber(1)
  void clearSource() => clearField(1);

  /// The offset within source to operate at.
  @$pb.TagNumber(2)
  $core.int get offset => $_getIZ(1);
  @$pb.TagNumber(2)
  set offset($core.int v) {
    $_setSignedInt32(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasOffset() => $_has(1);
  @$pb.TagNumber(2)
  void clearOffset() => clearField(2);
}

/// / Multiple file set of dart source for analysis, completion, fixes, etc.
class SourceFilesRequest extends $pb.GeneratedMessage {
  factory SourceFilesRequest({
    $core.Map<$core.String, $core.String>? files,
    $core.String? activeSourceName,
    $core.int? offset,
  }) {
    final $result = create();
    if (files != null) {
      $result.files.addAll(files);
    }
    if (activeSourceName != null) {
      $result.activeSourceName = activeSourceName;
    }
    if (offset != null) {
      $result.offset = offset;
    }
    return $result;
  }
  SourceFilesRequest._() : super();
  factory SourceFilesRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory SourceFilesRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SourceFilesRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, _omitFieldNames ? '' : 'files',
        entryClassName: 'SourceFilesRequest.FilesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('dart_services.api'))
    ..aOS(2, _omitFieldNames ? '' : 'activeSourceName',
        protoName: 'activeSourceName')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'offset', $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  SourceFilesRequest clone() => SourceFilesRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  SourceFilesRequest copyWith(void Function(SourceFilesRequest) updates) =>
      super.copyWith((message) => updates(message as SourceFilesRequest))
          as SourceFilesRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SourceFilesRequest create() => SourceFilesRequest._();
  SourceFilesRequest createEmptyInstance() => create();
  static $pb.PbList<SourceFilesRequest> createRepeated() =>
      $pb.PbList<SourceFilesRequest>();
  @$core.pragma('dart2js:noInline')
  static SourceFilesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SourceFilesRequest>(create);
  static SourceFilesRequest? _defaultInstance;

  /// The Dart source files set. map of { filename1:sourcecode1 .. filenameN:sourcecodeN }
  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get files => $_getMap(0);

  /// active (within editor) source filename key within files map
  @$pb.TagNumber(2)
  $core.String get activeSourceName => $_getSZ(1);
  @$pb.TagNumber(2)
  set activeSourceName($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasActiveSourceName() => $_has(1);
  @$pb.TagNumber(2)
  void clearActiveSourceName() => clearField(2);

  /// The offset within active source file to operate at.
  @$pb.TagNumber(3)
  $core.int get offset => $_getIZ(2);
  @$pb.TagNumber(3)
  set offset($core.int v) {
    $_setSignedInt32(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasOffset() => $_has(2);
  @$pb.TagNumber(3)
  void clearOffset() => clearField(3);
}

class AnalysisResults extends $pb.GeneratedMessage {
  factory AnalysisResults({
    $core.Iterable<AnalysisIssue>? issues,
    $core.Iterable<$core.String>? packageImports,
    ErrorMessage? error,
  }) {
    final $result = create();
    if (issues != null) {
      $result.issues.addAll(issues);
    }
    if (packageImports != null) {
      $result.packageImports.addAll(packageImports);
    }
    if (error != null) {
      $result.error = error;
    }
    return $result;
  }
  AnalysisResults._() : super();
  factory AnalysisResults.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory AnalysisResults.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AnalysisResults',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..pc<AnalysisIssue>(1, _omitFieldNames ? '' : 'issues', $pb.PbFieldType.PM,
        subBuilder: AnalysisIssue.create)
    ..pPS(2, _omitFieldNames ? '' : 'packageImports',
        protoName: 'packageImports')
    ..aOM<ErrorMessage>(99, _omitFieldNames ? '' : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  AnalysisResults clone() => AnalysisResults()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  AnalysisResults copyWith(void Function(AnalysisResults) updates) =>
      super.copyWith((message) => updates(message as AnalysisResults))
          as AnalysisResults;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AnalysisResults create() => AnalysisResults._();
  AnalysisResults createEmptyInstance() => create();
  static $pb.PbList<AnalysisResults> createRepeated() =>
      $pb.PbList<AnalysisResults>();
  @$core.pragma('dart2js:noInline')
  static AnalysisResults getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AnalysisResults>(create);
  static AnalysisResults? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<AnalysisIssue> get issues => $_getList(0);

  /// The package imports parsed from the source.
  @$pb.TagNumber(2)
  $core.List<$core.String> get packageImports => $_getList(1);

  /// Make this response compatible with BadRequest
  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(2);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) {
    setField(99, v);
  }

  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(2);
}

class AnalysisIssue extends $pb.GeneratedMessage {
  factory AnalysisIssue({
    $core.String? kind,
    $core.int? line,
    $core.String? message,
    $core.String? sourceName,
    $core.bool? hasFixes,
    $core.int? charStart,
    $core.int? charLength,
    $core.String? url,
    $core.Iterable<DiagnosticMessage>? diagnosticMessages,
    $core.String? correction,
    $core.int? column,
    $core.String? code,
  }) {
    final $result = create();
    if (kind != null) {
      $result.kind = kind;
    }
    if (line != null) {
      $result.line = line;
    }
    if (message != null) {
      $result.message = message;
    }
    if (sourceName != null) {
      $result.sourceName = sourceName;
    }
    if (hasFixes != null) {
      $result.hasFixes = hasFixes;
    }
    if (charStart != null) {
      $result.charStart = charStart;
    }
    if (charLength != null) {
      $result.charLength = charLength;
    }
    if (url != null) {
      $result.url = url;
    }
    if (diagnosticMessages != null) {
      $result.diagnosticMessages.addAll(diagnosticMessages);
    }
    if (correction != null) {
      $result.correction = correction;
    }
    if (column != null) {
      $result.column = column;
    }
    if (code != null) {
      $result.code = code;
    }
    return $result;
  }
  AnalysisIssue._() : super();
  factory AnalysisIssue.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory AnalysisIssue.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AnalysisIssue',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'kind')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'line', $pb.PbFieldType.O3)
    ..aOS(3, _omitFieldNames ? '' : 'message')
    ..aOS(4, _omitFieldNames ? '' : 'sourceName', protoName: 'sourceName')
    ..aOB(5, _omitFieldNames ? '' : 'hasFixes', protoName: 'hasFixes')
    ..a<$core.int>(6, _omitFieldNames ? '' : 'charStart', $pb.PbFieldType.O3,
        protoName: 'charStart')
    ..a<$core.int>(7, _omitFieldNames ? '' : 'charLength', $pb.PbFieldType.O3,
        protoName: 'charLength')
    ..aOS(8, _omitFieldNames ? '' : 'url')
    ..pc<DiagnosticMessage>(
        9, _omitFieldNames ? '' : 'diagnosticMessages', $pb.PbFieldType.PM,
        protoName: 'diagnosticMessages', subBuilder: DiagnosticMessage.create)
    ..aOS(10, _omitFieldNames ? '' : 'correction')
    ..a<$core.int>(11, _omitFieldNames ? '' : 'column', $pb.PbFieldType.O3)
    ..aOS(12, _omitFieldNames ? '' : 'code')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  AnalysisIssue clone() => AnalysisIssue()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  AnalysisIssue copyWith(void Function(AnalysisIssue) updates) =>
      super.copyWith((message) => updates(message as AnalysisIssue))
          as AnalysisIssue;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AnalysisIssue create() => AnalysisIssue._();
  AnalysisIssue createEmptyInstance() => create();
  static $pb.PbList<AnalysisIssue> createRepeated() =>
      $pb.PbList<AnalysisIssue>();
  @$core.pragma('dart2js:noInline')
  static AnalysisIssue getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AnalysisIssue>(create);
  static AnalysisIssue? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get kind => $_getSZ(0);
  @$pb.TagNumber(1)
  set kind($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get line => $_getIZ(1);
  @$pb.TagNumber(2)
  set line($core.int v) {
    $_setSignedInt32(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasLine() => $_has(1);
  @$pb.TagNumber(2)
  void clearLine() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get message => $_getSZ(2);
  @$pb.TagNumber(3)
  set message($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasMessage() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessage() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get sourceName => $_getSZ(3);
  @$pb.TagNumber(4)
  set sourceName($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasSourceName() => $_has(3);
  @$pb.TagNumber(4)
  void clearSourceName() => clearField(4);

  @$pb.TagNumber(5)
  $core.bool get hasFixes => $_getBF(4);
  @$pb.TagNumber(5)
  set hasFixes($core.bool v) {
    $_setBool(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasHasFixes() => $_has(4);
  @$pb.TagNumber(5)
  void clearHasFixes() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get charStart => $_getIZ(5);
  @$pb.TagNumber(6)
  set charStart($core.int v) {
    $_setSignedInt32(5, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasCharStart() => $_has(5);
  @$pb.TagNumber(6)
  void clearCharStart() => clearField(6);

  @$pb.TagNumber(7)
  $core.int get charLength => $_getIZ(6);
  @$pb.TagNumber(7)
  set charLength($core.int v) {
    $_setSignedInt32(6, v);
  }

  @$pb.TagNumber(7)
  $core.bool hasCharLength() => $_has(6);
  @$pb.TagNumber(7)
  void clearCharLength() => clearField(7);

  @$pb.TagNumber(8)
  $core.String get url => $_getSZ(7);
  @$pb.TagNumber(8)
  set url($core.String v) {
    $_setString(7, v);
  }

  @$pb.TagNumber(8)
  $core.bool hasUrl() => $_has(7);
  @$pb.TagNumber(8)
  void clearUrl() => clearField(8);

  @$pb.TagNumber(9)
  $core.List<DiagnosticMessage> get diagnosticMessages => $_getList(8);

  @$pb.TagNumber(10)
  $core.String get correction => $_getSZ(9);
  @$pb.TagNumber(10)
  set correction($core.String v) {
    $_setString(9, v);
  }

  @$pb.TagNumber(10)
  $core.bool hasCorrection() => $_has(9);
  @$pb.TagNumber(10)
  void clearCorrection() => clearField(10);

  @$pb.TagNumber(11)
  $core.int get column => $_getIZ(10);
  @$pb.TagNumber(11)
  set column($core.int v) {
    $_setSignedInt32(10, v);
  }

  @$pb.TagNumber(11)
  $core.bool hasColumn() => $_has(10);
  @$pb.TagNumber(11)
  void clearColumn() => clearField(11);

  @$pb.TagNumber(12)
  $core.String get code => $_getSZ(11);
  @$pb.TagNumber(12)
  set code($core.String v) {
    $_setString(11, v);
  }

  @$pb.TagNumber(12)
  $core.bool hasCode() => $_has(11);
  @$pb.TagNumber(12)
  void clearCode() => clearField(12);
}

class DiagnosticMessage extends $pb.GeneratedMessage {
  factory DiagnosticMessage({
    $core.String? message,
    $core.int? line,
    $core.int? charStart,
    $core.int? charLength,
  }) {
    final $result = create();
    if (message != null) {
      $result.message = message;
    }
    if (line != null) {
      $result.line = line;
    }
    if (charStart != null) {
      $result.charStart = charStart;
    }
    if (charLength != null) {
      $result.charLength = charLength;
    }
    return $result;
  }
  DiagnosticMessage._() : super();
  factory DiagnosticMessage.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory DiagnosticMessage.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DiagnosticMessage',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'message')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'line', $pb.PbFieldType.O3)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'charStart', $pb.PbFieldType.O3,
        protoName: 'charStart')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'charLength', $pb.PbFieldType.O3,
        protoName: 'charLength')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  DiagnosticMessage clone() => DiagnosticMessage()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  DiagnosticMessage copyWith(void Function(DiagnosticMessage) updates) =>
      super.copyWith((message) => updates(message as DiagnosticMessage))
          as DiagnosticMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DiagnosticMessage create() => DiagnosticMessage._();
  DiagnosticMessage createEmptyInstance() => create();
  static $pb.PbList<DiagnosticMessage> createRepeated() =>
      $pb.PbList<DiagnosticMessage>();
  @$core.pragma('dart2js:noInline')
  static DiagnosticMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DiagnosticMessage>(create);
  static DiagnosticMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get message => $_getSZ(0);
  @$pb.TagNumber(1)
  set message($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get line => $_getIZ(1);
  @$pb.TagNumber(2)
  set line($core.int v) {
    $_setSignedInt32(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasLine() => $_has(1);
  @$pb.TagNumber(2)
  void clearLine() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get charStart => $_getIZ(2);
  @$pb.TagNumber(3)
  set charStart($core.int v) {
    $_setSignedInt32(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasCharStart() => $_has(2);
  @$pb.TagNumber(3)
  void clearCharStart() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get charLength => $_getIZ(3);
  @$pb.TagNumber(4)
  set charLength($core.int v) {
    $_setSignedInt32(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasCharLength() => $_has(3);
  @$pb.TagNumber(4)
  void clearCharLength() => clearField(4);
}

class VersionRequest extends $pb.GeneratedMessage {
  factory VersionRequest() => create();
  VersionRequest._() : super();
  factory VersionRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory VersionRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VersionRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  VersionRequest clone() => VersionRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  VersionRequest copyWith(void Function(VersionRequest) updates) =>
      super.copyWith((message) => updates(message as VersionRequest))
          as VersionRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static VersionRequest create() => VersionRequest._();
  VersionRequest createEmptyInstance() => create();
  static $pb.PbList<VersionRequest> createRepeated() =>
      $pb.PbList<VersionRequest>();
  @$core.pragma('dart2js:noInline')
  static VersionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<VersionRequest>(create);
  static VersionRequest? _defaultInstance;
}

class CompileResponse extends $pb.GeneratedMessage {
  factory CompileResponse({
    $core.String? result,
    $core.String? sourceMap,
    ErrorMessage? error,
  }) {
    final $result = create();
    if (result != null) {
      $result.result = result;
    }
    if (sourceMap != null) {
      $result.sourceMap = sourceMap;
    }
    if (error != null) {
      $result.error = error;
    }
    return $result;
  }
  CompileResponse._() : super();
  factory CompileResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CompileResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompileResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'result')
    ..aOS(2, _omitFieldNames ? '' : 'sourceMap', protoName: 'sourceMap')
    ..aOM<ErrorMessage>(99, _omitFieldNames ? '' : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CompileResponse clone() => CompileResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CompileResponse copyWith(void Function(CompileResponse) updates) =>
      super.copyWith((message) => updates(message as CompileResponse))
          as CompileResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompileResponse create() => CompileResponse._();
  CompileResponse createEmptyInstance() => create();
  static $pb.PbList<CompileResponse> createRepeated() =>
      $pb.PbList<CompileResponse>();
  @$core.pragma('dart2js:noInline')
  static CompileResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompileResponse>(create);
  static CompileResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get result => $_getSZ(0);
  @$pb.TagNumber(1)
  set result($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasResult() => $_has(0);
  @$pb.TagNumber(1)
  void clearResult() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get sourceMap => $_getSZ(1);
  @$pb.TagNumber(2)
  set sourceMap($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasSourceMap() => $_has(1);
  @$pb.TagNumber(2)
  void clearSourceMap() => clearField(2);

  /// Make this response compatible with BadRequest
  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(2);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) {
    setField(99, v);
  }

  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(2);
}

class CompileDDCResponse extends $pb.GeneratedMessage {
  factory CompileDDCResponse({
    $core.String? result,
    $core.String? modulesBaseUrl,
    ErrorMessage? error,
  }) {
    final $result = create();
    if (result != null) {
      $result.result = result;
    }
    if (modulesBaseUrl != null) {
      $result.modulesBaseUrl = modulesBaseUrl;
    }
    if (error != null) {
      $result.error = error;
    }
    return $result;
  }
  CompileDDCResponse._() : super();
  factory CompileDDCResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CompileDDCResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompileDDCResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'result')
    ..aOS(2, _omitFieldNames ? '' : 'modulesBaseUrl',
        protoName: 'modulesBaseUrl')
    ..aOM<ErrorMessage>(99, _omitFieldNames ? '' : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CompileDDCResponse clone() => CompileDDCResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CompileDDCResponse copyWith(void Function(CompileDDCResponse) updates) =>
      super.copyWith((message) => updates(message as CompileDDCResponse))
          as CompileDDCResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompileDDCResponse create() => CompileDDCResponse._();
  CompileDDCResponse createEmptyInstance() => create();
  static $pb.PbList<CompileDDCResponse> createRepeated() =>
      $pb.PbList<CompileDDCResponse>();
  @$core.pragma('dart2js:noInline')
  static CompileDDCResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompileDDCResponse>(create);
  static CompileDDCResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get result => $_getSZ(0);
  @$pb.TagNumber(1)
  set result($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasResult() => $_has(0);
  @$pb.TagNumber(1)
  void clearResult() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get modulesBaseUrl => $_getSZ(1);
  @$pb.TagNumber(2)
  set modulesBaseUrl($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasModulesBaseUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearModulesBaseUrl() => clearField(2);

  /// Make this response compatible with BadRequest
  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(2);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) {
    setField(99, v);
  }

  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(2);
}

class DocumentResponse extends $pb.GeneratedMessage {
  factory DocumentResponse({
    $core.Map<$core.String, $core.String>? info,
    ErrorMessage? error,
  }) {
    final $result = create();
    if (info != null) {
      $result.info.addAll(info);
    }
    if (error != null) {
      $result.error = error;
    }
    return $result;
  }
  DocumentResponse._() : super();
  factory DocumentResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory DocumentResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DocumentResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, _omitFieldNames ? '' : 'info',
        entryClassName: 'DocumentResponse.InfoEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('dart_services.api'))
    ..aOM<ErrorMessage>(99, _omitFieldNames ? '' : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  DocumentResponse clone() => DocumentResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  DocumentResponse copyWith(void Function(DocumentResponse) updates) =>
      super.copyWith((message) => updates(message as DocumentResponse))
          as DocumentResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DocumentResponse create() => DocumentResponse._();
  DocumentResponse createEmptyInstance() => create();
  static $pb.PbList<DocumentResponse> createRepeated() =>
      $pb.PbList<DocumentResponse>();
  @$core.pragma('dart2js:noInline')
  static DocumentResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DocumentResponse>(create);
  static DocumentResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get info => $_getMap(0);

  /// Make this response compatible with BadRequest
  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(1);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) {
    setField(99, v);
  }

  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(1);
}

class CompleteResponse extends $pb.GeneratedMessage {
  factory CompleteResponse({
    $core.int? replacementOffset,
    $core.int? replacementLength,
    $core.Iterable<Completion>? completions,
    ErrorMessage? error,
  }) {
    final $result = create();
    if (replacementOffset != null) {
      $result.replacementOffset = replacementOffset;
    }
    if (replacementLength != null) {
      $result.replacementLength = replacementLength;
    }
    if (completions != null) {
      $result.completions.addAll(completions);
    }
    if (error != null) {
      $result.error = error;
    }
    return $result;
  }
  CompleteResponse._() : super();
  factory CompleteResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CompleteResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompleteResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..a<$core.int>(
        1, _omitFieldNames ? '' : 'replacementOffset', $pb.PbFieldType.O3,
        protoName: 'replacementOffset')
    ..a<$core.int>(
        2, _omitFieldNames ? '' : 'replacementLength', $pb.PbFieldType.O3,
        protoName: 'replacementLength')
    ..pc<Completion>(
        3, _omitFieldNames ? '' : 'completions', $pb.PbFieldType.PM,
        subBuilder: Completion.create)
    ..aOM<ErrorMessage>(99, _omitFieldNames ? '' : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CompleteResponse clone() => CompleteResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CompleteResponse copyWith(void Function(CompleteResponse) updates) =>
      super.copyWith((message) => updates(message as CompleteResponse))
          as CompleteResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompleteResponse create() => CompleteResponse._();
  CompleteResponse createEmptyInstance() => create();
  static $pb.PbList<CompleteResponse> createRepeated() =>
      $pb.PbList<CompleteResponse>();
  @$core.pragma('dart2js:noInline')
  static CompleteResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompleteResponse>(create);
  static CompleteResponse? _defaultInstance;

  /// The offset of the start of the text to be replaced.
  @$pb.TagNumber(1)
  $core.int get replacementOffset => $_getIZ(0);
  @$pb.TagNumber(1)
  set replacementOffset($core.int v) {
    $_setSignedInt32(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasReplacementOffset() => $_has(0);
  @$pb.TagNumber(1)
  void clearReplacementOffset() => clearField(1);

  /// The length of the text to be replaced.
  @$pb.TagNumber(2)
  $core.int get replacementLength => $_getIZ(1);
  @$pb.TagNumber(2)
  set replacementLength($core.int v) {
    $_setSignedInt32(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasReplacementLength() => $_has(1);
  @$pb.TagNumber(2)
  void clearReplacementLength() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<Completion> get completions => $_getList(2);

  /// Make this response compatible with BadRequest
  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(3);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) {
    setField(99, v);
  }

  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(3);
}

class Completion extends $pb.GeneratedMessage {
  factory Completion({
    $core.Map<$core.String, $core.String>? completion,
  }) {
    final $result = create();
    if (completion != null) {
      $result.completion.addAll(completion);
    }
    return $result;
  }
  Completion._() : super();
  factory Completion.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Completion.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Completion',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..m<$core.String, $core.String>(1, _omitFieldNames ? '' : 'completion',
        entryClassName: 'Completion.CompletionEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('dart_services.api'))
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Completion clone() => Completion()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Completion copyWith(void Function(Completion) updates) =>
      super.copyWith((message) => updates(message as Completion)) as Completion;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Completion create() => Completion._();
  Completion createEmptyInstance() => create();
  static $pb.PbList<Completion> createRepeated() => $pb.PbList<Completion>();
  @$core.pragma('dart2js:noInline')
  static Completion getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Completion>(create);
  static Completion? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get completion => $_getMap(0);
}

class FixesResponse extends $pb.GeneratedMessage {
  factory FixesResponse({
    $core.Iterable<ProblemAndFixes>? fixes,
    ErrorMessage? error,
  }) {
    final $result = create();
    if (fixes != null) {
      $result.fixes.addAll(fixes);
    }
    if (error != null) {
      $result.error = error;
    }
    return $result;
  }
  FixesResponse._() : super();
  factory FixesResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FixesResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FixesResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..pc<ProblemAndFixes>(1, _omitFieldNames ? '' : 'fixes', $pb.PbFieldType.PM,
        subBuilder: ProblemAndFixes.create)
    ..aOM<ErrorMessage>(99, _omitFieldNames ? '' : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  FixesResponse clone() => FixesResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  FixesResponse copyWith(void Function(FixesResponse) updates) =>
      super.copyWith((message) => updates(message as FixesResponse))
          as FixesResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FixesResponse create() => FixesResponse._();
  FixesResponse createEmptyInstance() => create();
  static $pb.PbList<FixesResponse> createRepeated() =>
      $pb.PbList<FixesResponse>();
  @$core.pragma('dart2js:noInline')
  static FixesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FixesResponse>(create);
  static FixesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<ProblemAndFixes> get fixes => $_getList(0);

  /// Make this response compatible with BadRequest
  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(1);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) {
    setField(99, v);
  }

  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(1);
}

/// Represents a problem detected during analysis, and a set of possible ways of
/// resolving the problem.
class ProblemAndFixes extends $pb.GeneratedMessage {
  factory ProblemAndFixes({
    $core.Iterable<CandidateFix>? fixes,
    $core.String? problemMessage,
    $core.int? offset,
    $core.int? length,
  }) {
    final $result = create();
    if (fixes != null) {
      $result.fixes.addAll(fixes);
    }
    if (problemMessage != null) {
      $result.problemMessage = problemMessage;
    }
    if (offset != null) {
      $result.offset = offset;
    }
    if (length != null) {
      $result.length = length;
    }
    return $result;
  }
  ProblemAndFixes._() : super();
  factory ProblemAndFixes.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ProblemAndFixes.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProblemAndFixes',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..pc<CandidateFix>(1, _omitFieldNames ? '' : 'fixes', $pb.PbFieldType.PM,
        subBuilder: CandidateFix.create)
    ..aOS(2, _omitFieldNames ? '' : 'problemMessage',
        protoName: 'problemMessage')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'offset', $pb.PbFieldType.O3)
    ..a<$core.int>(4, _omitFieldNames ? '' : 'length', $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  ProblemAndFixes clone() => ProblemAndFixes()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  ProblemAndFixes copyWith(void Function(ProblemAndFixes) updates) =>
      super.copyWith((message) => updates(message as ProblemAndFixes))
          as ProblemAndFixes;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProblemAndFixes create() => ProblemAndFixes._();
  ProblemAndFixes createEmptyInstance() => create();
  static $pb.PbList<ProblemAndFixes> createRepeated() =>
      $pb.PbList<ProblemAndFixes>();
  @$core.pragma('dart2js:noInline')
  static ProblemAndFixes getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProblemAndFixes>(create);
  static ProblemAndFixes? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<CandidateFix> get fixes => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get problemMessage => $_getSZ(1);
  @$pb.TagNumber(2)
  set problemMessage($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasProblemMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearProblemMessage() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get offset => $_getIZ(2);
  @$pb.TagNumber(3)
  set offset($core.int v) {
    $_setSignedInt32(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasOffset() => $_has(2);
  @$pb.TagNumber(3)
  void clearOffset() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get length => $_getIZ(3);
  @$pb.TagNumber(4)
  set length($core.int v) {
    $_setSignedInt32(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasLength() => $_has(3);
  @$pb.TagNumber(4)
  void clearLength() => clearField(4);
}

/// Represents a possible way of solving an Analysis Problem.
class CandidateFix extends $pb.GeneratedMessage {
  factory CandidateFix({
    $core.String? message,
    $core.Iterable<SourceEdit>? edits,
    $core.int? selectionOffset,
    $core.Iterable<LinkedEditGroup>? linkedEditGroups,
  }) {
    final $result = create();
    if (message != null) {
      $result.message = message;
    }
    if (edits != null) {
      $result.edits.addAll(edits);
    }
    if (selectionOffset != null) {
      $result.selectionOffset = selectionOffset;
    }
    if (linkedEditGroups != null) {
      $result.linkedEditGroups.addAll(linkedEditGroups);
    }
    return $result;
  }
  CandidateFix._() : super();
  factory CandidateFix.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CandidateFix.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CandidateFix',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'message')
    ..pc<SourceEdit>(2, _omitFieldNames ? '' : 'edits', $pb.PbFieldType.PM,
        subBuilder: SourceEdit.create)
    ..a<$core.int>(
        3, _omitFieldNames ? '' : 'selectionOffset', $pb.PbFieldType.O3,
        protoName: 'selectionOffset')
    ..pc<LinkedEditGroup>(
        4, _omitFieldNames ? '' : 'linkedEditGroups', $pb.PbFieldType.PM,
        protoName: 'linkedEditGroups', subBuilder: LinkedEditGroup.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CandidateFix clone() => CandidateFix()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CandidateFix copyWith(void Function(CandidateFix) updates) =>
      super.copyWith((message) => updates(message as CandidateFix))
          as CandidateFix;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CandidateFix create() => CandidateFix._();
  CandidateFix createEmptyInstance() => create();
  static $pb.PbList<CandidateFix> createRepeated() =>
      $pb.PbList<CandidateFix>();
  @$core.pragma('dart2js:noInline')
  static CandidateFix getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CandidateFix>(create);
  static CandidateFix? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get message => $_getSZ(0);
  @$pb.TagNumber(1)
  set message($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<SourceEdit> get edits => $_getList(1);

  @$pb.TagNumber(3)
  $core.int get selectionOffset => $_getIZ(2);
  @$pb.TagNumber(3)
  set selectionOffset($core.int v) {
    $_setSignedInt32(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasSelectionOffset() => $_has(2);
  @$pb.TagNumber(3)
  void clearSelectionOffset() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<LinkedEditGroup> get linkedEditGroups => $_getList(3);
}

/// Represents a single edit-point change to a source file.
class SourceEdit extends $pb.GeneratedMessage {
  factory SourceEdit({
    $core.int? offset,
    $core.int? length,
    $core.String? replacement,
  }) {
    final $result = create();
    if (offset != null) {
      $result.offset = offset;
    }
    if (length != null) {
      $result.length = length;
    }
    if (replacement != null) {
      $result.replacement = replacement;
    }
    return $result;
  }
  SourceEdit._() : super();
  factory SourceEdit.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory SourceEdit.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SourceEdit',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'offset', $pb.PbFieldType.O3)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'length', $pb.PbFieldType.O3)
    ..aOS(3, _omitFieldNames ? '' : 'replacement')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  SourceEdit clone() => SourceEdit()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  SourceEdit copyWith(void Function(SourceEdit) updates) =>
      super.copyWith((message) => updates(message as SourceEdit)) as SourceEdit;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SourceEdit create() => SourceEdit._();
  SourceEdit createEmptyInstance() => create();
  static $pb.PbList<SourceEdit> createRepeated() => $pb.PbList<SourceEdit>();
  @$core.pragma('dart2js:noInline')
  static SourceEdit getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SourceEdit>(create);
  static SourceEdit? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get offset => $_getIZ(0);
  @$pb.TagNumber(1)
  set offset($core.int v) {
    $_setSignedInt32(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasOffset() => $_has(0);
  @$pb.TagNumber(1)
  void clearOffset() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get length => $_getIZ(1);
  @$pb.TagNumber(2)
  set length($core.int v) {
    $_setSignedInt32(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasLength() => $_has(1);
  @$pb.TagNumber(2)
  void clearLength() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get replacement => $_getSZ(2);
  @$pb.TagNumber(3)
  set replacement($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasReplacement() => $_has(2);
  @$pb.TagNumber(3)
  void clearReplacement() => clearField(3);
}

class LinkedEditGroup extends $pb.GeneratedMessage {
  factory LinkedEditGroup({
    $core.Iterable<$core.int>? positions,
    $core.int? length,
    $core.Iterable<LinkedEditSuggestion>? suggestions,
  }) {
    final $result = create();
    if (positions != null) {
      $result.positions.addAll(positions);
    }
    if (length != null) {
      $result.length = length;
    }
    if (suggestions != null) {
      $result.suggestions.addAll(suggestions);
    }
    return $result;
  }
  LinkedEditGroup._() : super();
  factory LinkedEditGroup.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory LinkedEditGroup.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LinkedEditGroup',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..p<$core.int>(1, _omitFieldNames ? '' : 'positions', $pb.PbFieldType.K3)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'length', $pb.PbFieldType.O3)
    ..pc<LinkedEditSuggestion>(
        3, _omitFieldNames ? '' : 'suggestions', $pb.PbFieldType.PM,
        subBuilder: LinkedEditSuggestion.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  LinkedEditGroup clone() => LinkedEditGroup()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  LinkedEditGroup copyWith(void Function(LinkedEditGroup) updates) =>
      super.copyWith((message) => updates(message as LinkedEditGroup))
          as LinkedEditGroup;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LinkedEditGroup create() => LinkedEditGroup._();
  LinkedEditGroup createEmptyInstance() => create();
  static $pb.PbList<LinkedEditGroup> createRepeated() =>
      $pb.PbList<LinkedEditGroup>();
  @$core.pragma('dart2js:noInline')
  static LinkedEditGroup getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LinkedEditGroup>(create);
  static LinkedEditGroup? _defaultInstance;

  /// The positions of the regions that should be edited simultaneously.
  @$pb.TagNumber(1)
  $core.List<$core.int> get positions => $_getList(0);

  /// The length of the regions that should be edited simultaneously.
  @$pb.TagNumber(2)
  $core.int get length => $_getIZ(1);
  @$pb.TagNumber(2)
  set length($core.int v) {
    $_setSignedInt32(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasLength() => $_has(1);
  @$pb.TagNumber(2)
  void clearLength() => clearField(2);

  /// Pre-computed suggestions for what every region might want to be changed to.
  @$pb.TagNumber(3)
  $core.List<LinkedEditSuggestion> get suggestions => $_getList(2);
}

class LinkedEditSuggestion extends $pb.GeneratedMessage {
  factory LinkedEditSuggestion({
    $core.String? value,
    $core.String? kind,
  }) {
    final $result = create();
    if (value != null) {
      $result.value = value;
    }
    if (kind != null) {
      $result.kind = kind;
    }
    return $result;
  }
  LinkedEditSuggestion._() : super();
  factory LinkedEditSuggestion.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory LinkedEditSuggestion.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LinkedEditSuggestion',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..aOS(2, _omitFieldNames ? '' : 'kind')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  LinkedEditSuggestion clone() =>
      LinkedEditSuggestion()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  LinkedEditSuggestion copyWith(void Function(LinkedEditSuggestion) updates) =>
      super.copyWith((message) => updates(message as LinkedEditSuggestion))
          as LinkedEditSuggestion;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LinkedEditSuggestion create() => LinkedEditSuggestion._();
  LinkedEditSuggestion createEmptyInstance() => create();
  static $pb.PbList<LinkedEditSuggestion> createRepeated() =>
      $pb.PbList<LinkedEditSuggestion>();
  @$core.pragma('dart2js:noInline')
  static LinkedEditSuggestion getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LinkedEditSuggestion>(create);
  static LinkedEditSuggestion? _defaultInstance;

  /// The value that could be used to replace all of the linked edit regions.
  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => clearField(1);

  /// The kind of value being proposed.
  @$pb.TagNumber(2)
  $core.String get kind => $_getSZ(1);
  @$pb.TagNumber(2)
  set kind($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => clearField(2);
}

/// Represents a reformatting of the code.
class FormatResponse extends $pb.GeneratedMessage {
  factory FormatResponse({
    $core.String? newString,
    $core.int? offset,
    ErrorMessage? error,
  }) {
    final $result = create();
    if (newString != null) {
      $result.newString = newString;
    }
    if (offset != null) {
      $result.offset = offset;
    }
    if (error != null) {
      $result.error = error;
    }
    return $result;
  }
  FormatResponse._() : super();
  factory FormatResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FormatResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FormatResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'newString', protoName: 'newString')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'offset', $pb.PbFieldType.O3)
    ..aOM<ErrorMessage>(99, _omitFieldNames ? '' : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  FormatResponse clone() => FormatResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  FormatResponse copyWith(void Function(FormatResponse) updates) =>
      super.copyWith((message) => updates(message as FormatResponse))
          as FormatResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FormatResponse create() => FormatResponse._();
  FormatResponse createEmptyInstance() => create();
  static $pb.PbList<FormatResponse> createRepeated() =>
      $pb.PbList<FormatResponse>();
  @$core.pragma('dart2js:noInline')
  static FormatResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FormatResponse>(create);
  static FormatResponse? _defaultInstance;

  /// The formatted source code.
  @$pb.TagNumber(1)
  $core.String get newString => $_getSZ(0);
  @$pb.TagNumber(1)
  set newString($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasNewString() => $_has(0);
  @$pb.TagNumber(1)
  void clearNewString() => clearField(1);

  /// The (optional) new offset of the cursor; can be `null`.
  @$pb.TagNumber(2)
  $core.int get offset => $_getIZ(1);
  @$pb.TagNumber(2)
  set offset($core.int v) {
    $_setSignedInt32(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasOffset() => $_has(1);
  @$pb.TagNumber(2)
  void clearOffset() => clearField(2);

  /// Make this response compatible with BadRequest
  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(2);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) {
    setField(99, v);
  }

  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(2);
}

/// The response from the `/assists` service call.
class AssistsResponse extends $pb.GeneratedMessage {
  factory AssistsResponse({
    $core.Iterable<CandidateFix>? assists,
    ErrorMessage? error,
  }) {
    final $result = create();
    if (assists != null) {
      $result.assists.addAll(assists);
    }
    if (error != null) {
      $result.error = error;
    }
    return $result;
  }
  AssistsResponse._() : super();
  factory AssistsResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory AssistsResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AssistsResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..pc<CandidateFix>(1, _omitFieldNames ? '' : 'assists', $pb.PbFieldType.PM,
        subBuilder: CandidateFix.create)
    ..aOM<ErrorMessage>(99, _omitFieldNames ? '' : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  AssistsResponse clone() => AssistsResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  AssistsResponse copyWith(void Function(AssistsResponse) updates) =>
      super.copyWith((message) => updates(message as AssistsResponse))
          as AssistsResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AssistsResponse create() => AssistsResponse._();
  AssistsResponse createEmptyInstance() => create();
  static $pb.PbList<AssistsResponse> createRepeated() =>
      $pb.PbList<AssistsResponse>();
  @$core.pragma('dart2js:noInline')
  static AssistsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AssistsResponse>(create);
  static AssistsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<CandidateFix> get assists => $_getList(0);

  /// Make this response compatible with BadRequest
  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(1);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) {
    setField(99, v);
  }

  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(1);
}

/// The response from the `/version` service call.
class VersionResponse extends $pb.GeneratedMessage {
  factory VersionResponse({
    $core.String? sdkVersion,
    $core.String? sdkVersionFull,
    @$core.Deprecated('This field is deprecated.') $core.String? runtimeVersion,
    @$core.Deprecated('This field is deprecated.')
    $core.String? appEngineVersion,
    @$core.Deprecated('This field is deprecated.')
    $core.String? servicesVersion,
    $core.String? flutterVersion,
    @$core.Deprecated('This field is deprecated.')
    $core.String? flutterDartVersion,
    @$core.Deprecated('This field is deprecated.')
    $core.String? flutterDartVersionFull,
    @$core.Deprecated('This field is deprecated.')
    $core.Map<$core.String, $core.String>? packageVersions,
    $core.Iterable<PackageInfo>? packageInfo,
    $core.Iterable<$core.String>? experiment,
    $core.String? flutterEngineSha,
    ErrorMessage? error,
  }) {
    final $result = create();
    if (sdkVersion != null) {
      $result.sdkVersion = sdkVersion;
    }
    if (sdkVersionFull != null) {
      $result.sdkVersionFull = sdkVersionFull;
    }
    if (runtimeVersion != null) {
      // ignore: deprecated_member_use_from_same_package
      $result.runtimeVersion = runtimeVersion;
    }
    if (appEngineVersion != null) {
      // ignore: deprecated_member_use_from_same_package
      $result.appEngineVersion = appEngineVersion;
    }
    if (servicesVersion != null) {
      // ignore: deprecated_member_use_from_same_package
      $result.servicesVersion = servicesVersion;
    }
    if (flutterVersion != null) {
      $result.flutterVersion = flutterVersion;
    }
    if (flutterDartVersion != null) {
      // ignore: deprecated_member_use_from_same_package
      $result.flutterDartVersion = flutterDartVersion;
    }
    if (flutterDartVersionFull != null) {
      // ignore: deprecated_member_use_from_same_package
      $result.flutterDartVersionFull = flutterDartVersionFull;
    }
    if (packageVersions != null) {
      // ignore: deprecated_member_use_from_same_package
      $result.packageVersions.addAll(packageVersions);
    }
    if (packageInfo != null) {
      $result.packageInfo.addAll(packageInfo);
    }
    if (experiment != null) {
      $result.experiment.addAll(experiment);
    }
    if (flutterEngineSha != null) {
      $result.flutterEngineSha = flutterEngineSha;
    }
    if (error != null) {
      $result.error = error;
    }
    return $result;
  }
  VersionResponse._() : super();
  factory VersionResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory VersionResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VersionResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sdkVersion', protoName: 'sdkVersion')
    ..aOS(2, _omitFieldNames ? '' : 'sdkVersionFull',
        protoName: 'sdkVersionFull')
    ..aOS(3, _omitFieldNames ? '' : 'runtimeVersion',
        protoName: 'runtimeVersion')
    ..aOS(4, _omitFieldNames ? '' : 'appEngineVersion',
        protoName: 'appEngineVersion')
    ..aOS(5, _omitFieldNames ? '' : 'servicesVersion',
        protoName: 'servicesVersion')
    ..aOS(6, _omitFieldNames ? '' : 'flutterVersion',
        protoName: 'flutterVersion')
    ..aOS(7, _omitFieldNames ? '' : 'flutterDartVersion',
        protoName: 'flutterDartVersion')
    ..aOS(8, _omitFieldNames ? '' : 'flutterDartVersionFull',
        protoName: 'flutterDartVersionFull')
    ..m<$core.String, $core.String>(9, _omitFieldNames ? '' : 'packageVersions',
        protoName: 'packageVersions',
        entryClassName: 'VersionResponse.PackageVersionsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('dart_services.api'))
    ..pc<PackageInfo>(
        10, _omitFieldNames ? '' : 'packageInfo', $pb.PbFieldType.PM,
        protoName: 'packageInfo', subBuilder: PackageInfo.create)
    ..pPS(11, _omitFieldNames ? '' : 'experiment')
    ..aOS(12, _omitFieldNames ? '' : 'flutterEngineSha',
        protoName: 'flutterEngineSha')
    ..aOM<ErrorMessage>(99, _omitFieldNames ? '' : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  VersionResponse clone() => VersionResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  VersionResponse copyWith(void Function(VersionResponse) updates) =>
      super.copyWith((message) => updates(message as VersionResponse))
          as VersionResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static VersionResponse create() => VersionResponse._();
  VersionResponse createEmptyInstance() => create();
  static $pb.PbList<VersionResponse> createRepeated() =>
      $pb.PbList<VersionResponse>();
  @$core.pragma('dart2js:noInline')
  static VersionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<VersionResponse>(create);
  static VersionResponse? _defaultInstance;

  /// The Dart SDK version.
  @$pb.TagNumber(1)
  $core.String get sdkVersion => $_getSZ(0);
  @$pb.TagNumber(1)
  set sdkVersion($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasSdkVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearSdkVersion() => clearField(1);

  ///  The full string of the Dart SDK version, including any channel name.
  ///
  ///  E.g., `3.1.0-262.2.beta` vs `3.1.0`.
  @$pb.TagNumber(2)
  $core.String get sdkVersionFull => $_getSZ(1);
  @$pb.TagNumber(2)
  set sdkVersionFull($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasSdkVersionFull() => $_has(1);
  @$pb.TagNumber(2)
  void clearSdkVersionFull() => clearField(2);

  /// Removed.
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(3)
  $core.String get runtimeVersion => $_getSZ(2);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(3)
  set runtimeVersion($core.String v) {
    $_setString(2, v);
  }

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(3)
  $core.bool hasRuntimeVersion() => $_has(2);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(3)
  void clearRuntimeVersion() => clearField(3);

  /// Removed.
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(4)
  $core.String get appEngineVersion => $_getSZ(3);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(4)
  set appEngineVersion($core.String v) {
    $_setString(3, v);
  }

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(4)
  $core.bool hasAppEngineVersion() => $_has(3);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(4)
  void clearAppEngineVersion() => clearField(4);

  /// Removed.
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(5)
  $core.String get servicesVersion => $_getSZ(4);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(5)
  set servicesVersion($core.String v) {
    $_setString(4, v);
  }

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(5)
  $core.bool hasServicesVersion() => $_has(4);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(5)
  void clearServicesVersion() => clearField(5);

  /// The Flutter SDK version.
  @$pb.TagNumber(6)
  $core.String get flutterVersion => $_getSZ(5);
  @$pb.TagNumber(6)
  set flutterVersion($core.String v) {
    $_setString(5, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasFlutterVersion() => $_has(5);
  @$pb.TagNumber(6)
  void clearFlutterVersion() => clearField(6);

  /// Removed.
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(7)
  $core.String get flutterDartVersion => $_getSZ(6);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(7)
  set flutterDartVersion($core.String v) {
    $_setString(6, v);
  }

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(7)
  $core.bool hasFlutterDartVersion() => $_has(6);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(7)
  void clearFlutterDartVersion() => clearField(7);

  /// Removed.
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(8)
  $core.String get flutterDartVersionFull => $_getSZ(7);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(8)
  set flutterDartVersionFull($core.String v) {
    $_setString(7, v);
  }

  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(8)
  $core.bool hasFlutterDartVersionFull() => $_has(7);
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(8)
  void clearFlutterDartVersionFull() => clearField(8);

  /// Removed.
  @$core.Deprecated('This field is deprecated.')
  @$pb.TagNumber(9)
  $core.Map<$core.String, $core.String> get packageVersions => $_getMap(8);

  /// Package information; each package found in `pubspec.lock` is included.
  @$pb.TagNumber(10)
  $core.List<PackageInfo> get packageInfo => $_getList(9);

  /// Experiments that this server is running.
  @$pb.TagNumber(11)
  $core.List<$core.String> get experiment => $_getList(10);

  /// The Flutter engine SHA, located in bin/internal/engine.version.
  @$pb.TagNumber(12)
  $core.String get flutterEngineSha => $_getSZ(11);
  @$pb.TagNumber(12)
  set flutterEngineSha($core.String v) {
    $_setString(11, v);
  }

  @$pb.TagNumber(12)
  $core.bool hasFlutterEngineSha() => $_has(11);
  @$pb.TagNumber(12)
  void clearFlutterEngineSha() => clearField(12);

  /// Make this response compatible with BadRequest
  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(12);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) {
    setField(99, v);
  }

  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(12);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(12);
}

class PackageInfo extends $pb.GeneratedMessage {
  factory PackageInfo({
    $core.String? name,
    $core.String? version,
    $core.bool? supported,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (version != null) {
      $result.version = version;
    }
    if (supported != null) {
      $result.supported = supported;
    }
    return $result;
  }
  PackageInfo._() : super();
  factory PackageInfo.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory PackageInfo.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PackageInfo',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'version')
    ..aOB(3, _omitFieldNames ? '' : 'supported')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  PackageInfo clone() => PackageInfo()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  PackageInfo copyWith(void Function(PackageInfo) updates) =>
      super.copyWith((message) => updates(message as PackageInfo))
          as PackageInfo;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PackageInfo create() => PackageInfo._();
  PackageInfo createEmptyInstance() => create();
  static $pb.PbList<PackageInfo> createRepeated() => $pb.PbList<PackageInfo>();
  @$core.pragma('dart2js:noInline')
  static PackageInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PackageInfo>(create);
  static PackageInfo? _defaultInstance;

  /// The name of this package.
  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  /// The selected version of this package.
  @$pb.TagNumber(2)
  $core.String get version => $_getSZ(1);
  @$pb.TagNumber(2)
  set version($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearVersion() => clearField(2);

  /// Whether this package is supported as a directly importable package,
  /// or simply available as a transitive dependency of a supported package.
  @$pb.TagNumber(3)
  $core.bool get supported => $_getBF(2);
  @$pb.TagNumber(3)
  set supported($core.bool v) {
    $_setBool(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasSupported() => $_has(2);
  @$pb.TagNumber(3)
  void clearSupported() => clearField(3);
}

/// Response from the server when errors are thrown internally
class BadRequest extends $pb.GeneratedMessage {
  factory BadRequest({
    ErrorMessage? error,
  }) {
    final $result = create();
    if (error != null) {
      $result.error = error;
    }
    return $result;
  }
  BadRequest._() : super();
  factory BadRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory BadRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BadRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOM<ErrorMessage>(99, _omitFieldNames ? '' : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  BadRequest clone() => BadRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  BadRequest copyWith(void Function(BadRequest) updates) =>
      super.copyWith((message) => updates(message as BadRequest)) as BadRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BadRequest create() => BadRequest._();
  BadRequest createEmptyInstance() => create();
  static $pb.PbList<BadRequest> createRepeated() => $pb.PbList<BadRequest>();
  @$core.pragma('dart2js:noInline')
  static BadRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BadRequest>(create);
  static BadRequest? _defaultInstance;

  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(0);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) {
    setField(99, v);
  }

  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(0);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(0);
}

/// Individual error messages.
class ErrorMessage extends $pb.GeneratedMessage {
  factory ErrorMessage({
    $core.String? message,
  }) {
    final $result = create();
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  ErrorMessage._() : super();
  factory ErrorMessage.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ErrorMessage.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ErrorMessage',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  ErrorMessage clone() => ErrorMessage()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  ErrorMessage copyWith(void Function(ErrorMessage) updates) =>
      super.copyWith((message) => updates(message as ErrorMessage))
          as ErrorMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ErrorMessage create() => ErrorMessage._();
  ErrorMessage createEmptyInstance() => create();
  static $pb.PbList<ErrorMessage> createRepeated() =>
      $pb.PbList<ErrorMessage>();
  @$core.pragma('dart2js:noInline')
  static ErrorMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ErrorMessage>(create);
  static ErrorMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get message => $_getSZ(0);
  @$pb.TagNumber(1)
  set message($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => clearField(1);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');

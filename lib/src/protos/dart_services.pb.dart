///
//  Generated code. Do not modify.
//  source: protos/dart_services.proto
//
// @dart = 2.12
// ignore_for_file: annotate_overrides,camel_case_types,unnecessary_const,non_constant_identifier_names,library_prefixes,unused_import,unused_shown_name,return_of_invalid_type,unnecessary_this,prefer_final_fields

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class CompileRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'CompileRequest',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'source')
    ..aOB(
        2,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'returnSourceMap',
        protoName: 'returnSourceMap')
    ..hasRequiredFields = false;

  CompileRequest._() : super();
  factory CompileRequest({
    $core.String? source,
    $core.bool? returnSourceMap,
  }) {
    final _result = create();
    if (source != null) {
      _result.source = source;
    }
    if (returnSourceMap != null) {
      _result.returnSourceMap = returnSourceMap;
    }
    return _result;
  }
  factory CompileRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CompileRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CompileRequest clone() => CompileRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CompileRequest copyWith(void Function(CompileRequest) updates) =>
      super.copyWith((message) => updates(message as CompileRequest))
          as CompileRequest; // ignore: deprecated_member_use
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

class CompileFilesRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'CompileFilesRequest',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..m<$core.String, $core.String>(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'files',
        entryClassName: 'CompileFilesRequest.FilesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('dart_services.api'))
    ..aOB(
        2,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'returnSourceMap',
        protoName: 'returnSourceMap')
    ..hasRequiredFields = false;

  CompileFilesRequest._() : super();
  factory CompileFilesRequest({
    $core.Map<$core.String, $core.String>? files,
    $core.bool? returnSourceMap,
  }) {
    final _result = create();
    if (files != null) {
      _result.files.addAll(files);
    }
    if (returnSourceMap != null) {
      _result.returnSourceMap = returnSourceMap;
    }
    return _result;
  }
  factory CompileFilesRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CompileFilesRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CompileFilesRequest clone() => CompileFilesRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CompileFilesRequest copyWith(void Function(CompileFilesRequest) updates) =>
      super.copyWith((message) => updates(message as CompileFilesRequest))
          as CompileFilesRequest; // ignore: deprecated_member_use
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

  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get files => $_getMap(0);

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
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'CompileDDCRequest',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'source')
    ..hasRequiredFields = false;

  CompileDDCRequest._() : super();
  factory CompileDDCRequest({
    $core.String? source,
  }) {
    final _result = create();
    if (source != null) {
      _result.source = source;
    }
    return _result;
  }
  factory CompileDDCRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CompileDDCRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CompileDDCRequest clone() => CompileDDCRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CompileDDCRequest copyWith(void Function(CompileDDCRequest) updates) =>
      super.copyWith((message) => updates(message as CompileDDCRequest))
          as CompileDDCRequest; // ignore: deprecated_member_use
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

class CompileFilesDDCRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'CompileFilesDDCRequest',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..m<$core.String, $core.String>(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'files',
        entryClassName: 'CompileFilesDDCRequest.FilesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('dart_services.api'))
    ..hasRequiredFields = false;

  CompileFilesDDCRequest._() : super();
  factory CompileFilesDDCRequest({
    $core.Map<$core.String, $core.String>? files,
  }) {
    final _result = create();
    if (files != null) {
      _result.files.addAll(files);
    }
    return _result;
  }
  factory CompileFilesDDCRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CompileFilesDDCRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
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
          as CompileFilesDDCRequest; // ignore: deprecated_member_use
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

  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get files => $_getMap(0);
}

class SourceRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'SourceRequest',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'source')
    ..a<$core.int>(
        2,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'offset',
        $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  SourceRequest._() : super();
  factory SourceRequest({
    $core.String? source,
    $core.int? offset,
  }) {
    final _result = create();
    if (source != null) {
      _result.source = source;
    }
    if (offset != null) {
      _result.offset = offset;
    }
    return _result;
  }
  factory SourceRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory SourceRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  SourceRequest clone() => SourceRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  SourceRequest copyWith(void Function(SourceRequest) updates) =>
      super.copyWith((message) => updates(message as SourceRequest))
          as SourceRequest; // ignore: deprecated_member_use
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

class SourceFilesRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'SourceFilesRequest',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..m<$core.String, $core.String>(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'files',
        entryClassName: 'SourceFilesRequest.FilesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('dart_services.api'))
    ..aOS(
        2,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'activeSourceName',
        protoName: 'activeSourceName')
    ..a<$core.int>(
        3,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'offset',
        $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  SourceFilesRequest._() : super();
  factory SourceFilesRequest({
    $core.Map<$core.String, $core.String>? files,
    $core.String? activeSourceName,
    $core.int? offset,
  }) {
    final _result = create();
    if (files != null) {
      _result.files.addAll(files);
    }
    if (activeSourceName != null) {
      _result.activeSourceName = activeSourceName;
    }
    if (offset != null) {
      _result.offset = offset;
    }
    return _result;
  }
  factory SourceFilesRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory SourceFilesRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  SourceFilesRequest clone() => SourceFilesRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  SourceFilesRequest copyWith(void Function(SourceFilesRequest) updates) =>
      super.copyWith((message) => updates(message as SourceFilesRequest))
          as SourceFilesRequest; // ignore: deprecated_member_use
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

  @$pb.TagNumber(1)
  $core.Map<$core.String, $core.String> get files => $_getMap(0);

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
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'AnalysisResults',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..pc<AnalysisIssue>(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'issues',
        $pb.PbFieldType.PM,
        subBuilder: AnalysisIssue.create)
    ..pPS(
        2,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'packageImports',
        protoName: 'packageImports')
    ..aOM<ErrorMessage>(
        99,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  AnalysisResults._() : super();
  factory AnalysisResults({
    $core.Iterable<AnalysisIssue>? issues,
    $core.Iterable<$core.String>? packageImports,
    ErrorMessage? error,
  }) {
    final _result = create();
    if (issues != null) {
      _result.issues.addAll(issues);
    }
    if (packageImports != null) {
      _result.packageImports.addAll(packageImports);
    }
    if (error != null) {
      _result.error = error;
    }
    return _result;
  }
  factory AnalysisResults.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory AnalysisResults.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  AnalysisResults clone() => AnalysisResults()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  AnalysisResults copyWith(void Function(AnalysisResults) updates) =>
      super.copyWith((message) => updates(message as AnalysisResults))
          as AnalysisResults; // ignore: deprecated_member_use
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

  @$pb.TagNumber(2)
  $core.List<$core.String> get packageImports => $_getList(1);

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
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'AnalysisIssue',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'kind')
    ..a<$core.int>(
        2,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'line',
        $pb.PbFieldType.O3)
    ..aOS(
        3,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'message')
    ..aOS(
        4,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'sourceName',
        protoName: 'sourceName')
    ..aOB(
        5,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'hasFixes',
        protoName: 'hasFixes')
    ..a<$core.int>(
        6,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'charStart',
        $pb.PbFieldType.O3,
        protoName: 'charStart')
    ..a<$core.int>(
        7,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'charLength',
        $pb.PbFieldType.O3,
        protoName: 'charLength')
    ..aOS(
        8,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'url')
    ..pc<DiagnosticMessage>(
        9,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'diagnosticMessages',
        $pb.PbFieldType.PM,
        protoName: 'diagnosticMessages',
        subBuilder: DiagnosticMessage.create)
    ..aOS(
        10,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'correction')
    ..hasRequiredFields = false;

  AnalysisIssue._() : super();
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
  }) {
    final _result = create();
    if (kind != null) {
      _result.kind = kind;
    }
    if (line != null) {
      _result.line = line;
    }
    if (message != null) {
      _result.message = message;
    }
    if (sourceName != null) {
      _result.sourceName = sourceName;
    }
    if (hasFixes != null) {
      _result.hasFixes = hasFixes;
    }
    if (charStart != null) {
      _result.charStart = charStart;
    }
    if (charLength != null) {
      _result.charLength = charLength;
    }
    if (url != null) {
      _result.url = url;
    }
    if (diagnosticMessages != null) {
      _result.diagnosticMessages.addAll(diagnosticMessages);
    }
    if (correction != null) {
      _result.correction = correction;
    }
    return _result;
  }
  factory AnalysisIssue.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory AnalysisIssue.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  AnalysisIssue clone() => AnalysisIssue()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  AnalysisIssue copyWith(void Function(AnalysisIssue) updates) =>
      super.copyWith((message) => updates(message as AnalysisIssue))
          as AnalysisIssue; // ignore: deprecated_member_use
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
}

class DiagnosticMessage extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'DiagnosticMessage',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'message')
    ..a<$core.int>(
        2,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'line',
        $pb.PbFieldType.O3)
    ..a<$core.int>(
        3,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'charStart',
        $pb.PbFieldType.O3,
        protoName: 'charStart')
    ..a<$core.int>(
        4,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'charLength',
        $pb.PbFieldType.O3,
        protoName: 'charLength')
    ..hasRequiredFields = false;

  DiagnosticMessage._() : super();
  factory DiagnosticMessage({
    $core.String? message,
    $core.int? line,
    $core.int? charStart,
    $core.int? charLength,
  }) {
    final _result = create();
    if (message != null) {
      _result.message = message;
    }
    if (line != null) {
      _result.line = line;
    }
    if (charStart != null) {
      _result.charStart = charStart;
    }
    if (charLength != null) {
      _result.charLength = charLength;
    }
    return _result;
  }
  factory DiagnosticMessage.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory DiagnosticMessage.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  DiagnosticMessage clone() => DiagnosticMessage()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  DiagnosticMessage copyWith(void Function(DiagnosticMessage) updates) =>
      super.copyWith((message) => updates(message as DiagnosticMessage))
          as DiagnosticMessage; // ignore: deprecated_member_use
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
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'VersionRequest',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  VersionRequest._() : super();
  factory VersionRequest() => create();
  factory VersionRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory VersionRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  VersionRequest clone() => VersionRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  VersionRequest copyWith(void Function(VersionRequest) updates) =>
      super.copyWith((message) => updates(message as VersionRequest))
          as VersionRequest; // ignore: deprecated_member_use
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
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'CompileResponse',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'result')
    ..aOS(
        2,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'sourceMap',
        protoName: 'sourceMap')
    ..aOM<ErrorMessage>(
        99,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  CompileResponse._() : super();
  factory CompileResponse({
    $core.String? result,
    $core.String? sourceMap,
    ErrorMessage? error,
  }) {
    final _result = create();
    if (result != null) {
      _result.result = result;
    }
    if (sourceMap != null) {
      _result.sourceMap = sourceMap;
    }
    if (error != null) {
      _result.error = error;
    }
    return _result;
  }
  factory CompileResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CompileResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CompileResponse clone() => CompileResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CompileResponse copyWith(void Function(CompileResponse) updates) =>
      super.copyWith((message) => updates(message as CompileResponse))
          as CompileResponse; // ignore: deprecated_member_use
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
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'CompileDDCResponse',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'result')
    ..aOS(
        2,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'modulesBaseUrl',
        protoName: 'modulesBaseUrl')
    ..aOM<ErrorMessage>(
        99,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  CompileDDCResponse._() : super();
  factory CompileDDCResponse({
    $core.String? result,
    $core.String? modulesBaseUrl,
    ErrorMessage? error,
  }) {
    final _result = create();
    if (result != null) {
      _result.result = result;
    }
    if (modulesBaseUrl != null) {
      _result.modulesBaseUrl = modulesBaseUrl;
    }
    if (error != null) {
      _result.error = error;
    }
    return _result;
  }
  factory CompileDDCResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CompileDDCResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CompileDDCResponse clone() => CompileDDCResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CompileDDCResponse copyWith(void Function(CompileDDCResponse) updates) =>
      super.copyWith((message) => updates(message as CompileDDCResponse))
          as CompileDDCResponse; // ignore: deprecated_member_use
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
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'DocumentResponse',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..m<$core.String, $core.String>(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'info',
        entryClassName: 'DocumentResponse.InfoEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('dart_services.api'))
    ..aOM<ErrorMessage>(
        99,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  DocumentResponse._() : super();
  factory DocumentResponse({
    $core.Map<$core.String, $core.String>? info,
    ErrorMessage? error,
  }) {
    final _result = create();
    if (info != null) {
      _result.info.addAll(info);
    }
    if (error != null) {
      _result.error = error;
    }
    return _result;
  }
  factory DocumentResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory DocumentResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  DocumentResponse clone() => DocumentResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  DocumentResponse copyWith(void Function(DocumentResponse) updates) =>
      super.copyWith((message) => updates(message as DocumentResponse))
          as DocumentResponse; // ignore: deprecated_member_use
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
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'CompleteResponse',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..a<$core.int>(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'replacementOffset',
        $pb.PbFieldType.O3,
        protoName: 'replacementOffset')
    ..a<$core.int>(
        2,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'replacementLength',
        $pb.PbFieldType.O3,
        protoName: 'replacementLength')
    ..pc<Completion>(
        3,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'completions',
        $pb.PbFieldType.PM,
        subBuilder: Completion.create)
    ..aOM<ErrorMessage>(
        99,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  CompleteResponse._() : super();
  factory CompleteResponse({
    $core.int? replacementOffset,
    $core.int? replacementLength,
    $core.Iterable<Completion>? completions,
    ErrorMessage? error,
  }) {
    final _result = create();
    if (replacementOffset != null) {
      _result.replacementOffset = replacementOffset;
    }
    if (replacementLength != null) {
      _result.replacementLength = replacementLength;
    }
    if (completions != null) {
      _result.completions.addAll(completions);
    }
    if (error != null) {
      _result.error = error;
    }
    return _result;
  }
  factory CompleteResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CompleteResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CompleteResponse clone() => CompleteResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CompleteResponse copyWith(void Function(CompleteResponse) updates) =>
      super.copyWith((message) => updates(message as CompleteResponse))
          as CompleteResponse; // ignore: deprecated_member_use
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
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'Completion',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..m<$core.String, $core.String>(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'completion',
        entryClassName: 'Completion.CompletionEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('dart_services.api'))
    ..hasRequiredFields = false;

  Completion._() : super();
  factory Completion({
    $core.Map<$core.String, $core.String>? completion,
  }) {
    final _result = create();
    if (completion != null) {
      _result.completion.addAll(completion);
    }
    return _result;
  }
  factory Completion.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Completion.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Completion clone() => Completion()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Completion copyWith(void Function(Completion) updates) =>
      super.copyWith((message) => updates(message as Completion))
          as Completion; // ignore: deprecated_member_use
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
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'FixesResponse',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..pc<ProblemAndFixes>(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'fixes',
        $pb.PbFieldType.PM,
        subBuilder: ProblemAndFixes.create)
    ..aOM<ErrorMessage>(
        99,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  FixesResponse._() : super();
  factory FixesResponse({
    $core.Iterable<ProblemAndFixes>? fixes,
    ErrorMessage? error,
  }) {
    final _result = create();
    if (fixes != null) {
      _result.fixes.addAll(fixes);
    }
    if (error != null) {
      _result.error = error;
    }
    return _result;
  }
  factory FixesResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FixesResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  FixesResponse clone() => FixesResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  FixesResponse copyWith(void Function(FixesResponse) updates) =>
      super.copyWith((message) => updates(message as FixesResponse))
          as FixesResponse; // ignore: deprecated_member_use
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

class ProblemAndFixes extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'ProblemAndFixes',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..pc<CandidateFix>(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'fixes',
        $pb.PbFieldType.PM,
        subBuilder: CandidateFix.create)
    ..aOS(
        2,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'problemMessage',
        protoName: 'problemMessage')
    ..a<$core.int>(
        3,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'offset',
        $pb.PbFieldType.O3)
    ..a<$core.int>(
        4,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'length',
        $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  ProblemAndFixes._() : super();
  factory ProblemAndFixes({
    $core.Iterable<CandidateFix>? fixes,
    $core.String? problemMessage,
    $core.int? offset,
    $core.int? length,
  }) {
    final _result = create();
    if (fixes != null) {
      _result.fixes.addAll(fixes);
    }
    if (problemMessage != null) {
      _result.problemMessage = problemMessage;
    }
    if (offset != null) {
      _result.offset = offset;
    }
    if (length != null) {
      _result.length = length;
    }
    return _result;
  }
  factory ProblemAndFixes.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ProblemAndFixes.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  ProblemAndFixes clone() => ProblemAndFixes()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  ProblemAndFixes copyWith(void Function(ProblemAndFixes) updates) =>
      super.copyWith((message) => updates(message as ProblemAndFixes))
          as ProblemAndFixes; // ignore: deprecated_member_use
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

class CandidateFix extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'CandidateFix',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'message')
    ..pc<SourceEdit>(
        2,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'edits',
        $pb.PbFieldType.PM,
        subBuilder: SourceEdit.create)
    ..a<$core.int>(
        3,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'selectionOffset',
        $pb.PbFieldType.O3,
        protoName: 'selectionOffset')
    ..pc<LinkedEditGroup>(
        4,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'linkedEditGroups',
        $pb.PbFieldType.PM,
        protoName: 'linkedEditGroups',
        subBuilder: LinkedEditGroup.create)
    ..hasRequiredFields = false;

  CandidateFix._() : super();
  factory CandidateFix({
    $core.String? message,
    $core.Iterable<SourceEdit>? edits,
    $core.int? selectionOffset,
    $core.Iterable<LinkedEditGroup>? linkedEditGroups,
  }) {
    final _result = create();
    if (message != null) {
      _result.message = message;
    }
    if (edits != null) {
      _result.edits.addAll(edits);
    }
    if (selectionOffset != null) {
      _result.selectionOffset = selectionOffset;
    }
    if (linkedEditGroups != null) {
      _result.linkedEditGroups.addAll(linkedEditGroups);
    }
    return _result;
  }
  factory CandidateFix.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory CandidateFix.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  CandidateFix clone() => CandidateFix()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  CandidateFix copyWith(void Function(CandidateFix) updates) =>
      super.copyWith((message) => updates(message as CandidateFix))
          as CandidateFix; // ignore: deprecated_member_use
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

class SourceEdit extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'SourceEdit',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..a<$core.int>(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'offset',
        $pb.PbFieldType.O3)
    ..a<$core.int>(
        2,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'length',
        $pb.PbFieldType.O3)
    ..aOS(
        3,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'replacement')
    ..hasRequiredFields = false;

  SourceEdit._() : super();
  factory SourceEdit({
    $core.int? offset,
    $core.int? length,
    $core.String? replacement,
  }) {
    final _result = create();
    if (offset != null) {
      _result.offset = offset;
    }
    if (length != null) {
      _result.length = length;
    }
    if (replacement != null) {
      _result.replacement = replacement;
    }
    return _result;
  }
  factory SourceEdit.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory SourceEdit.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  SourceEdit clone() => SourceEdit()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  SourceEdit copyWith(void Function(SourceEdit) updates) =>
      super.copyWith((message) => updates(message as SourceEdit))
          as SourceEdit; // ignore: deprecated_member_use
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
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'LinkedEditGroup',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..p<$core.int>(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'positions',
        $pb.PbFieldType.P3)
    ..a<$core.int>(
        2,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'length',
        $pb.PbFieldType.O3)
    ..pc<LinkedEditSuggestion>(
        3,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'suggestions',
        $pb.PbFieldType.PM,
        subBuilder: LinkedEditSuggestion.create)
    ..hasRequiredFields = false;

  LinkedEditGroup._() : super();
  factory LinkedEditGroup({
    $core.Iterable<$core.int>? positions,
    $core.int? length,
    $core.Iterable<LinkedEditSuggestion>? suggestions,
  }) {
    final _result = create();
    if (positions != null) {
      _result.positions.addAll(positions);
    }
    if (length != null) {
      _result.length = length;
    }
    if (suggestions != null) {
      _result.suggestions.addAll(suggestions);
    }
    return _result;
  }
  factory LinkedEditGroup.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory LinkedEditGroup.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  LinkedEditGroup clone() => LinkedEditGroup()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  LinkedEditGroup copyWith(void Function(LinkedEditGroup) updates) =>
      super.copyWith((message) => updates(message as LinkedEditGroup))
          as LinkedEditGroup; // ignore: deprecated_member_use
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

  @$pb.TagNumber(1)
  $core.List<$core.int> get positions => $_getList(0);

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
  $core.List<LinkedEditSuggestion> get suggestions => $_getList(2);
}

class LinkedEditSuggestion extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'LinkedEditSuggestion',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'value')
    ..aOS(
        2,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'kind')
    ..hasRequiredFields = false;

  LinkedEditSuggestion._() : super();
  factory LinkedEditSuggestion({
    $core.String? value,
    $core.String? kind,
  }) {
    final _result = create();
    if (value != null) {
      _result.value = value;
    }
    if (kind != null) {
      _result.kind = kind;
    }
    return _result;
  }
  factory LinkedEditSuggestion.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory LinkedEditSuggestion.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
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
          as LinkedEditSuggestion; // ignore: deprecated_member_use
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

class FormatResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'FormatResponse',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'newString',
        protoName: 'newString')
    ..a<$core.int>(
        2,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'offset',
        $pb.PbFieldType.O3)
    ..aOM<ErrorMessage>(
        99,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  FormatResponse._() : super();
  factory FormatResponse({
    $core.String? newString,
    $core.int? offset,
    ErrorMessage? error,
  }) {
    final _result = create();
    if (newString != null) {
      _result.newString = newString;
    }
    if (offset != null) {
      _result.offset = offset;
    }
    if (error != null) {
      _result.error = error;
    }
    return _result;
  }
  factory FormatResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory FormatResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  FormatResponse clone() => FormatResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  FormatResponse copyWith(void Function(FormatResponse) updates) =>
      super.copyWith((message) => updates(message as FormatResponse))
          as FormatResponse; // ignore: deprecated_member_use
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

class AssistsResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'AssistsResponse',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..pc<CandidateFix>(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'assists',
        $pb.PbFieldType.PM,
        subBuilder: CandidateFix.create)
    ..aOM<ErrorMessage>(
        99,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  AssistsResponse._() : super();
  factory AssistsResponse({
    $core.Iterable<CandidateFix>? assists,
    ErrorMessage? error,
  }) {
    final _result = create();
    if (assists != null) {
      _result.assists.addAll(assists);
    }
    if (error != null) {
      _result.error = error;
    }
    return _result;
  }
  factory AssistsResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory AssistsResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  AssistsResponse clone() => AssistsResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  AssistsResponse copyWith(void Function(AssistsResponse) updates) =>
      super.copyWith((message) => updates(message as AssistsResponse))
          as AssistsResponse; // ignore: deprecated_member_use
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

class VersionResponse extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'VersionResponse',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'sdkVersion',
        protoName: 'sdkVersion')
    ..aOS(
        2,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'sdkVersionFull',
        protoName: 'sdkVersionFull')
    ..aOS(
        3,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'runtimeVersion',
        protoName: 'runtimeVersion')
    ..aOS(
        4,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'appEngineVersion',
        protoName: 'appEngineVersion')
    ..aOS(
        5,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'servicesVersion',
        protoName: 'servicesVersion')
    ..aOS(
        6,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'flutterVersion',
        protoName: 'flutterVersion')
    ..aOS(
        7,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'flutterDartVersion',
        protoName: 'flutterDartVersion')
    ..aOS(
        8,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'flutterDartVersionFull',
        protoName: 'flutterDartVersionFull')
    ..m<$core.String, $core.String>(
        9,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'packageVersions',
        protoName: 'packageVersions',
        entryClassName: 'VersionResponse.PackageVersionsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('dart_services.api'))
    ..pc<PackageInfo>(
        10,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'packageInfo',
        $pb.PbFieldType.PM,
        protoName: 'packageInfo',
        subBuilder: PackageInfo.create)
    ..aOM<ErrorMessage>(
        99,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  VersionResponse._() : super();
  factory VersionResponse({
    $core.String? sdkVersion,
    $core.String? sdkVersionFull,
    $core.String? runtimeVersion,
    $core.String? appEngineVersion,
    $core.String? servicesVersion,
    $core.String? flutterVersion,
    $core.String? flutterDartVersion,
    $core.String? flutterDartVersionFull,
    $core.Map<$core.String, $core.String>? packageVersions,
    $core.Iterable<PackageInfo>? packageInfo,
    ErrorMessage? error,
  }) {
    final _result = create();
    if (sdkVersion != null) {
      _result.sdkVersion = sdkVersion;
    }
    if (sdkVersionFull != null) {
      _result.sdkVersionFull = sdkVersionFull;
    }
    if (runtimeVersion != null) {
      _result.runtimeVersion = runtimeVersion;
    }
    if (appEngineVersion != null) {
      _result.appEngineVersion = appEngineVersion;
    }
    if (servicesVersion != null) {
      _result.servicesVersion = servicesVersion;
    }
    if (flutterVersion != null) {
      _result.flutterVersion = flutterVersion;
    }
    if (flutterDartVersion != null) {
      _result.flutterDartVersion = flutterDartVersion;
    }
    if (flutterDartVersionFull != null) {
      _result.flutterDartVersionFull = flutterDartVersionFull;
    }
    if (packageVersions != null) {
      _result.packageVersions.addAll(packageVersions);
    }
    if (packageInfo != null) {
      _result.packageInfo.addAll(packageInfo);
    }
    if (error != null) {
      _result.error = error;
    }
    return _result;
  }
  factory VersionResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory VersionResponse.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  VersionResponse clone() => VersionResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  VersionResponse copyWith(void Function(VersionResponse) updates) =>
      super.copyWith((message) => updates(message as VersionResponse))
          as VersionResponse; // ignore: deprecated_member_use
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

  @$pb.TagNumber(3)
  $core.String get runtimeVersion => $_getSZ(2);
  @$pb.TagNumber(3)
  set runtimeVersion($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasRuntimeVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearRuntimeVersion() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get appEngineVersion => $_getSZ(3);
  @$pb.TagNumber(4)
  set appEngineVersion($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasAppEngineVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearAppEngineVersion() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get servicesVersion => $_getSZ(4);
  @$pb.TagNumber(5)
  set servicesVersion($core.String v) {
    $_setString(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasServicesVersion() => $_has(4);
  @$pb.TagNumber(5)
  void clearServicesVersion() => clearField(5);

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

  @$pb.TagNumber(7)
  $core.String get flutterDartVersion => $_getSZ(6);
  @$pb.TagNumber(7)
  set flutterDartVersion($core.String v) {
    $_setString(6, v);
  }

  @$pb.TagNumber(7)
  $core.bool hasFlutterDartVersion() => $_has(6);
  @$pb.TagNumber(7)
  void clearFlutterDartVersion() => clearField(7);

  @$pb.TagNumber(8)
  $core.String get flutterDartVersionFull => $_getSZ(7);
  @$pb.TagNumber(8)
  set flutterDartVersionFull($core.String v) {
    $_setString(7, v);
  }

  @$pb.TagNumber(8)
  $core.bool hasFlutterDartVersionFull() => $_has(7);
  @$pb.TagNumber(8)
  void clearFlutterDartVersionFull() => clearField(8);

  @$pb.TagNumber(9)
  $core.Map<$core.String, $core.String> get packageVersions => $_getMap(8);

  @$pb.TagNumber(10)
  $core.List<PackageInfo> get packageInfo => $_getList(9);

  @$pb.TagNumber(99)
  ErrorMessage get error => $_getN(10);
  @$pb.TagNumber(99)
  set error(ErrorMessage v) {
    setField(99, v);
  }

  @$pb.TagNumber(99)
  $core.bool hasError() => $_has(10);
  @$pb.TagNumber(99)
  void clearError() => clearField(99);
  @$pb.TagNumber(99)
  ErrorMessage ensureError() => $_ensure(10);
}

class PackageInfo extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'PackageInfo',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'name')
    ..aOS(
        2,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'version')
    ..aOB(
        3,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'supported')
    ..hasRequiredFields = false;

  PackageInfo._() : super();
  factory PackageInfo({
    $core.String? name,
    $core.String? version,
    $core.bool? supported,
  }) {
    final _result = create();
    if (name != null) {
      _result.name = name;
    }
    if (version != null) {
      _result.version = version;
    }
    if (supported != null) {
      _result.supported = supported;
    }
    return _result;
  }
  factory PackageInfo.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory PackageInfo.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  PackageInfo clone() => PackageInfo()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  PackageInfo copyWith(void Function(PackageInfo) updates) =>
      super.copyWith((message) => updates(message as PackageInfo))
          as PackageInfo; // ignore: deprecated_member_use
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static PackageInfo create() => PackageInfo._();
  PackageInfo createEmptyInstance() => create();
  static $pb.PbList<PackageInfo> createRepeated() => $pb.PbList<PackageInfo>();
  @$core.pragma('dart2js:noInline')
  static PackageInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PackageInfo>(create);
  static PackageInfo? _defaultInstance;

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

class BadRequest extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'BadRequest',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOM<ErrorMessage>(
        99,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'error',
        subBuilder: ErrorMessage.create)
    ..hasRequiredFields = false;

  BadRequest._() : super();
  factory BadRequest({
    ErrorMessage? error,
  }) {
    final _result = create();
    if (error != null) {
      _result.error = error;
    }
    return _result;
  }
  factory BadRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory BadRequest.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  BadRequest clone() => BadRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  BadRequest copyWith(void Function(BadRequest) updates) =>
      super.copyWith((message) => updates(message as BadRequest))
          as BadRequest; // ignore: deprecated_member_use
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

class ErrorMessage extends $pb.GeneratedMessage {
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      const $core.bool.fromEnvironment('protobuf.omit_message_names')
          ? ''
          : 'ErrorMessage',
      package: const $pb.PackageName(
          $core.bool.fromEnvironment('protobuf.omit_message_names')
              ? ''
              : 'dart_services.api'),
      createEmptyInstance: create)
    ..aOS(
        1,
        const $core.bool.fromEnvironment('protobuf.omit_field_names')
            ? ''
            : 'message')
    ..hasRequiredFields = false;

  ErrorMessage._() : super();
  factory ErrorMessage({
    $core.String? message,
  }) {
    final _result = create();
    if (message != null) {
      _result.message = message;
    }
    return _result;
  }
  factory ErrorMessage.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory ErrorMessage.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  ErrorMessage clone() => ErrorMessage()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  ErrorMessage copyWith(void Function(ErrorMessage) updates) =>
      super.copyWith((message) => updates(message as ErrorMessage))
          as ErrorMessage; // ignore: deprecated_member_use
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

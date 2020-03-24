// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server_proto;

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:protobuf/protobuf.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'api_classes.dart' as api;
import 'common_server_impl.dart' show CommonServerImpl, BadRequest;
import 'protos/dart_services.pb.dart' as proto;

export 'common_server_impl.dart' show log, ServerContainer;

part 'common_server_proto.g.dart'; // generated with 'pub run build_runner build'

const PROTOBUF_CONTENT_TYPE = 'application/x-protobuf';
const JSON_CONTENT_TYPE = 'application/json; charset=utf-8';
const PROTO_API_URL_PREFIX = '/api/dartservices/v2';

class CommonServerProto {
  final CommonServerImpl _impl;

  CommonServerProto(this._impl);

  @Route.post('$PROTO_API_URL_PREFIX/analyze')
  Future<Response> analyze(Request request) => _processRequest(request,
      decodeFromJSON: (json) =>
          proto.SourceRequest.create()..mergeFromProto3Json(json),
      decodeFromProto: (bytes) => proto.SourceRequest.fromBuffer(bytes),
      transform: _analyze);

  Future<proto.AnalysisResults> _analyze(proto.SourceRequest request) async {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }

    final apiRequest = api.SourceRequest()
      ..source = request.source
      ..offset = request.offset;
    final apiResponse = await _impl.analyze(apiRequest);

    return proto.AnalysisResults()
      ..packageImports.addAll(apiResponse.packageImports)
      ..issues.addAll(
        apiResponse.issues.map(
          (issue) => proto.AnalysisIssue()
            ..kind = issue.kind
            ..line = issue.line
            ..message = issue.message
            ..sourceName = issue.sourceName
            ..hasFixes = issue.hasFixes
            ..charStart = issue.charStart
            ..charLength = issue.charLength,
        ),
      );
  }

  @Route.post('$PROTO_API_URL_PREFIX/compile')
  Future<Response> compile(Request request) => _processRequest(request,
      decodeFromJSON: (json) =>
          proto.CompileRequest.create()..mergeFromProto3Json(json),
      decodeFromProto: (bytes) => proto.CompileRequest.fromBuffer(bytes),
      transform: _compile);

  Future<proto.CompileResponse> _compile(proto.CompileRequest request) async {
    final apiRequest = api.CompileRequest()
      ..source = request.source
      ..returnSourceMap = request.returnSourceMap;
    final apiResponse = await _impl.compile(apiRequest);
    final response = proto.CompileResponse()..result = apiResponse.result;
    if (apiResponse.sourceMap != null) {
      response.sourceMap = apiResponse.sourceMap;
    }
    return response;
  }

  @Route.post('$PROTO_API_URL_PREFIX/compileDDC')
  Future<Response> compileDDC(Request request) => _processRequest(request,
      decodeFromJSON: (json) =>
          proto.CompileRequest.create()..mergeFromProto3Json(json),
      decodeFromProto: (bytes) => proto.CompileRequest.fromBuffer(bytes),
      transform: _compileDDC);

  Future<proto.CompileDDCResponse> _compileDDC(
      proto.CompileRequest request) async {
    final apiRequest = api.CompileRequest()
      ..source = request.source
      ..returnSourceMap = request.returnSourceMap;
    final apiResponse = await _impl.compileDDC(apiRequest);

    return proto.CompileDDCResponse()
      ..result = apiResponse.result
      ..modulesBaseUrl = apiResponse.modulesBaseUrl;
  }

  @Route.post('$PROTO_API_URL_PREFIX/complete')
  Future<Response> complete(Request request) => _processRequest(request,
      decodeFromJSON: (json) =>
          proto.SourceRequest.create()..mergeFromProto3Json(json),
      decodeFromProto: (bytes) => proto.SourceRequest.fromBuffer(bytes),
      transform: _complete);

  Future<proto.CompleteResponse> _complete(proto.SourceRequest request) async {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }
    if (!request.hasOffset()) {
      throw BadRequest('Missing parameter: \'offset\'');
    }

    final apiRequest = api.SourceRequest()
      ..offset = request.offset
      ..source = request.source;
    final apiResponse = await _impl.complete(apiRequest);

    return proto.CompleteResponse()
      ..replacementOffset = apiResponse.replacementOffset
      ..replacementLength = apiResponse.replacementLength
      ..completions.addAll(
        apiResponse.completions.map(
          (completion) => proto.Completion()..completion.addAll(completion),
        ),
      );
  }

  @Route.post('$PROTO_API_URL_PREFIX/fixes')
  Future<Response> fixes(Request request) => _processRequest(request,
      decodeFromJSON: (json) =>
          proto.SourceRequest.create()..mergeFromProto3Json(json),
      decodeFromProto: (bytes) => proto.SourceRequest.fromBuffer(bytes),
      transform: _fixes);

  Future<proto.FixesResponse> _fixes(proto.SourceRequest request) async {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }
    if (!request.hasOffset()) {
      throw BadRequest('Missing parameter: \'offset\'');
    }

    final apiRequest = api.SourceRequest()
      ..offset = request.offset
      ..source = request.source;
    final apiResponse = await _impl.fixes(apiRequest);

    return proto.FixesResponse()
      ..fixes.addAll(
        apiResponse.fixes.map(
          (apiFix) => proto.ProblemAndFixes()
            ..problemMessage = apiFix.problemMessage
            ..offset = apiFix.offset
            ..length = apiFix.length
            ..fixes.addAll(
              apiFix.fixes.map(_transformCandidateFix),
            ),
        ),
      );
  }

  @Route.post('$PROTO_API_URL_PREFIX/assists')
  Future<Response> assists(Request request) => _processRequest(request,
      decodeFromJSON: (json) =>
          proto.SourceRequest.create()..mergeFromProto3Json(json),
      decodeFromProto: (bytes) => proto.SourceRequest.fromBuffer(bytes),
      transform: _assists);

  Future<proto.AssistsResponse> _assists(proto.SourceRequest request) async {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }
    if (!request.hasOffset()) {
      throw BadRequest('Missing parameter: \'offset\'');
    }

    final apiRequest = api.SourceRequest()
      ..offset = request.offset
      ..source = request.source;
    final apiResponse = await _impl.assists(apiRequest);

    return proto.AssistsResponse()
      ..assists.addAll(
        apiResponse.assists.map(_transformCandidateFix),
      );
  }

  @Route.post('$PROTO_API_URL_PREFIX/format')
  Future<Response> format(Request request) => _processRequest(request,
      decodeFromJSON: (json) =>
          proto.SourceRequest.create()..mergeFromProto3Json(json),
      decodeFromProto: (bytes) => proto.SourceRequest.fromBuffer(bytes),
      transform: _format);

  Future<proto.FormatResponse> _format(proto.SourceRequest request) async {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }

    final apiRequest = api.SourceRequest()
      ..offset = request.offset
      ..source = request.source;
    final apiResponse = await _impl.format(apiRequest);

    return proto.FormatResponse()
      ..newString = apiResponse.newString
      ..offset = apiResponse.offset;
  }

  @Route.post('$PROTO_API_URL_PREFIX/document')
  Future<Response> document(Request request) => _processRequest(request,
      decodeFromJSON: (json) =>
          proto.SourceRequest.create()..mergeFromProto3Json(json),
      decodeFromProto: (bytes) => proto.SourceRequest.fromBuffer(bytes),
      transform: _document);

  Future<proto.DocumentResponse> _document(proto.SourceRequest request) async {
    if (!request.hasSource()) {
      throw BadRequest('Missing parameter: \'source\'');
    }
    if (!request.hasOffset()) {
      throw BadRequest('Missing parameter: \'offset\'');
    }

    final apiRequest = api.SourceRequest()
      ..offset = request.offset
      ..source = request.source;
    final apiResponse = await _impl.document(apiRequest);

    return proto.DocumentResponse()..info.addAll(apiResponse.info);
  }

  @Route.post('$PROTO_API_URL_PREFIX/version')
  Future<Response> versionPost(Request request) => _processRequest(request,
      decodeFromJSON: (json) =>
          proto.VersionRequest.create()..mergeFromProto3Json(json),
      decodeFromProto: (bytes) => proto.VersionRequest.fromBuffer(bytes),
      transform: _version);

  @Route.get('$PROTO_API_URL_PREFIX/version')
  Future<Response> versionGet(Request request) => _processRequest(request,
      decodeFromJSON: (json) =>
          proto.VersionRequest.create()..mergeFromProto3Json(json),
      decodeFromProto: (bytes) => proto.VersionRequest.fromBuffer(bytes),
      transform: _version);

  Future<proto.VersionResponse> _version(proto.VersionRequest request) async {
    final apiResponse = await _impl.version();

    return proto.VersionResponse()
      ..sdkVersion = apiResponse.sdkVersion
      ..sdkVersionFull = apiResponse.sdkVersionFull
      ..runtimeVersion = apiResponse.runtimeVersion
      ..appEngineVersion = apiResponse.appEngineVersion
      ..servicesVersion = apiResponse.servicesVersion
      ..flutterDartVersion = apiResponse.flutterDartVersion
      ..flutterDartVersionFull = apiResponse.flutterDartVersionFull
      ..flutterVersion = apiResponse.flutterVersion;
  }

  proto.CandidateFix _transformCandidateFix(api.CandidateFix candidateFix) {
    final result = proto.CandidateFix()..message = candidateFix.message;
    if (candidateFix.edits != null) {
      result.edits.addAll(
        candidateFix.edits.map(
          (edit) => proto.SourceEdit()
            ..offset = edit.offset
            ..length = edit.length
            ..replacement = edit.replacement,
        ),
      );
    }
    if (candidateFix.linkedEditGroups != null) {
      result.linkedEditGroups.addAll(
        candidateFix.linkedEditGroups.map(
          (group) => proto.LinkedEditGroup()
            ..positions.addAll(group.positions)
            ..length = group.length
            ..suggestions.addAll(
              group.suggestions.map(
                (suggestion) => proto.LinkedEditSuggestion()
                  ..value = suggestion.value
                  ..kind = suggestion.kind,
              ),
            ),
        ),
      );
    }
    if (candidateFix.selectionOffset != null) {
      result.selectionOffset = candidateFix.selectionOffset;
    }
    return result;
  }

  Router get router => _$CommonServerProtoRouter(this);

  // We are serving requests that are arriving in both Protobuf binary encoding,
  // and Protobuf JSON encoding. To handle this we need the ability to decode
  // the requests and encode the responses. We also need to know how to do the
  // work the request is requesting.

  Future<Response> _processRequest<I, O extends GeneratedMessage>(
    Request request, {
    @required I Function(List<int> bytes) decodeFromProto,
    @required I Function(Object json) decodeFromJSON,
    @required Future<O> Function(I input) transform,
  }) async {
    if (request.mimeType == PROTOBUF_CONTENT_TYPE) {
      // Dealing with binary Protobufs
      final body = <int>[];
      await for (final chunk in request.read()) {
        body.addAll(chunk);
      }
      try {
        final response = await transform(decodeFromProto(body));
        return Response.ok(
          response.writeToBuffer(),
          headers: _PROTOBUF_HEADERS,
        );
      } on BadRequest catch (e) {
        return Response(400,
            headers: _PROTOBUF_HEADERS,
            body: (proto.BadRequest.create()
                  ..error = (proto.ErrorMessage.create()..message = e.cause))
                .writeToBuffer());
      }
    } else {
      // Dealing with JSON encoded Protobufs
      final body = await request.readAsString();
      try {
        final response = await transform(
            decodeFromJSON(body.isNotEmpty ? json.decode(body) : {}));
        return Response.ok(
          _jsonEncoder.convert(response.toProto3Json()),
          encoding: utf8,
          headers: _JSON_HEADERS,
        );
      } on BadRequest catch (e) {
        return Response(400,
            headers: _JSON_HEADERS,
            encoding: utf8,
            body: _jsonEncoder.convert((proto.BadRequest.create()
                  ..error = (proto.ErrorMessage.create()..message = e.cause))
                .toProto3Json()));
      }
    }
  }

  final JsonEncoder _jsonEncoder = JsonEncoder.withIndent(' ');

  static const _JSON_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Content-Type': JSON_CONTENT_TYPE
  };

  static const _PROTOBUF_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Content-Type': PROTOBUF_CONTENT_TYPE
  };
}

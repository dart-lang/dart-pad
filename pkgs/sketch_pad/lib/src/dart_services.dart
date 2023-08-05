// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart';
import 'package:protobuf/protobuf.dart';

import 'protos/dart_services.pb.dart';

export 'protos/dart_services.pb.dart';

const _apiPath = 'api/dartservices/v2';

class DartservicesApi {
  DartservicesApi(this._client, {required this.rootUrl});

  final Client _client;
  String rootUrl;

  Future<AnalysisResults> analyze(SourceRequest request) => _request(
        'analyze',
        request,
        AnalysisResults(),
      );

  Future<AssistsResponse> assists(SourceRequest request) => _request(
        'assists',
        request,
        AssistsResponse(),
      );

  Future<CompileResponse> compile(CompileRequest request) => _request(
        'compile',
        request,
        CompileResponse(),
      );

  Future<CompileDDCResponse> compileDDC(CompileRequest request) => _request(
        'compileDDC',
        request,
        CompileDDCResponse(),
      );

  /// Note that this call is experimental and can change at any time.
  Future<FlutterBuildResponse> flutterBuild(FlutterBuildRequest request) =>
      _request('_flutterBuild', request, FlutterBuildResponse());

  Future<CompleteResponse> complete(SourceRequest request) => _request(
        'complete',
        request,
        CompleteResponse(),
      );

  Future<DocumentResponse> document(SourceRequest request) => _request(
        'document',
        request,
        DocumentResponse(),
      );

  Future<FixesResponse> fixes(SourceRequest request) => _request(
        'fixes',
        request,
        FixesResponse(),
      );

  Future<FormatResponse> format(SourceRequest request) => _request(
        'format',
        request,
        FormatResponse(),
      );

  Future<VersionResponse> version() => _requestGet(
        'version',
        VersionRequest(),
        VersionResponse(),
      );

  Future<O> _requestGet<I extends GeneratedMessage, O extends GeneratedMessage>(
    String action,
    I request,
    O result,
  ) async {
    final response = await _client.get(Uri.parse('$rootUrl$_apiPath/$action'));

    final jsonBody = json.decode(response.body);
    result
      ..mergeFromProto3Json(jsonBody)
      ..freeze();

    // 99 is the tag number for error message.
    if (result.getFieldOrNull(99) != null) {
      final br = BadRequest()
        ..mergeFromProto3Json(jsonBody)
        ..freeze();
      throw ApiRequestError(br.error.message);
    } else {
      return result;
    }
  }

  Future<O> _request<I extends GeneratedMessage, O extends GeneratedMessage>(
    String action,
    I request,
    O result,
  ) async {
    final response = await _client.post(
      Uri.parse('$rootUrl$_apiPath/$action'),
      encoding: utf8,
      body: json.encode(request.toProto3Json()),
    );

    try {
      final jsonBody = json.decode(response.body);
      result
        ..mergeFromProto3Json(jsonBody)
        ..freeze();

      // 99 is the tag number for error message.
      if (result.getFieldOrNull(99) != null) {
        final br = BadRequest()
          ..mergeFromProto3Json(jsonBody)
          ..freeze();
        throw ApiRequestError(br.error.message);
      } else {
        return result;
      }
    } on FormatException {
      final message = '${response.statusCode} ${response.reasonPhrase}';
      throw ApiRequestError('$message: ${response.body}');
    }
  }
}

class ApiRequestError implements Exception {
  ApiRequestError(this.message);

  final String message;
}

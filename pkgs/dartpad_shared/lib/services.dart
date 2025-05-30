// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'backend_client.dart';
import 'model.dart';

export 'model.dart';

class DartServicesClient {
  final DartServicesHttpClient client;
  final String rootUrl;

  DartServicesClient(this.client, {required this.rootUrl});

  Future<VersionResponse> version() =>
      _requestGet('version', VersionResponse.fromJson);

  Future<AnalysisResponse> analyze(SourceRequest request) =>
      _requestPost('analyze', request.toJson(), AnalysisResponse.fromJson);

  Future<CompleteResponse> complete(SourceRequest request) =>
      _requestPost('complete', request.toJson(), CompleteResponse.fromJson);

  Future<DocumentResponse> document(SourceRequest request) =>
      _requestPost('document', request.toJson(), DocumentResponse.fromJson);

  Future<FixesResponse> fixes(SourceRequest request) =>
      _requestPost('fixes', request.toJson(), FixesResponse.fromJson);

  Future<FormatResponse> format(SourceRequest request) =>
      _requestPost('format', request.toJson(), FormatResponse.fromJson);

  Future<CompileResponse> compile(CompileRequest request) =>
      _requestPost('compile', request.toJson(), CompileResponse.fromJson);

  Future<CompileDDCResponse> compileDDC(CompileRequest request) =>
      _requestPost('compileDDC', request.toJson(), CompileDDCResponse.fromJson);

  Future<CompileDDCResponse> compileNewDDC(CompileRequest request) =>
      _requestPost(
        'compileNewDDC',
        request.toJson(),
        CompileDDCResponse.fromJson,
      );

  Future<CompileDDCResponse> compileNewDDCReload(CompileRequest request) =>
      _requestPost(
        'compileNewDDCReload',
        request.toJson(),
        CompileDDCResponse.fromJson,
      );

  Future<OpenInIdxResponse> openInFirebaseStudio(
    OpenInFirebaseStudioRequest request,
  ) => _requestPost(
    'openInFirebaseStudio',
    request.toJson(),
    OpenInIdxResponse.fromJson,
  );

  Stream<String> suggestFix(SuggestFixRequest request) =>
      _requestPostStream('suggestFix', request.toJson());

  Stream<String> generateCode(GenerateCodeRequest request) =>
      _requestPostStream('generateCode', request.toJson());

  Stream<String> updateCode(UpdateCodeRequest request) =>
      _requestPostStream('updateCode', request.toJson());

  void dispose() => client.close();

  Future<T> _requestGet<T>(
    String action,
    T Function(Map<String, Object?> json) responseFactory,
  ) async {
    final response = await client.get('${rootUrl}api/v3/$action');

    if (response.statusCode != 200) {
      throw ApiRequestError(action, response.body);
    } else {
      try {
        return responseFactory(
          json.decode(response.body) as Map<String, Object?>,
        );
      } on FormatException catch (e) {
        throw ApiRequestError('$action: $e', response.body);
      }
    }
  }

  Future<T> _requestPost<T>(
    String action,
    Map<String, Object?> request,
    T Function(Map<String, Object?> json) responseFactory,
  ) async {
    final response = await client.post('${rootUrl}api/v3/$action', request);
    if (response.statusCode != 200) {
      throw ApiRequestError(action, response.body);
    } else {
      try {
        return responseFactory(
          json.decode(response.body) as Map<String, Object?>,
        );
      } on FormatException catch (e) {
        throw ApiRequestError('$action: $e', response.body);
      }
    }
  }

  Stream<String> _requestPostStream(
    String action,
    Map<String, Object?> request,
  ) async* {
    final response = await client.sendJson('${rootUrl}api/v3/$action', request);

    if (response.statusCode != 200) {
      throw ApiRequestError(
        action,
        '${response.statusCode}: ${response.reasonPhrase}',
      );
    }

    try {
      yield* response.stream.transform(utf8.decoder);
    } on FormatException catch (e) {
      throw ApiRequestError('$action: $e', '');
    }
  }
}

class ApiRequestError implements Exception {
  ApiRequestError(this.message, this.body);

  final String message;
  final String body;

  @override
  String toString() => '$message: $body';
}

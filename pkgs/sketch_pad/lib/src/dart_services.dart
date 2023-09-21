// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart';

import 'api_model.dart';

export 'api_model.dart';

class DartservicesApi {
  final Client _client;
  final String rootUrl;

  DartservicesApi(this._client, {required this.rootUrl});

  Future<AnalysisResults> analyze(SourceRequest request) =>
      _request('analyze', request.toJson(), AnalysisResults.fromJson);

  Future<CompileResponse> compile(CompileRequest request) =>
      _request('compile', request.toJson(), CompileResponse.fromJson);

  /// Note that this call is experimental and can change at any time.
  Future<FlutterBuildResponse> flutterBuild(SourceRequest request) => _request(
      '_flutterBuild', request.toJson(), FlutterBuildResponse.fromJson);

  Future<CompleteResponse> complete(SourceRequest request) =>
      _request('complete', request.toJson(), CompleteResponse.fromJson);

  // Future<DocumentResponse> document(SourceRequest request) =>
  //     _request('document', request.toJson(), DocumentResponse.fromJson);

  // Future<FixesResponse> fixes(SourceRequest request) =>
  //     _request('fixes', request.toJson(), FixesResponse.fromJson);

  Future<FormatResponse> format(SourceRequest request) =>
      _request('format', request.toJson(), FormatResponse.fromJson);

  Future<VersionResponse> version() =>
      _requestGet('version', {}, VersionResponse.fromJson);

  Future<T> _requestGet<T>(
    String action,
    Map<String, dynamic> request,
    T Function(Map<String, dynamic> json) responseFactory,
  ) async {
    final response =
        await _client.get(Uri.parse('${rootUrl}api/dartservices/v3/$action'));
    // TODO: handle responses other than 200
    final jsonBody = json.decode(response.body) as Map<String, dynamic>;
    return responseFactory(jsonBody);
  }

  Future<T> _request<T>(
    String action,
    Map<String, dynamic> request,
    T Function(Map<String, dynamic> json) responseFactory,
  ) async {
    final response = await _client.post(
      Uri.parse('${rootUrl}api/dartservices/v3/$action'),
      encoding: utf8,
      body: json.encode(request),
    );

    // TODO: handle responses other than 200

    try {
      final jsonBody = json.decode(response.body) as Map<String, dynamic>;
      return responseFactory(jsonBody);
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

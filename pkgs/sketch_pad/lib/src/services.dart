// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart';

import 'api_model.dart';

export 'api_model.dart';

class Services {
  final Client _client;
  final String rootUrl;

  Services(this._client, {required this.rootUrl});

  Future<AnalysisResponse> analyze(SourceRequest request) =>
      _requestPost('analyze', request.toJson(), AnalysisResponse.fromJson);

  Future<CompileResponse> compile(CompileRequest request) =>
      _requestPost('compile', request.toJson(), CompileResponse.fromJson);

  /// Note that this call is experimental and can change at any time.
  Future<FlutterBuildResponse> flutterBuild(SourceRequest request) =>
      _requestPost(
          '_flutterBuild', request.toJson(), FlutterBuildResponse.fromJson);

  Future<CompleteResponse> complete(SourceRequest request) =>
      _requestPost('complete', request.toJson(), CompleteResponse.fromJson);

  // Future<DocumentResponse> document(SourceRequest request) =>
  //     _request('document', request.toJson(), DocumentResponse.fromJson);

  // Future<FixesResponse> fixes(SourceRequest request) =>
  //     _request('fixes', request.toJson(), FixesResponse.fromJson);

  Future<FormatResponse> format(SourceRequest request) =>
      _requestPost('format', request.toJson(), FormatResponse.fromJson);

  Future<VersionResponse> version() =>
      _requestGet('version', VersionResponse.fromJson);

  Future<T> _requestGet<T>(
    String action,
    T Function(Map<String, dynamic> json) responseFactory,
  ) async {
    final response =
        await _client.get(Uri.parse('${rootUrl}api/dartservices/v3/$action'));
    if (response.statusCode != 200) {
      throw ApiRequestError(
          '$action: ${response.statusCode}: ${response.reasonPhrase}');
    }

    try {
      return responseFactory(
          json.decode(response.body) as Map<String, dynamic>);
    } on FormatException catch (e) {
      throw ApiRequestError('$action: $e');
    }
  }

  Future<T> _requestPost<T>(
    String action,
    Map<String, dynamic> request,
    T Function(Map<String, dynamic> json) responseFactory,
  ) async {
    final response = await _client.post(
        Uri.parse('${rootUrl}api/dartservices/v3/$action'),
        encoding: utf8,
        body: json.encode(request));
    if (response.statusCode != 200) {
      throw ApiRequestError(
          '$action: ${response.statusCode}: ${response.reasonPhrase}');
    }

    try {
      return responseFactory(
          json.decode(response.body) as Map<String, dynamic>);
    } on FormatException catch (e) {
      throw ApiRequestError('$action: $e');
    }
  }
}

class ApiRequestError implements Exception {
  ApiRequestError(this.message);

  final String message;
}

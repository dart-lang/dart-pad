// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart';

import 'headers.dart';

class DartServicesClient {
  final Client _client = Client();
  static Map<String, String> _headers =
      DartPadRequestHeaders(enableLogging: true).encoded;

  /// Turns off backend logging for all future requests.
  static void turnOffBackendLogging() {
    _headers = DartPadRequestHeaders(enableLogging: false).encoded;
  }

  void close() => _client.close();

  Future<Response> get(String url) async {
    return await _client.get(Uri.parse(url), headers: _headers);
  }

  Future<Response> post(String url, Map<String, Object?> body) async {
    return await _client.post(
      Uri.parse(url),
      encoding: utf8,
      body: json.encode(body),
      headers: _headers,
    );
  }

  Future<StreamedResponse> sendJson(
    String url,
    Map<String, Object?> request,
  ) async {
    final httpRequest = Request('POST', Uri.parse(url));
    httpRequest.encoding = utf8;
    httpRequest.headers.addAll(_headers);
    httpRequest.headers['Content-Type'] = 'application/json';
    httpRequest.body = json.encode(request);

    return await _client.send(httpRequest);
  }
}

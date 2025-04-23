// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'dart:typed_data';

import 'package:http/http.dart';

/// The number of active HTTP requests.
///
/// This is used in testing to determine when
/// the app is done with all requests.
int _activeHttpRequests = 0;

class DartPadHttpClient implements Client {
  final Client _client = Client();

  DartPadHttpClient();

  static bool get allRequestsCompleted => _activeHttpRequests == 0;

  @override
  void close() => _client.close();

  @override
  Future<Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    _activeHttpRequests++;
    final result = await _client.delete(
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    );
    _activeHttpRequests--;
    return result;
  }

  @override
  Future<Response> get(Uri url, {Map<String, String>? headers}) async {
    _activeHttpRequests++;
    final result = await _client.get(url, headers: headers);
    _activeHttpRequests--;
    return result;
  }

  @override
  Future<Response> head(Uri url, {Map<String, String>? headers}) async {
    _activeHttpRequests++;
    final result = await _client.head(url, headers: headers);
    _activeHttpRequests--;
    return result;
  }

  @override
  Future<Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    _activeHttpRequests++;
    final result = await _client.patch(
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    );
    _activeHttpRequests--;
    return result;
  }

  @override
  Future<Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    _activeHttpRequests++;
    final result = await _client.post(
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    );
    _activeHttpRequests--;
    return result;
  }

  @override
  Future<Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    _activeHttpRequests++;
    final result = await _client.put(
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    );
    _activeHttpRequests--;
    return result;
  }

  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) =>
      _client.read(url, headers: headers);

  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) =>
      _client.readBytes(url, headers: headers);

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    _activeHttpRequests++;
    final result = await _client.send(request);
    _activeHttpRequests--;
    return result;
  }
}

// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:dart_services/src/server_cache.dart';

export 'package:angel3_mock_request/angel3_mock_request.dart'
    show MockHttpRequest, MockHttpResponse;

class MockCache implements ServerCache {
  final _cache = HashMap<String, String>();

  @override
  Future<String?> get(String key) async => _cache[key];

  @override
  Future<void> set(String key, String value, {Duration? expiration}) async =>
      _cache[key] = value;

  @override
  Future<void> remove(String key) async => _cache.remove(key);

  @override
  Future<void> shutdown() async => _cache.removeWhere((key, value) => true);
}

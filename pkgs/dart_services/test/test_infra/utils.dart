// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

import 'package:dart_services/src/caching.dart';
import 'package:dart_services/src/context.dart';
import 'package:dartpad_shared/backend_client.dart';
import 'package:dartpad_shared/services.dart';

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

final ctx = DartPadRequestContext(enableLogging: false);

final dartServicesProdProbingClients = () {
  DartServicesHttpClient.turnOffBackendLogging();

  return Channel.values
      .where((c) => c != Channel.localhost)
      .map(
        (channel) =>
            DartServicesClient(DartServicesHttpClient(), rootUrl: channel.url),
      );
}();

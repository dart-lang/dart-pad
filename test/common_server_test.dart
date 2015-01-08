// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_server.common_server_test;

import 'dart:async';
import 'dart:convert' show JSON;

import 'package:dartpad_server/src/common.dart';
import 'package:dartpad_server/src/common_server.dart';
import 'package:grinder/grinder.dart' as grinder;
import 'package:unittest/unittest.dart';

void defineTests() {
  CommonServer server;
  MockLogger logger = new MockLogger();
  MockCache cache = new MockCache();

  group('CommonServer', () {
    setUp(() {
      if (server == null) {
        String sdkPath = grinder.getSdkDir().path;
        server = new CommonServer(sdkPath, logger, cache);
      }
    });

    test('analyze', () {
      String json = JSON.encode({'source': sampleCode});
      return server.handleAnalyze(json).then((ServerResponse response) {
        expect(response.statusCode, 200);
        expect(response.data, '[]');
      });
    });

    test('analyze errors', () {
      String json = JSON.encode({'source': sampleCodeError});
      return server.handleAnalyze(json).then((ServerResponse response) {
        expect(response.statusCode, 200);
        expect(response.data, '[{"kind":"error","line":2,"message":'
            '"Expected to find \';\'","charStart":29,"charLength":1}]');
      });
    });

    test('compile', () {
      String json = JSON.encode({'source': sampleCode});
      return server.handleCompile(json).then((ServerResponse response) {
        expect(response.statusCode, 200);
        expect(response.data, isNotEmpty);
      });
    });

    test('complete', () {
      String json = JSON.encode(
          {'source': 'void main() {print("foo");}', 'offset': 1});
      return server.handleComplete(json, 'application/json; utf8')
          .then((ServerResponse response) {
        expect(response.statusCode, 501);
      });
    });

    test('complete no data', () {
      return server.handleComplete('').then((ServerResponse response) {
        expect(response.statusCode, 400);
      });
    });

    test('complete param missing', () {
      return server.handleComplete('offset=1', 'application/x-www-form-urlencoded')
          .then((ServerResponse response) {
        expect(response.statusCode, 400);
        expect(response.toString(), '[response 400]');
      });
    });

    test('complete param missing 2', () {
      String json = JSON.encode({'source': 'void main() {print("foo");}'});
      return server.handleComplete(json).then((ServerResponse response) {
        expect(response.statusCode, 400);
      });
    });

    test('document', () {
      String json = JSON.encode(
          {'source': 'void main() {print("foo");}', 'offset': 17});
      return server.handleDocument(json).then((ServerResponse response) {
        expect(response.statusCode, 200);
        expect(response.data, isNotEmpty);
      });
    });

    test('document little data', () {
      String json = JSON.encode(
          {'source': 'void main() {print("foo");}', 'offset': 2});
      return server.handleDocument(json).then((ServerResponse response) {
        expect(response.statusCode, 200);
        expect(response.data, '{"staticType":"void"}');
      });
    });

    test('document no data', () {
      String json = JSON.encode(
          {'source': 'void main() {print("foo");}', 'offset': 12});
      return server.handleDocument(json).then((ServerResponse response) {
        expect(response.statusCode, 200);
        expect(response.data, '{}');
      });
    });
  });
}

class MockLogger implements ServerLogger {
  StringBuffer builder = new StringBuffer();

  void info(String message) => builder.write('${message}\n');
  void warn(String message) => builder.write('${message}\n');
  void error(String message) => builder.write('${message}\n');

  void clear() => builder.clear();
  String getLog() => builder.toString();
}

class MockCache implements ServerCache {
  Future<String> get(String key) => new Future.value(null);
  Future set(String key, String value, {Duration expiration}) =>
      new Future.value();
  Future remove(String key) => new Future.value();
}

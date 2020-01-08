// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library gae_deployed_test;

import 'package:dart_services/src/common.dart' as common;
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

final String serverUrl = 'https://liftoff-dev.appspot.com';

void main() => defineTests();

void defineTests({bool skip = true}) {
  group('gae deployed tests', () {
    test('analyze end point', analyzeTest, skip: skip);
    test('compile end point', compileTest, skip: skip);
    test('compileDDC end point', compileDDCTest, skip: skip);
  });
}

void analyzeTest() {
  final url = '$serverUrl/api/analyze';
  final headers = {'Content-Type': 'text/plain; charset=UTF-8'};

  expect(
      http
          .post(url, headers: headers, body: common.sampleCodeWeb)
          .then((response) {
        expect(response.statusCode, 200);
        expect(response.body.trim(), '[]');
        return true;
      }),
      completion(equals(true)));
}

void compileTest() {
  final url = '$serverUrl/api/compile';
  final headers = {'Content-Type': 'text/plain; charset=UTF-8'};

  expect(
      http
          .post(url, headers: headers, body: common.sampleCodeWeb)
          .then((response) {
        expect(response.statusCode, 200);
        expect(true, response.body.length > 100);
        return true;
      }),
      completion(equals(true)));
}

void compileDDCTest() {
  final url = '$serverUrl/api/compileDDC';
  final headers = {'Content-Type': 'text/plain; charset=UTF-8'};

  expect(
      http
          .post(url, headers: headers, body: common.sampleCodeWeb)
          .then((response) {
        expect(response.statusCode, 200);
        expect(true, response.body.length > 100);
        return true;
      }),
      completion(equals(true)));
}

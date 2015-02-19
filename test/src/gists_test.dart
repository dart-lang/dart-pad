// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.gists_test;

import 'package:dart_pad/src/gists.dart';
import 'package:unittest/unittest.dart';

void defineTests() {
  group('gists', () {
    group('extractHtmlBody', () {
      test('should return empty string if html is empty', () {
        expect(extractHtmlBody(''), isEmpty);
      });

      test('should return body content if html is well-formed', () {
        expect(extractHtmlBody('<html><body><h1>Hello World!</h1></body></html>'), equals('<h1>Hello World!</h1>'));
      });

      test('should return empty string if html is well-formed but without body', () {
        expect(extractHtmlBody('<html><head><title>Hello World!</title></head></html>'), isEmpty);
      });

      test('should return body content even if html is malformed', () {
        expect(extractHtmlBody('Hello World!'), equals('Hello World!'));
        expect(extractHtmlBody('<h1>Hello World!</h1>'), equals('<h1>Hello World!</h1>'));
        expect(extractHtmlBody('<body><h1>Hello World!</h1>'), '<h1>Hello World!</h1>');
        expect(extractHtmlBody('<body><h1>Hello World!</h1></XXX>'), '<h1>Hello World!</h1>');
      });
    });
  });
}

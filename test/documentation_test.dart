// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library dartpad.documentation_test;

import 'package:dart_pad/documentation.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  group('documentation', () {
    // Verify that the MDN documentation address hasn't changed.
    test('MDN link exists', () {
      return createMdnMarkdownLink('HTMLDivElement').then((linkText) {
        expect(linkText, contains('HTMLDivElement'));
      });
    });

    test('MDN no link', () {
      return createMdnMarkdownLink('FooBar').then((linkText) {
        expect(linkText, null);
      });
    });
  });
}

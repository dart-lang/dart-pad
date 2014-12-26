// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_server.analyzer_test;

import 'package:dartpad_server/src/analyzer.dart';
import 'package:unittest/unittest.dart';

// TODO: analyze
// TODO: dartdoc

void defineTests() {
  group('analyzer.cleanDartDoc', () {
    test('null', () {
      expect(cleanDartDoc(null), null);
    });

    test('1 line', () {
      expect(cleanDartDoc("/**\n * Foo.\n */\n"), "Foo.");
    });

    test('2 lines', () {
      expect(cleanDartDoc("/**\n * Foo.\n * Foo.\n */\n"), "Foo.\nFoo.");
    });

    test('C# comments', () {
      expect(cleanDartDoc("/// Foo.\n /// Foo.\n"), "Foo.\nFoo.");
    });
  });
}

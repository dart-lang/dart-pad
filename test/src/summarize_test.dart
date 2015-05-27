// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad.summarize_test;

import 'package:dart_pad/src/summarize.dart';
import 'package:unittest/unittest.dart';

///These tests serve to determine the functionality of the summarization tool

void defineTests() {
  group('Summarizer', () {
    //Verify that summarizer returns non-null input
    test('non-null', () {
      String codeSample = '''void main() {
  for (int i = 0; i < 5; i++) {
    print("hello \${i + 1}");
  }
};''';
      Summarizer summer = new Summarizer();
      expect(summer.summarize(null, null), isNot(equals(null)));
    });
  });
}

// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: prefer_single_quotes

library services.common_test;

import 'package:dart_services/src/common.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  group('Lines', () {
    test('empty string', () {
      final lines = Lines('');
      expect(lines.getLineForOffset(0), 0);
      expect(lines.getLineForOffset(1), 0);
    });

    test('getLineForOffset', () {
      final lines = Lines('one\ntwo\nthree');
      expect(lines.getLineForOffset(0), 0);
      expect(lines.getLineForOffset(1), 0);
      expect(lines.getLineForOffset(2), 0);
      expect(lines.getLineForOffset(3), 0);
      expect(lines.getLineForOffset(4), 1);
      expect(lines.getLineForOffset(5), 1);
      expect(lines.getLineForOffset(6), 1);
      expect(lines.getLineForOffset(7), 1);
      expect(lines.getLineForOffset(8), 2);
      expect(lines.getLineForOffset(9), 2);
      expect(lines.getLineForOffset(10), 2);
      expect(lines.getLineForOffset(11), 2);
      expect(lines.getLineForOffset(12), 2);
      expect(lines.getLineForOffset(13), 2);

      expect(lines.getLineForOffset(14), 2);
    });
  });

  test('stripMatchingQuotes', () {
    expect(stripMatchingQuotes(""), "");
    expect(stripMatchingQuotes("'"), "'");
    expect(stripMatchingQuotes("''"), "");
    expect(stripMatchingQuotes("'abc'"), "abc");

    expect(stripMatchingQuotes(''), '');
    expect(stripMatchingQuotes('"'), '"');
    expect(stripMatchingQuotes('""'), '');
    expect(stripMatchingQuotes('"abc"'), 'abc');
  });

  test('vmVersion', () {
    expect(vmVersion, isNotNull);
    expect(vmVersion, startsWith('2.'));
  });
}

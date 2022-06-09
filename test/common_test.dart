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

  test('countLines', () {
    final Map<String, String> sources = {
      'file1': '\n\n\n\n\n', // 5 lines,
      'file2': r'''THis is line 1,
                    This is line 2,
                    THis is line 3''', // 3 lines,
      'file3': 'line1\r\nline2\r\nline 3\r\n', // 3 lines,
      'file4': 'line1\nline2\nline3\n', // 3 lines,
      'file5': 'line1\rline2\rline3\r', // and 3 lines makes 17 total lines.
    };
    expect(countLines(sources), 17);
  });

  test('countEOLsInString', () {
    expect(countLinesInString('line1\r\nline2\r\nline 3\r\n\r\n'), 4);
    expect(countLinesInString('line1\nline2\nline3\nline4\n\n'), 5);
    expect(countLinesInString('line1\rline2\rline3\rline4\rline5\r\r'), 6);
    expect(countLinesInString('\n\n\n\n\n\n\n'), 7);
    expect(countLinesInString('\r\r\r\r\r\r\r\r'), 8);
    expect(countLinesInString('\n\n\n\n\n\n\n\n\n'), 9);
    expect(countLinesInString(r'''THis is line 1,
                    This is line 2
'''), 2);
  });

  test('sanitizeAndCheckFilenames', () {
    final Map<String, String> filesSanitize = {
      '..\\.../../$kMainDart': '',
      '../various.dart': ''
    };

    sanitizeAndCheckFilenames(filesSanitize);
    expect(filesSanitize.keys.elementAt(0), kMainDart);
    expect(filesSanitize.keys.elementAt(1), 'various.dart');

    // Using "part 'various.dart'" to bring in second file.
    final Map<String, String> filesVar2 = {
      'mymain.dart': 'void main() => ();',
      'various.dart': '',
      'discdata.dart': ''
    };

    String newmain = sanitizeAndCheckFilenames(filesVar2, 'mymain.dart');
    expect(newmain, kMainDart);
    expect(filesVar2.keys.elementAt(0), kMainDart);
    expect(filesVar2.keys.elementAt(1), 'various.dart');

    final Map<String, String> filesVar3Sani = {
      'package:$kMainDart': '',
      'dart:discdata.dart': '',
      'http://dart:http://various.dart': ''
    };
    newmain = sanitizeAndCheckFilenames(filesVar3Sani, 'package:$kMainDart');
    expect(newmain, kMainDart);
    expect(filesVar3Sani.keys.elementAt(0), kMainDart);
    expect(filesVar3Sani.keys.elementAt(1), 'discdata.dart');
    expect(filesVar3Sani.keys.elementAt(2), 'various.dart');
  });
}

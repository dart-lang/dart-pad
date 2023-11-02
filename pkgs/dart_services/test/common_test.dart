// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: prefer_single_quotes

import 'package:dart_services/src/common.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  test('countLines', () {
    final sources = <String, String>{
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
    final filesSanitize = <String, String>{
      '..\\.../../$kMainDart': '',
      '../various.dart': ''
    };

    sanitizeAndCheckFilenames(filesSanitize);
    expect(filesSanitize.keys.elementAt(0), kMainDart);
    expect(filesSanitize.keys.elementAt(1), 'various.dart');

    // Using "part 'various.dart'" to bring in second file.
    final filesVar2 = <String, String>{
      'mymain.dart': 'void main() => ();',
      'various.dart': '',
      'discdata.dart': ''
    };

    var newmain = sanitizeAndCheckFilenames(filesVar2, 'mymain.dart');
    expect(newmain, kMainDart);
    expect(filesVar2.keys.elementAt(0), kMainDart);
    expect(filesVar2.keys.elementAt(1), 'various.dart');

    final filesVar3Sani = <String, String>{
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

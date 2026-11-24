// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_frontend/features/preview/models/compiler_error_file.dart';
import 'package:test/test.dart';

void main() {
  test('extracts the actual file from the first compiler error', () {
    const output = '''
file:///workspace/pad_1/lib/other.dart:2:16: Error: Expected ';' after this.
  print("hello")
               ^
file:///workspace/pad_1/lib/main.dart:4:3: Error: Method not found: 'missing'.
''';
    expect(compilerErrorFile(output), 'other.dart');
  });

  test('supports a diagnostic on the following line', () {
    const output = "file:///workspace/pad_1/lib/main.dart:2:16:\r\nError: Expected ';' after this.\r\n";
    expect(compilerErrorFile(output), 'main.dart');
  });

  test('handles package and encoded paths', () {
    expect(compilerErrorFile('package:example/src/my%20file.dart:3:4: Error: Bad type.'), 'my file.dart');
    expect(compilerErrorFile(r'C:\workspace\pad_1\lib\main.dart:3:4: Error: Bad type.'), 'main.dart');
  });

  test('skips warnings and generated wrappers', () {
    const output = '''
lib/old.dart:1:1: Warning: Something happened.
file:///workspace/pad_1/lib/main.dart.flutter-wrapper.dart:15:8: Error: Error when reading a file.
lib/actual.dart:2:3: Error: Bad type.
''';
    expect(compilerErrorFile(output), 'actual.dart');
  });

  test('returns null for unknown output and wrapper-only errors', () {
    expect(compilerErrorFile('Error: Compilation failed.\n#0 internal stack trace'), isNull);
    expect(compilerErrorFile('lib/main.dart:2:16:\nWarning: Something happened.'), isNull);
    expect(compilerErrorFile('file:///workspace/pad_1/lib/main.dart.flutter-wrapper.dart:1:1: Error: Failed.'), isNull);
    expect(compilerErrorFile(''), isNull);
  });

  test('does not display control characters in filenames', () {
    expect(compilerErrorFile('file:///workspace/bad%0Aname.dart:1:1: Error: Failed.'), isNull);
  });
}

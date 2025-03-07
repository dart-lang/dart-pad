// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_services/src/pub.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  group('pub', () {
    group('getAllImportsFor', () {
      test('empty', () {
        expect(extractImportStrings(getAllImportsFor('')), isEmpty);
        expect(extractImportStrings(getAllImportsFor('   \n ')), isEmpty);
      });

      test('bad source', () {
        final imports = extractImportStrings(
          getAllImportsFor('foo bar;\n baz\nimport mybad;\n'),
        );
        expect(imports, hasLength(1));
        expect(imports.single, equals(''));
      });

      test('one', () {
        const source = '''
library woot;
import 'dart:math';
import 'package:foo/foo.dart';
void main() { }
''';
        expect(
          extractImportStrings(getAllImportsFor(source)),
          unorderedEquals(['dart:math', 'package:foo/foo.dart']),
        );
      });

      test('two', () {
        const source = '''
library woot;
import 'dart:math';
 import 'package:foo/foo.dart';
import 'package:bar/bar.dart';
void main() { }
''';
        expect(
          extractImportStrings(getAllImportsFor(source)),
          unorderedEquals([
            'dart:math',
            'package:foo/foo.dart',
            'package:bar/bar.dart',
          ]),
        );
      });

      test('three', () {
        const source = '''
library woot;
import 'dart:math';
import 'package:foo/foo.dart';
import 'package:bar/bar.dart';import 'package:baz/baz.dart';
import 'mybazfile.dart';
void main() { }
''';
        expect(
          extractImportStrings(getAllImportsFor(source)),
          unorderedEquals([
            'dart:math',
            'package:foo/foo.dart',
            'package:bar/bar.dart',
            'package:baz/baz.dart',
            'mybazfile.dart',
          ]),
        );
      });
    });
  });
}

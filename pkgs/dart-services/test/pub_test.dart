// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_services/src/pub.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  group('getAllImportsFor', () {
    test('null', () {
      expect(getAllImportsFor(null), isEmpty);
    });

    test('empty', () {
      expect(getAllImportsFor(''), isEmpty);
      expect(getAllImportsFor('   \n '), isEmpty);
    });

    test('bad source', () {
      final imports = getAllImportsFor('foo bar;\n baz\nimport mybad;\n');
      expect(imports, hasLength(1));
      expect(imports.single.uri.stringValue, equals(''));
    });

    test('one', () {
      const source = '''
library woot;
import 'dart:math';
import 'package:foo/foo.dart';
void main() { }
''';
      expect(getAllImportsFor(source).map((import) => import.uri.stringValue),
          unorderedEquals(['dart:math', 'package:foo/foo.dart']));
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
          getAllImportsFor(source).map((import) => import.uri.stringValue),
          unorderedEquals(
              ['dart:math', 'package:foo/foo.dart', 'package:bar/bar.dart']));
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
          getAllImportsFor(source).map((import) => import.uri.stringValue),
          unorderedEquals([
            'dart:math',
            'package:foo/foo.dart',
            'package:bar/bar.dart',
            'package:baz/baz.dart',
            'mybazfile.dart'
          ]));
    });
  });

  group('filterSafePackagesFromImports', () {
    test('empty', () {
      const source = '''import 'package:';
void main() { }
''';
      expect(getAllImportsFor(source).filterSafePackages(), isEmpty);
    });

    test('simple', () {
      const source = '''
import 'package:foo/foo.dart';
import 'package:bar/bar.dart';
void main() { }
''';
      expect(getAllImportsFor(source).filterSafePackages(),
          unorderedEquals(['foo', 'bar']));
    });

    test('defensive', () {
      const source = '''
library woot;
import 'dart:math';
import 'package:../foo/foo.dart';
void main() { }
''';
      final imports = getAllImportsFor(source);
      expect(imports, hasLength(2));
      expect(imports[0].uri.stringValue, equals('dart:math'));
      expect(imports[1].uri.stringValue, equals('package:../foo/foo.dart'));
      expect(imports.filterSafePackages(), isEmpty);
    });

    test('negative dart import', () {
      const source = '''
import 'dart:../bar.dart';
''';
      final imports = getAllImportsFor(source);
      expect(imports, hasLength(1));
      expect(imports.single.uri.stringValue, equals('dart:../bar.dart'));
      expect(imports.filterSafePackages(), isEmpty);
    });

    test('negative path import', () {
      const source = '''
import '../foo.dart';
''';
      final imports = getAllImportsFor(source);
      expect(imports, hasLength(1));
      expect(imports.single.uri.stringValue, equals('../foo.dart'));
      expect(imports.filterSafePackages(), isEmpty);
    });
  });
}

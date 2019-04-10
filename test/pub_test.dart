// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: always_specify_types

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
      expect(getAllImportsFor('foo bar;\n baz\nimport mybad;\n'), isEmpty);
    });

    test('one', () {
      final String source = '''
library woot;
import 'dart:math';
import 'package:foo/foo.dart';
void main() { }
''';
      expect(getAllImportsFor(source),
          unorderedEquals(['dart:math', 'package:foo/foo.dart']));
    });

    test('two', () {
      final String source = '''
library woot;
import 'dart:math';
 import 'package:foo/foo.dart';
import 'package:bar/bar.dart';
void main() { }
''';
      expect(
          getAllImportsFor(source),
          unorderedEquals(
              ['dart:math', 'package:foo/foo.dart', 'package:bar/bar.dart']));
    });

    test('three', () {
      final String source = '''
library woot;
import 'dart:math';
import 'package:foo/foo.dart';
import 'package:bar/bar.dart';import 'package:baz/baz.dart';
import 'mybazfile.dart';
void main() { }
''';
      expect(
          getAllImportsFor(source),
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
      final String source = '''import 'package:';
void main() { }
''';
      expect(filterSafePackagesFromImports(getAllImportsFor(source)), isEmpty);
    });

    test('simple', () {
      final String source = '''
import 'package:foo/foo.dart';
import 'package:bar/bar.dart';
void main() { }
''';
      expect(filterSafePackagesFromImports(getAllImportsFor(source)),
          unorderedEquals(['foo', 'bar']));
    });

    test('defensive', () {
      final String source = '''
library woot;
import 'dart:math';
import 'package:../foo/foo.dart';
void main() { }
''';
      Set imports = getAllImportsFor(source);
      expect(
          imports, unorderedMatches(['dart:math', 'package:../foo/foo.dart']));
      expect(filterSafePackagesFromImports(imports), isEmpty);
    });

    test('negative dart import', () {
      final String source = '''
import 'dart:../bar.dart';
''';
      Set imports = getAllImportsFor(source);
      expect(imports, unorderedMatches(['dart:../bar.dart']));
      expect(filterSafePackagesFromImports(imports), isEmpty);
    });

    test('negative path import', () {
      final String source = '''
import '../foo.dart';
''';
      Set imports = getAllImportsFor(source);
      expect(imports, unorderedMatches(['../foo.dart']));
      expect(filterSafePackagesFromImports(imports), isEmpty);
    });
  });
}

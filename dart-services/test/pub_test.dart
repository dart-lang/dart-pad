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
      expect(getAllImportsFor('foo bar;\n baz\nimport mybad;\n'), isEmpty);
    });

    test('one', () {
      const source = '''
library woot;
import 'dart:math';
import 'package:foo/foo.dart';
void main() { }
''';
      expect(getAllImportsFor(source),
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
          getAllImportsFor(source),
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
      const source = '''import 'package:';
void main() { }
''';
      expect(filterSafePackagesFromImports(getAllImportsFor(source)), isEmpty);
    });

    test('simple', () {
      const source = '''
import 'package:foo/foo.dart';
import 'package:bar/bar.dart';
void main() { }
''';
      expect(filterSafePackagesFromImports(getAllImportsFor(source)),
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
      expect(
          imports, unorderedMatches(['dart:math', 'package:../foo/foo.dart']));
      expect(filterSafePackagesFromImports(imports), isEmpty);
    });

    test('negative dart import', () {
      const source = '''
import 'dart:../bar.dart';
''';
      final imports = getAllImportsFor(source);
      expect(imports, unorderedMatches(['dart:../bar.dart']));
      expect(filterSafePackagesFromImports(imports), isEmpty);
    });

    test('negative path import', () {
      const source = '''
import '../foo.dart';
''';
      final imports = getAllImportsFor(source);
      expect(imports, unorderedMatches(['../foo.dart']));
      expect(filterSafePackagesFromImports(imports), isEmpty);
    });
  });
}

// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dart_services/src/pub.dart';
import 'package:dart_services/src/sdk.dart';
import 'package:dart_services/src/server_cache.dart';
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

  group('PackageResolver', () {
    late final Sdk sdk;

    setUpAll(() {
      sdk =
          Sdk.create(Platform.environment['FLUTTER_CHANNEL'] ?? stableChannel);
    });

    late ServerCache serverCache;
    late PackageResolver resolver;
    late Directory tempDir;

    setUp(() {
      serverCache = InMemoryCache();
      resolver = PackageResolver(serverCache: serverCache, sdk: sdk);
      tempDir = Directory.systemTemp.createTempSync();
    });

    tearDown(() {
      resolver.dispose();
      tempDir.deleteSync(recursive: true);
    });

    test('no packages', () async {
      final result = await resolver.pubGet(tempDir, '''
void main() {
  print('hello world');
}
''');
      final package =
          result.packages.firstWhereOrNull((p) => p.name == 'lints');
      expect(package, isNotNull);
      expect(package!.version, isNotNull);
      expect(package.flutterSdkPath, isNull);
    });

    test('one package', () async {
      final result = await resolver.pubGet(tempDir, '''
import 'package:path/path.dart';

void main() {
  print('hello world');
}
''');
      expect(result.packages.length, greaterThanOrEqualTo(2));

      final names = result.packages.map((p) => p.name).toSet();
      expect(names, contains('lints'));
      expect(names, contains('path'));
    });

    test('several packages', () async {
      final result = await resolver.pubGet(tempDir, '''
import 'package:args/args.dart';
import 'package:path/path.dart';

void main() {
  print('hello world');
}
''');
      expect(result.packages.length, greaterThanOrEqualTo(3));

      final names = result.packages.map((p) => p.name).toSet();
      expect(names, contains('args'));
      expect(names, contains('path'));
    });

    test('flutter', () async {
      final result = await resolver.pubGet(tempDir, '''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  print('hello world');
}
''');
      expect(result.packages.length, greaterThanOrEqualTo(2));

      final names = result.packages.map((p) => p.name).toSet();
      expect(names, contains('collection'));
      expect(names, contains('meta'));
      expect(names, contains('flutter'));
      expect(names, contains('flutter_test'));

      final package =
          result.packages.firstWhereOrNull((p) => p.name == 'flutter');
      expect(package, isNotNull);
      expect(package!.version, isNull);
      expect(package.flutterSdkPath, isNotNull);
    });

    test('multiple runs', () async {
      const source = '''
import 'package:args/args.dart';
import 'package:path/path.dart';

void main() {
  print('hello world');
}
''';

      var result = await resolver.pubGet(tempDir, source);

      expect(result.fromCached, false);
      expect(result.packages.length, greaterThanOrEqualTo(2));

      final names = result.packages.map((p) => p.name).toSet();
      expect(names, contains('args'));
      expect(names, contains('path'));

      result = await resolver.pubGet(tempDir, source);

      expect(result.fromCached, true);
      expect(result.packages.length, greaterThanOrEqualTo(2));
    });
  });
}

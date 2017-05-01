// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.pub_test;

import 'dart:io';

import 'package:services/src/pub.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  Pub pub = new Pub();

  group('pub', () {
    test('version', () {
      String ver = pub.getVersion().toLowerCase();
      expect(ver, isNotEmpty);
      expect(ver, startsWith('pub 1.'));
    });

    test('resolvePackages simple', () {
      return pub.resolvePackages(['path']).then((PackagesInfo result) {
        expect(result, isNotNull);
        expect(result.packages, isNotEmpty);
        expect(result.packages.length, greaterThanOrEqualTo(1));
        expect(result.packages.map((p) => p.name), contains('path'));
      });
    });

    test('resolvePackages complex', () {
      return pub.resolvePackages(['grinder']).then((PackagesInfo result) {
        expect(result, isNotNull);
        expect(result.packages, isNotEmpty);
        expect(result.packages.length, greaterThanOrEqualTo(5));
        expect(result.packages.map((p) => p.name), contains('grinder'));
      });
    });

    test('getPackageLibDir', () {
      PackageInfo packageInfo = new PackageInfo('which', '0.1.2');
      return pub.getPackageLibDir(packageInfo).then((Directory libDir) {
        expect(libDir, isNotNull);
        expect(libDir.path, endsWith('lib'));
        expect(libDir.existsSync(), true);
        expect(libDir.parent.path, endsWith('which-0.1.2'));

        // Test we can get it again.
        return pub.getPackageLibDir(packageInfo).then((Directory libDir) {
          expect(libDir, isNotNull);
        });
      });
    });

    test('flushCache', () {
      expect(pub.cacheDir.listSync(), isNotEmpty);
      pub.flushCache();
      expect(pub.cacheDir.listSync(), isEmpty);
    });

    test('PackageInfo name', () {
      new PackageInfo('foo', '1');
      new PackageInfo('foo_bar', '1');
      new PackageInfo('foo_bar2', '1');
    });

    test('PackageInfo name bad', () {
      ensureBad('foo bar', '1');
      ensureBad('foobar.9', '1');
      ensureBad('../foobar', '1');
    });

    test('PackageInfo version', () {
      new PackageInfo('foo', '1.1.0');
      new PackageInfo('foo', '1.1.0-dev23');
      new PackageInfo('foo', '1.2.3+324bar');
    });

    test('PackageInfo version bad', () {
      ensureBad('foo', '1 2');
      ensureBad('foo', '../1.0.1');
      ensureBad('foo', '1.0.0/2.0.0');
    });
  });

  group('PubHelper', () {
    test('resolves content', () {
      final String source = "import 'package:path/path.dart'; void main() { }";

      return pub.createPubHelperForSource(source).then((PubHelper helper) {
        expect(helper.hasPackages, true);
        PackageInfo pInfo = helper.getPackage('path');
        expect(pInfo, isNotNull);
        expect(pInfo.name, 'path');
        expect(pInfo.version, isNotNull);
        return helper
            .getPackageContentsAsync('package:path/path.dart')
            .then((contents) {
          expect(contents, isNotEmpty);
        });
      });
    });

    test('does not resolve', () {
      final String source = "import 'package:path/path.dart; void main() { }";

      return pub.createPubHelperForSource(source).then((PubHelper helper) {
        expect(helper.hasPackages, false);
      });
    });
  });

  group('MockPub', () {
    test('no-op impls', () {
      Pub pub = new Pub.mock();
      expect(pub.cacheDir, isNull);
      expect(pub.flushCache(), null);
      expect(pub.getVersion(), null);

      return pub
          .createPubHelperForSource("import 'package:foo/foo.dart';")
          .then((helper) {
        expect(helper, isNotNull);
        return pub.resolvePackages(['foo', 'test']);
      }).then((packagesInfo) {
        expect(packagesInfo, isNotNull);
        return pub.getPackageLibDir(null);
      }).then((result) {
        expect(result, isNull);
      });
    });
  });

  group('getAllUnsafeImportsFor', () {
    test('null', () {
      expect(getAllUnsafeImportsFor(null), isEmpty);
    });

    test('empty', () {
      expect(getAllUnsafeImportsFor(''), isEmpty);
      expect(getAllUnsafeImportsFor('   \n '), isEmpty);
    });

    test('bad source', () {
      expect(
          getAllUnsafeImportsFor('foo bar;\n baz\nimport mybad;\n'), isEmpty);
    });

    test('one', () {
      final String source = '''
library woot;
import 'dart:math';
import 'package:foo/foo.dart';
void main() { }
''';
      expect(getAllUnsafeImportsFor(source),
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
          getAllUnsafeImportsFor(source),
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
          getAllUnsafeImportsFor(source),
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
      expect(filterSafePackagesFromImports(getAllUnsafeImportsFor(source)),
          isEmpty);
    });

    test('simple', () {
      final String source = '''
import 'package:foo/foo.dart';
import 'package:bar/bar.dart';
void main() { }
''';
      expect(filterSafePackagesFromImports(getAllUnsafeImportsFor(source)),
          unorderedEquals(['foo', 'bar']));
    });

    test('defensive', () {
      final String source = '''
library woot;
import 'dart:math';
import 'package:../foo/foo.dart';
void main() { }
''';
      Set imports = getAllUnsafeImportsFor(source);
      expect(
          imports, unorderedMatches(['dart:math', 'package:../foo/foo.dart']));
      expect(filterSafePackagesFromImports(imports), isEmpty);
    });

    test('negative dart import', () {
      final String source = '''
import 'dart:../bar.dart';
''';
      Set imports = getAllUnsafeImportsFor(source);
      expect(imports, unorderedMatches(['dart:../bar.dart']));
      expect(filterSafePackagesFromImports(imports), isEmpty);
    });

    test('negative path import', () {
      final String source = '''
import '../foo.dart';
''';
      Set imports = getAllUnsafeImportsFor(source);
      expect(imports, unorderedMatches(['../foo.dart']));
      expect(filterSafePackagesFromImports(imports), isEmpty);
    });
  });
}

void ensureBad(String packageName, String packageVersion) {
  try {
    /*PackageInfo info =*/ new PackageInfo(packageName, packageVersion);
    fail('${packageName}, ${packageVersion} should have failed');
  } catch (e) {
    // expected -
  }
}

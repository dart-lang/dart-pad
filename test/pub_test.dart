// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.pub_test;

import 'dart:io';

import 'package:services/src/pub.dart';
import 'package:unittest/unittest.dart';

void defineTests() {
  Pub pub = new Pub();

  group('pub', () {
    test('version', () {
      String ver = pub.getVersion().toLowerCase();
      expect(ver, isNotEmpty);
      expect(ver, startsWith('pub 1.'));
    });

    test('resolvePackages simple', () {
      return pub.resolvePackages(['test']).then((PackagesInfo result) {
        expect(result, isNotNull);
        expect(result.packages, isNotEmpty);
        expect(result.packages.length, 1);
        expect(result.packages[0].name, 'test');
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
      });
    });

    test('flushCache', () {
      expect(pub.cacheDir.listSync(), isNotEmpty);
      pub.flushCache();
      print(pub.cacheDir);
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
}

void ensureBad(String packageName, String packageVersion) {
  try {
    /*PackageInfo info =*/ new PackageInfo(packageName, packageVersion);
    fail('${packageName}, ${packageVersion} should have failed');
  } catch (e) {
    // expected -
  }
}

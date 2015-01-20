// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_server.pub_test;

import 'dart:io';

import 'package:dartpad_server/src/pub.dart';
import 'package:unittest/unittest.dart';

void defineTests() {
  Pub pub = new Pub();

  group('pub', () {
    test('version', () {
      String ver = pub.version.toLowerCase();
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
  });
}

// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.dependencies_test;

import 'package:dart_pad/core/dependencies.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  group('dependencies', () {
    test('retrieve dependency', () {
      final dependency = Dependencies();
      Dependencies.setGlobalInstance(dependency);
      expect(dependency[String], isNull);
      dependency[String] = 'foo';
      expect(dependency[String], isNotNull);
      expect(dependency[String], 'foo');
    });

    test('runInZone', () {
      final dependency = Dependencies();
      Dependencies.setGlobalInstance(dependency);
      expect(Dependencies.instance, isNotNull);
      dependency[String] = 'foo';
      dependency.runInZone(() {
        expect(Dependencies.instance, isNotNull);
        expect(dependency[String], 'foo');
      });
    });
  });
}

// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.all_test;

import 'core/dependencies_test.dart' as dependencies_test;
import 'elements/bind_test.dart' as bind_test;
import 'services/common_test.dart' as common_test;

void main() => defineTests();

void defineTests() {
  dependencies_test.defineTests();
  bind_test.defineTests();
  common_test.defineTests();
}

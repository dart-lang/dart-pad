// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad.web_test;

import 'package:unittest/html_config.dart';

import 'core/keys_test.dart' as keys_test;

void main() {
  // Set up the test environment.
  useHtmlConfiguration();

  // Define the tests.
  keys_test.defineTests();
}

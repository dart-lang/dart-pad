// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.web_test;

import 'core/dependencies_test.dart' as dependencies_test;
import 'core/keys_test.dart' as keys_test;
import 'documentation_test.dart' as documentation_test;
import 'services/common_test.dart' as common_test;
import 'sharing/gists_test.dart' as gists_test;
import 'sharing/mutable_gist_test.dart' as mutable_gist_test;

void main() {
  // Define the tests.
  dependencies_test.defineTests();
  keys_test.defineTests();
  documentation_test.defineTests();
  common_test.defineTests();
  gists_test.defineTests();
  mutable_gist_test.defineTests();
}

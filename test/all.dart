// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_server.all_test;

import 'src/analyzer_test.dart' as analyzer_test;
import 'src/bench_test.dart' as bench_test;
import 'src/common_test.dart' as common_test;
import 'common_server_test.dart' as common_server_test;
import 'src/compiler_test.dart' as compiler_test;

void main() {
  analyzer_test.defineTests();
  bench_test.defineTests();
  common_test.defineTests();
  common_server_test.defineTests();
  compiler_test.defineTests();
}

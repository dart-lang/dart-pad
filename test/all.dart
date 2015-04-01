// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.all_test;

import 'analyzer_test.dart' as analyzer_test;
import 'analysis_server_test.dart' as analysis_server_test;
import 'bench_test.dart' as bench_test;
import 'common_server_test.dart' as common_server_test;
import 'common_test.dart' as common_test;
import 'compiler_test.dart' as compiler_test;
import 'pub_test.dart' as pub_test;

void main() {
  analyzer_test.defineTests();
  analysis_server_test.defineTests();
  bench_test.defineTests();
  common_server_test.defineTests();
  common_test.defineTests();
  compiler_test.defineTests();
  pub_test.defineTests();
}

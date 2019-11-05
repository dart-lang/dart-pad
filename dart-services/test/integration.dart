// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Tests which run as part of integration testing; these test high level
/// services.
library services.integration;

import 'gae_deployed_test.dart' as gae_test_test;

void main() {
  gae_test_test.defineTests(skip: false);
}

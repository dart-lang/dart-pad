// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:unittest/unittest.dart';

_SimpleConfiguration _config;

List _callWhenFinished = [];

void setupTestConfiguration() {
  if (_config == null) {
    _config = new _SimpleConfiguration();
    unittestConfiguration = _config;
  }
}

void onTestsFinished(void testsFinished()) {
  if (_config == null) {
    throw new StateError('setupTestConfiguration() must be called');
  }

  _callWhenFinished.add(testsFinished);
}

class _SimpleConfiguration extends SimpleConfiguration {
  void onDone(bool success) {
    // TODO: We don't (can't?) handle futures here.
    for (var f in _callWhenFinished) {
      f();
    }

    super.onDone(success);
  }
}

// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library mock_analysis;

import 'dart:async';

import '../core/dependencies.dart';
import '../core/modules.dart';
import '../services/analysis.dart';
import '../services/analysis_mock.dart';

class MockAnalysisModule extends Module {
  MockAnalysisModule();

  Future init() {
    deps[AnalysisService] = new MockAnalysisService();
    return new Future.value();
  }
}

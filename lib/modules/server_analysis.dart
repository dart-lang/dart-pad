// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library server_analysis;

import 'dart:async';

import '../core/dependencies.dart';
import '../core/modules.dart';
import '../services/analysis_server.dart';

class ServerAnalysisModule extends Module {
  ServerAnalysisModule();

  Future init() {
    deps[AnalysisIssueService] = new ServerAnalysisIssueService();
    return new Future.value();
  }
}

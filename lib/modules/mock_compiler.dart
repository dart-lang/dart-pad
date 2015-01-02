// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library mock_compiler;

import 'dart:async';

import '../core/dependencies.dart';
import '../core/modules.dart';
import '../services/compiler.dart';
import '../services/compiler_mock.dart';

class MockCompilerModule extends Module {
  MockCompilerModule();

  Future init() {
    deps[CompilerService] = new MockCompilerService();
    return new Future.value();
  }
}

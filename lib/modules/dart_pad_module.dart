// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad_module;

import 'dart:async';

import '../core/dependencies.dart';
import '../core/keys.dart';
import '../core/modules.dart';
import '../elements/state.dart';

class DartPadModule extends Module {
  @override
  Future init() {
    if (Dependencies.instance == null) {
      Dependencies.setGlobalInstance(Dependencies());
    }

    deps[Keys] = Keys();
    deps[State] = HtmlState('dart_pad');

    return Future.value();
  }
}

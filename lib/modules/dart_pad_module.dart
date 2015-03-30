// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad_module;

import 'dart:async';

import '../core/dependencies.dart';
import '../core/event_bus.dart';
import '../core/keys.dart';
import '../core/modules.dart';
import '../elements/state.dart';
import '../src/options.dart';

class DartPadModule extends Module {
  Future init() {
    if (Dependencies.instance == null) {
      Dependencies.setGlobalInstance(new Dependencies());
    }

    deps[EventBus] = new EventBus();
    deps[Keys] = new Keys();
    deps[State] = new HtmlState('dart_pad');
    deps[Options] = new Options()..installIntoJsContext();

    return new Future.value();
  }
}

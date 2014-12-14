
library dartpad_ui_module;

import 'dart:async';

import '../dependencies.dart';
import '../event_bus.dart';
import '../modules.dart';

class DartpadModule extends Module {
  Future init() {
    if (Dependencies.instance == null) {
      Dependencies.setGlobalInstance(new Dependencies());
    }

    deps[EventBus] = new EventBus();

    return new Future.value();
  }
}

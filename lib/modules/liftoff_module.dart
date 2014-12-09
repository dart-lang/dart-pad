
library liftoff_module;

import 'dart:async';

import '../dependencies.dart';
import '../event_bus.dart';
import '../modules.dart';

class LiftoffModule extends Module {
  Future init() {
    if (Dependencies.instance == null) {
      Dependencies.setGlobalInstance(new Dependencies());
    }

    Dependencies.instance[EventBus] = new EventBus();

    return new Future.value();
  }
}

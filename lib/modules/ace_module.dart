
library ace_module;

import '../modules.dart';
import '../dependencies.dart';
import '../editing/editor_ace.dart';

class AceModule extends Module {
  Future init() {
    deps[EditorFactory] = aceFactory;

    if (!aceFactory.inited) {
      return aceFactory.init();
    } else {
      return new Future.value();
    }
  }
}

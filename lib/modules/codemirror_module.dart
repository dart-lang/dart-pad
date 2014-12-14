
library codemirror_module;

import '../modules.dart';
import '../dependencies.dart';
import '../editing/editor_codemirror.dart';

class CodeMirrorModule extends Module {
  Future init() {
    deps[EditorFactory] = codeMirrorFactory;

    if (!codeMirrorFactory.inited) {
      return codeMirrorFactory.init();
    } else {
      return new Future.value();
    }
  }
}

// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library codemirror_module;

import '../core/modules.dart';
import '../core/dependencies.dart';
import '../editing/editor_codemirror.dart';

class CodeMirrorModule extends Module {
  static String get version => codeMirrorFactory.version;

  Future init() {
    deps[EditorFactory] = codeMirrorFactory;

    if (!codeMirrorFactory.inited) {
      return codeMirrorFactory.init();
    } else {
      return new Future.value();
    }
  }
}

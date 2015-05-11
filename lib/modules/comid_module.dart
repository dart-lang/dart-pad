// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library codemirror_module;

import '../core/modules.dart';
import '../core/dependencies.dart';
import '../editing/editor_comid.dart';

class CodeMirrorModule extends Module {
  Future init() {
    deps[EditorFactory] = comidFactory;

    if (!comidFactory.inited) {
      return comidFactory.init();
    } else {
      return new Future.value();
    }
  }
}

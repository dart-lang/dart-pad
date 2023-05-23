// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../core/dependencies.dart';
import '../core/modules.dart';
import '../editing/editor_codemirror.dart';

class CodeMirrorModule extends Module {
  static String? get version => codeMirrorFactory.version;

  @override
  Future<void> init() async {
    deps[EditorFactory] = codeMirrorFactory;
  }
}

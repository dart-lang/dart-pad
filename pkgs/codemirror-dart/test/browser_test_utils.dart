// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

void verifyCodeMirrorBundleLoaded() {
  if (!web.window.hasProperty('_codemirror'.toJS).toDart) {
    throw StateError('The CodeMirror bundle was not loaded by the test page.');
  }
}

JSObject get codeMirrorNamespace => web.window.getProperty<JSObject>('_codemirror'.toJS);

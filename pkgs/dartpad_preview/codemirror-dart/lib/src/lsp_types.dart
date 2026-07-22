// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@JS('window._codemirror')
library;

import 'dart:js_interop';

import 'types.dart';

/// Client interface for communicating with an LSP server.
extension type LSPClient._(JSObject _) implements JSObject {
  external void sync();
  external JSPromise request(JSString method, JSObject params);
}

/// Represents an LSP code action returned from the language server.
extension type LSPCodeAction(JSObject _) implements JSObject {
  external JSString get title;
  external JSString? get kind;
  external JSObject? get edit;
  external JSObject? get command;
}

/// Plugin providing LSP integration for an [EditorView].
extension type LSPPlugin._(JSObject _) implements JSObject {
  external static LSPPlugin? get(EditorView view);

  external LSPClient get client;
  external JSString get uri;
  external JSObject toPosition(int pos);
  external int fromPosition(JSObject pos);
}

// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@JS('window._codemirror')
library;

import 'dart:js_interop';

import 'types.dart';

// =============================================================================
// Setup & Themes
// =============================================================================

@JS()
external JSAny get basicSetup;

@JS()
external JSAny get defaultHighlightStyle;

@JS()
external JSAny get oneDark;

/// Options for the `syntaxHighlighting` function.
///
/// See: https://codemirror.net/docs/ref/#language.syntaxHighlighting
extension type SyntaxHighlightingOptions._(JSObject _) implements JSObject {
  external factory SyntaxHighlightingOptions({bool? fallback});
}

@JS()
external JSAny syntaxHighlighting(JSAny style, [SyntaxHighlightingOptions? options]);

// =============================================================================
// Keymaps & Commands
// =============================================================================

@JS()
external JSAny get indentWithTab;

@JS('keymap.of')
external JSAny keymapOf(JSArray<KeyBinding> bindings);

@JS()
external JSFunction get toggleLineComment;

@JS()
external JSFunction get formatDocument;

/// Formats [view] and resolves after the returned edits have been applied.
@JS()
external JSPromise<JSBoolean> formatDocumentAsync(EditorView view);

// =============================================================================
// Navigation
// =============================================================================

@JS()
external JSAny gotoDefinitionOnClick();

// =============================================================================
// Linting & Diagnostics
// =============================================================================

@JS()
external JSAny lintGutter();

@JS()
external JSAny linter(JSFunction? source);

@JS()
external JSAny diagnosticHoverToolbar(JSArray<ToolbarAction> actions);

/// An action shown in the diagnostic hover toolbar.
@JS()
@anonymous
extension type ToolbarAction._(JSObject _) implements JSObject {
  external factory ToolbarAction({
    JSString label,
    JSFunction run,
  });
}

/// Represents a diagnostic (error, warning, etc.) reported by a linter.
///
/// See: https://codemirror.net/docs/ref/#lint.Diagnostic
extension type CMDiagnostic(JSObject _) implements JSObject {
  external int get from;
  external int get to;
  external JSString get severity;
  external JSString get message;
}

// =============================================================================
// Panels
// =============================================================================

@JS()
external ShowPanel get showPanel;

// =============================================================================
// State Effects
// =============================================================================

@JS()
external StateEffectType get forceSemanticTokensRefresh;

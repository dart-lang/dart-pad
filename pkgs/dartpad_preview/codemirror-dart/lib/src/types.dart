// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@JS('window._codemirror')
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

// =============================================================================
// State Types
// =============================================================================

/// A type used to succinctly describe document changes. It may either be a
/// plain object describing a change (a deletion, insertion, or replacement,
/// depending on which fields are present), a `ChangeSet`, or an array of
/// change specs.
///
/// See: https://codemirror.net/docs/ref/#state.ChangeSpec
extension type ChangeSpec._(JSObject _) implements JSObject {
  external factory ChangeSpec({int from, int? to, JSString? insert});

  external int get from;
  external int get to;
}

/// Extension compartments can be used to make a configuration dynamic.
/// By wrapping part of your configuration in a compartment, you can later
/// replace that part through a transaction.
///
/// See: https://codemirror.net/docs/ref/#state.Compartment
extension type Compartment._(JSObject _) implements JSObject {
  external factory Compartment();
  external JSAny of(JSAny extension);
  external JSAny reconfigure(JSAny extension);
}

/// An editor selection holds one or more selection ranges.
///
/// See: https://codemirror.net/docs/ref/#state.EditorSelection
extension type EditorSelection(JSObject _) implements JSObject {
  external static SelectionRange cursor(int pos);
  external static EditorSelection create(JSArray<SelectionRange> ranges, [int? mainIndex]);
  external static SelectionRange range(int anchor, int head);

  external JSArray<SelectionRange> get ranges;
  external SelectionRange get main;
}

/// The editor state class is a persistent (immutable) data structure.
/// To update a state, you create a transaction, which produces a _new_ state
/// instance, without modifying the original object.
///
/// As such, _never_ mutate properties of a state directly. That'll
/// just break things.
///
/// See: https://codemirror.net/docs/ref/#state.EditorState
extension type EditorState(JSObject _) implements JSObject {
  external static EditorState create(EditorStateConfig config);
  external static Facet get languageData;

  external Text get doc;
  external EditorSelection get selection;
}

/// Options passed when creating an editor state.
///
/// See: https://codemirror.net/docs/ref/#state.EditorStateConfig
extension type EditorStateConfig._(JSObject _) implements JSObject {
  external factory EditorStateConfig({
    JSString? doc,
    EditorSelection? selection,
    JSArray<JSAny>? extensions,
  });
}

/// A single selection range. When
/// `allowMultipleSelections` is enabled, a selection may hold
/// multiple ranges. By default, selections hold exactly one range.
///
/// See: https://codemirror.net/docs/ref/#state.SelectionRange
extension type SelectionRange(JSObject _) implements JSObject {
  external int get anchor;
  external int get head;
  external int get from;
  external int get to;
  external bool get empty;
}

/// The data structure for documents.
///
/// See: https://codemirror.net/docs/ref/#state.Text
extension type Text(JSObject _) implements JSObject {
  external int get length;
  external int get lines;
  external Line line(int line);

  @JS('toString')
  external JSString toJsString();
}

/// This type describes a line in the document. It is created
/// on-demand when lines are queried.
///
/// See: https://codemirror.net/docs/ref/#state.Line
extension type Line(JSObject _) implements JSObject {
  external int get from;
  external int get to;
  external int get length;
  external JSString get text;
}

/// Describes a transaction when calling `EditorState.update`.
///
/// See: https://codemirror.net/docs/ref/#state.TransactionSpec
extension type TransactionSpec._(JSObject _) implements JSObject {
  external factory TransactionSpec({
    JSAny? changes, // ChangeSpec or JSArray<ChangeSpec>
    EditorSelection? selection,
    JSAny? effects, // JSAny or JSArray<JSAny>
    JSAny? scrollIntoView,
  });
}

/// Representation of a type of state effect. Defined with
/// `StateEffect.define`.
///
/// See: https://codemirror.net/docs/ref/#state.StateEffectType
extension type StateEffectType(JSObject _) implements JSObject {
  external StateEffect of(JSAny? value);
}

/// State effects can be used to represent additional effects
/// associated with a transaction. They are often useful to model
/// changes to custom state fields, when those changes aren't implicit
/// in document or selection changes.
///
/// See: https://codemirror.net/docs/ref/#state.StateEffect
extension type StateEffect(JSObject _) implements JSObject {}

/// A facet is a labeled value that is associated with an editor state.
/// It takes inputs from any number of extensions, and combines those
/// into a single output value.
///
/// See: https://codemirror.net/docs/ref/#state.Facet
extension type Facet._(JSObject _) implements JSObject {
  external JSAny of(JSAny value);
}

// =============================================================================
// View Types
// =============================================================================

/// An editor view represents the editor's user interface. It holds
/// the editable DOM surface, and possibly other elements such as the
/// line number gutter. It handles events and dispatches state
/// transactions for editing actions.
///
/// See: https://codemirror.net/docs/ref/#view.EditorView
extension type EditorView._(JSObject _) implements JSObject {
  external factory EditorView(EditorViewConfig config);

  external EditorState get state;
  external void dispatch(TransactionSpec spec);
  external void destroy();
  external void requestMeasure();
  external void focus();
  external web.HTMLElement get scrollDOM;
  external web.HTMLElement get dom;
  external Rect? coordsAtPos(int pos, [int? side]);

  external static UpdateListener get updateListener;

  external static JSAny scrollIntoView(int pos, [ScrollIntoViewOptions? options]);
}

/// The type of object given to the [EditorView] constructor.
///
/// See: https://codemirror.net/docs/ref/#view.EditorViewConfig
extension type EditorViewConfig._(JSObject _) implements JSObject {
  external factory EditorViewConfig({
    EditorState? state,
    web.HTMLElement? parent,
  });
}

/// Key bindings associate key names with command-style functions.
///
/// Key names may be strings like `"Shift-Ctrl-Enter"` — a key identifier
/// prefixed with zero or more modifiers. Use `Mod-` as a shorthand for
/// `Cmd-` on Mac and `Ctrl-` on other platforms.
///
/// See: https://codemirror.net/docs/ref/#view.KeyBinding
extension type KeyBinding._(JSObject _) implements JSObject {
  external factory KeyBinding({
    JSString key,
    JSFunction run,
    bool? preventDefault,
  });
}

/// Object type used to represent a panel that is shown above or below
/// the editor.
///
/// See: https://codemirror.net/docs/ref/#view.Panel
@anonymous
extension type Panel._(JSObject _) implements JSObject {
  external factory Panel({
    web.HTMLElement dom,
    JSFunction? mount,
    JSFunction? update,
    JSFunction? destroy,
    bool? top,
  });
}

/// A rectangle with left, right, top, and bottom properties,
/// as returned by [EditorView.coordsAtPos].
extension type Rect(JSObject _) implements JSObject {
  external double get left;
  external double get right;
  external double get top;
  external double get bottom;
}

/// Options for [EditorView.scrollIntoView].
extension type ScrollIntoViewOptions._(JSObject _) implements JSObject {
  external factory ScrollIntoViewOptions({JSString? y});
}

/// A facet that can be used to register a panel to be shown
/// above or below the editor.
///
/// See: https://codemirror.net/docs/ref/#view.showPanel
extension type ShowPanel._(JSObject _) implements JSObject {
  external JSAny of(JSFunction createPanel);
}

/// A facet that can be used to register a function to be called
/// every time the view updates.
///
/// See: https://codemirror.net/docs/ref/#view.EditorView^updateListener
extension type UpdateListener(JSObject _) implements JSObject {
  external JSAny of(JSFunction callback);
}

/// View plugins are given instances of this class, which describe
/// what happened, whenever the view is updated.
///
/// See: https://codemirror.net/docs/ref/#view.ViewUpdate
extension type ViewUpdate(JSObject _) implements JSObject {
  external bool get docChanged;
  external EditorState get state;
}

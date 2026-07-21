// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_interop';

import 'package:codemirror_dart/codemirror_dart.dart' as cm;
import 'package:web/web.dart' as web;

import '../workspace/workspace_controller.dart';

/// Represents the scroll and selection state of a [CodeMirrorEditor].
class EditorViewState {
  final double scrollTop;
  final double scrollLeft;
  final cm.EditorSelection selection;

  EditorViewState({
    required this.scrollTop,
    required this.scrollLeft,
    required this.selection,
  });
}

/// A wrapper around CodeMirror 6's [cm.EditorView] that integrates with
/// the [WorkspaceController] and language server features (such as syntax highlighting,
/// diagnostics, code actions, renaming, and hover tooltips).
final class CodeMirrorEditor {
  CodeMirrorEditor._(this.view, this.workspaceController, this.langCompartment, this.file);

  /// The active file path.
  String file;

  /// The underlying CodeMirror [cm.EditorView] instance.
  final cm.EditorView view;

  final WorkspaceController workspaceController;
  final cm.Compartment langCompartment;

  /// Creates a new [CodeMirrorEditor] inside the given [element].
  ///
  /// The editor is configured with Dart syntax highlighting and LSP integration
  /// if the specified [file] is a Dart file.
  ///
  /// Optional callbacks can be provided:
  /// - [onUpdate] is triggered when the document text changes.
  /// - [onSave] is triggered on Cmd/Ctrl+S keypress.
  /// - [onCodeActionRequested] is triggered on Cmd/Ctrl+. keypress.
  /// - [onFixDiagnostic] is triggered when applying diagnostic fixes.
  factory CodeMirrorEditor(
    web.HTMLElement element, {
    required String file,
    String? initialDoc,
    required WorkspaceController workspaceController,
    void Function(String text)? onUpdate,
    void Function()? onSave,
    void Function()? onCodeActionRequested,
    void Function(int from, int to, String message)? onFixDiagnostic,
  }) {
    final langCompartment = cm.Compartment();

    final state = cm.EditorState.create(
      cm.EditorStateConfig(
        doc: (initialDoc ?? '').toJS,
        extensions: [
          // Intercept Mod-Shift-M (diagnostics panel shortcut) to prevent default panel from opening.
          cm.keymapOf(
            [
              cm.KeyBinding(key: 'Mod-Shift-m'.toJS, run: ((cm.EditorView view) => true.toJS).toJS),
              cm.KeyBinding(key: 'Mod-Shift-M'.toJS, run: ((cm.EditorView view) => true.toJS).toJS),
            ].toJS,
          ),
          cm.basicSetup,
          cm.gotoDefinitionOnClick(),
          cm.keymapOf([cm.indentWithTab as cm.KeyBinding].toJS),
          cm.oneDark,
          cm.lintGutter(),
          cm.linter(null),
          cm.syntaxHighlighting(
            cm.defaultHighlightStyle,
            cm.SyntaxHighlightingOptions(fallback: true),
          ),
          cm.EditorView.updateListener.of(
            ((cm.ViewUpdate update) {
              if (update.docChanged && onUpdate != null) {
                onUpdate(update.state.doc.toJsString().toDart);
              }
            }).toJS,
          ),
          if (onSave != null)
            cm.keymapOf(
              [
                cm.KeyBinding(
                  key: 'Mod-s'.toJS,
                  run: ((cm.EditorView view) {
                    onSave();
                    return true.toJS;
                  }).toJS,
                ),
              ].toJS,
            ),
          langCompartment.of(
            _languageExtension(file, workspaceController),
          ),
          if (onCodeActionRequested != null)
            cm.keymapOf(
              [
                cm.KeyBinding(
                  key: 'Mod-.'.toJS,
                  run: ((cm.EditorView view) {
                    onCodeActionRequested();
                    return true.toJS;
                  }).toJS,
                ),
              ].toJS,
            ),
          if (onFixDiagnostic != null)
            cm.diagnosticHoverToolbar(
              [
                cm.ToolbarAction(
                  label: 'Fix with Agent'.toJS,
                  run: ((cm.EditorView view, int from, int to, JSArray<JSObject> diagnostics) {
                    final list = diagnostics.toDart;
                    if (list.isNotEmpty) {
                      final diag = cm.CMDiagnostic(list.first);
                      onFixDiagnostic(from, to, diag.message.toDart);
                    }
                  }).toJS,
                ),
              ].toJS,
            ),
        ].toJS,
      ),
    );

    final view = cm.EditorView(
      cm.EditorViewConfig(
        state: state,
        parent: element,
      ),
    );

    return CodeMirrorEditor._(view, workspaceController, langCompartment, file);
  }

  /// Gets the current text content of the editor.
  String get text => view.state.doc.toJsString().toDart;

  /// Sets the text content of the editor, replacing the entire document.
  set text(String value) {
    view.dispatch(
      cm.TransactionSpec(
        changes: cm.ChangeSpec(
          from: 0,
          to: view.state.doc.length,
          insert: value.toJS,
        ),
      ),
    );
  }

  /// Applies a list of LSP document edits to the editor.
  void applyEdits(List<dynamic> edits) {
    if (edits.isEmpty) {
      return;
    }

    final doc = view.state.doc;
    final changeSpecs = edits.map((e) {
      final editMap = Map<String, dynamic>.from(e as Map);
      final range = editMap['range'] as Map;
      final start = range['start'] as Map;
      final end = range['end'] as Map;

      final startLine = start['line'] as int;
      final startChar = start['character'] as int;
      final endLine = end['line'] as int;
      final endChar = end['character'] as int;

      final startOffset = doc.line(startLine + 1).from + startChar;
      final endOffset = doc.line(endLine + 1).from + endChar;
      final newText = editMap['newText'] as String;

      return cm.ChangeSpec(
        from: startOffset,
        to: endOffset,
        insert: newText.toJS,
      );
    }).toList();

    changeSpecs.sort((specA, specB) => specA.from.compareTo(specB.from));

    view.dispatch(
      cm.TransactionSpec(
        changes: changeSpecs.toJS,
      ),
    );
  }

  /// Requests formatting through the LSP client.
  ///
  /// Returns whether a formatting request was started. The resulting edits are
  /// delivered asynchronously through the editor update listener.
  bool format() {
    if (!_isDartFile(file)) {
      return false;
    }

    return (cm.formatDocument.callAsFunction(null, view) as JSBoolean?)?.toDart ?? false;
  }

  /// Focuses the editor input.
  void focus() {
    view.focus();
  }

  /// Destroys the editor view.
  void destroy() {
    view.destroy();
  }

  /// Reconfigures language-specific extensions when a file is renamed or swapped.
  void applyRename(String filename) {
    file = filename;
    view.dispatch(
      cm.TransactionSpec(
        effects: langCompartment.reconfigure(
          _languageExtension(filename, workspaceController),
        ),
      ),
    );
  }

  /// Triggers a refresh of the LSP semantic tokens/highlighting.
  void triggerLspRefresh() {
    view.dispatch(
      cm.TransactionSpec(
        effects: cm.forceSemanticTokensRefresh.of(null),
      ),
    );
  }

  /// Saves the current scroll and selection state of the editor.
  EditorViewState saveViewState() {
    return EditorViewState(
      scrollTop: view.scrollDOM.scrollTop,
      scrollLeft: view.scrollDOM.scrollLeft,
      selection: view.state.selection,
    );
  }

  /// Restores a previously saved [EditorViewState] (scroll and selection).
  void restoreViewState(EditorViewState state) {
    view.dispatch(
      cm.TransactionSpec(
        selection: state.selection,
      ),
    );
    web.window.requestAnimationFrame(
      ((double time) {
        view.scrollDOM.scrollTop = state.scrollTop;
        view.scrollDOM.scrollLeft = state.scrollLeft;
      }).toJS,
    );
  }

  /// Requests a layout measurement from CodeMirror.
  void requestMeasure() {
    view.requestMeasure();
  }

  /// Moves the cursor to the specified [line] and [character] position, and scrolls it into view.
  ///
  /// The [line] and [character] parameters are 0-indexed.
  void goToPosition(int line, int character) {
    final doc = view.state.doc;
    final safeLine = (line + 1).clamp(1, doc.lines);
    final lineInfo = doc.line(safeLine);
    final safeCharacter = character.clamp(0, lineInfo.length);
    final pos = lineInfo.from + safeCharacter;

    view.dispatch(
      cm.TransactionSpec(
        selection: cm.EditorSelection.cursor(pos),
        effects: cm.EditorView.scrollIntoView(
          pos,
          cm.ScrollIntoViewOptions(y: 'center'.toJS),
        ),
      ),
    );
    view.focus();
  }

  /// Hides all active tooltips in the CodeMirror editor.
  static void hideAllTooltips() {
    final tooltips = web.document.querySelectorAll('.cm-tooltip');
    for (int i = 0; i < tooltips.length; i++) {
      final el = tooltips.item(i) as web.HTMLElement?;
      if (el != null) {
        el.style.visibility = 'hidden';
        el.style.opacity = '0';
        el.style.pointerEvents = 'none';
      }
    }
  }
}

bool _isDartFile(String fileName) => fileName.endsWith('.dart');

/// Returns the CodeMirror language extension for Dart or non-Dart files, or null.
JSAny _languageExtension(String fileName, WorkspaceController workspaceController) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.dart')) {
    return [
      cm.dart(),
      workspaceController.languageServerClient.codeMirrorLspClient.createExtension(
        workspaceController.workspaceUri.resolve(fileName).toString(),
      ),
      cm.keymapOf(
        [
          cm.KeyBinding(
            key: 'Shift-Alt-f'.toJS,
            run: cm.formatDocument,
            preventDefault: true,
          ),
          cm.KeyBinding(
            key: 'Shift-Alt-F'.toJS,
            run: cm.formatDocument,
            preventDefault: true,
          ),
          cm.KeyBinding(
            key: 'Shift-Alt-Ï'.toJS,
            run: cm.formatDocument,
            preventDefault: true,
          ),
        ].toJS,
      ),
    ].toJS;
  }
  if (lower.endsWith('.yaml') || lower.endsWith('.yml') || lower.endsWith('.lock')) {
    return cm.yaml();
  }
  if (lower.endsWith('.md')) {
    return cm.markdown();
  }
  if (lower.endsWith('.js') || lower.endsWith('.ts')) {
    return cm.javascript();
  }
  if (lower.endsWith('.html')) {
    return cm.html();
  }
  if (lower.endsWith('.css')) {
    return cm.css();
  }
  if (lower.endsWith('.json')) {
    return cm.json();
  }
  if (lower.endsWith('.xml')) {
    return cm.xml();
  }
  if (lower.endsWith('.scss') || lower.endsWith('.sass')) {
    return cm.sass();
  }
  if (lower.endsWith('.sql')) {
    return cm.sql();
  }
  return JSArray();
}

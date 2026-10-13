// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_interop';

import 'package:codemirror_dart/codemirror_dart.dart' as cm;
import 'package:web/web.dart' as web;

/// What should happen to the program in a pad when the page loads.
enum PadPreview {
  /// Run the program as soon as the pad scrolls into view.
  start,

  /// Show a run button and a console, but wait for the user.
  pause,

  /// Just an editor, no run button or console.
  none,
}

/// Where the console goes.
enum PadLayout {
  /// Console below the editor.
  vertical,

  /// Console to the right of the editor, below it when there is no room.
  horizontal,
}

/// A `<pre data-dartpad-filename="...">` element on the page, read once at
/// startup.
///
/// ```html
/// <pre data-dartpad-filename="hello.dart"
///      data-dartpad-preview="start"
///      data-dartpad-layout="horizontal"
///      data-dartpad-output="hi"><code>void main() => print('hi');</code></pre>
/// ```
final class PadSpec {
  /// Name of the file holding the code, from `data-dartpad-filename`, which
  /// is what marks an element as a pad.
  final String filename;

  /// Whether, and when, to run the program, [PadPreview.pause] unless given.
  final PadPreview preview;

  /// Where the console goes, [PadLayout.vertical] unless given.
  final PadLayout layout;

  /// Initial code, the text content of the element.
  final String code;

  /// What the console shows before the program has run, if anything; so a
  /// page can show the output of a program without running it.
  final String? output;

  PadSpec({required this.filename, required this.preview, required this.layout, required this.code, this.output});

  factory PadSpec.fromElement(web.HTMLElement element) {
    final preview = element.getAttribute('data-dartpad-preview');
    final layout = element.getAttribute('data-dartpad-layout');
    return PadSpec(
      filename: element.getAttribute('data-dartpad-filename')!,
      preview: PadPreview.values.asNameMap()[preview] ?? PadPreview.pause,
      layout: PadLayout.values.asNameMap()[layout] ?? PadLayout.vertical,
      // Markdown renderers leave a trailing newline inside the <code> element.
      code: element.textContent!.replaceFirst(RegExp(r'\n$'), ''),
      output: element.getAttribute('data-dartpad-output'),
    );
  }
}

/// One inline DartPad: a CodeMirror editor, run and reset buttons and a
/// console.
///
/// The root [element] carries state for stylesheets to pick up:
///  * `data-layout`, `vertical` or `horizontal`,
///  * `data-preview`, the [PadPreview] name,
///  * `data-state`, `idle` or `running`, and
///  * `data-modified`, present once the code differs from the original.
final class Pad {
  /// Path of the file holding the code, relative to the workspace folder.
  ///
  /// This is [PadSpec.filename], unless another pad on the page has the same
  /// name, see [uniqueFilenames].
  final String path;

  final PadSpec spec;

  /// Root element replacing the original `<pre>`.
  final web.HTMLElement element;
  final web.HTMLButtonElement? _runButton;
  final web.HTMLButtonElement _resetButton;
  final web.HTMLElement? _console;
  final web.HTMLElement? _status;

  late final cm.EditorView _view;
  final _lspCompartment = cm.Compartment();

  Pad._(this.path, this.spec, this.element, this._runButton, this._resetButton, this._console, this._status);

  /// Creates the pad UI inside a new element and mounts an editor in it.
  ///
  /// The [onRun] callback is invoked for the run button and `Mod-Enter`, it is
  /// `null` for pads with [PadPreview.none].
  factory Pad.mount(String path, PadSpec spec, {required void Function(Pad pad)? onRun}) {
    final element = web.HTMLDivElement()
      ..className = 'inline-dartpad'
      ..setAttribute('data-layout', spec.layout.name)
      ..setAttribute('data-preview', spec.preview.name)
      ..setAttribute('data-state', 'idle');
    final editorHost = web.HTMLDivElement()..className = 'inline-dartpad-editor';
    element.append(editorHost);

    final resetButton = web.HTMLButtonElement()
      ..className = 'inline-dartpad-reset'
      ..type = 'button'
      ..title = 'Restore the original code'
      ..textContent = 'Reset'
      ..hidden = true.toJS;
    final controls = web.HTMLDivElement()
      ..className = 'inline-dartpad-controls'
      ..append(
        web.HTMLSpanElement()
          ..className = 'inline-dartpad-filename'
          ..textContent = spec.filename,
      )
      ..append(resetButton);
    web.HTMLButtonElement? runButton;
    web.HTMLElement? console;
    web.HTMLElement? status;
    if (onRun != null) {
      runButton = web.HTMLButtonElement()
        ..className = 'inline-dartpad-run'
        ..type = 'button'
        ..title = 'Run (Ctrl+Enter)'
        ..textContent = 'Run';
      controls.append(runButton);
      status = web.HTMLDivElement()..className = 'inline-dartpad-status';
      console = web.document.createElement('pre') as web.HTMLPreElement
        ..className = 'inline-dartpad-console'
        ..setAttribute('aria-live', 'polite')
        ..textContent = spec.output ?? '';
      final output = web.HTMLDivElement()
        ..className = 'inline-dartpad-output'
        ..append(status)
        ..append(console);
      element.append(output);
    }
    element.append(controls);

    final pad = Pad._(path, spec, element, runButton, resetButton, console, status);
    runButton?.onclick = ((web.Event _) => onRun!(pad)).toJS;
    resetButton.onclick = ((web.Event _) => pad.reset()).toJS;

    pad._view = cm.EditorView(
      cm.EditorViewConfig(
        state: cm.EditorState.create(
          cm.EditorStateConfig(
            doc: spec.code.toJS,
            extensions: [
              if (onRun != null)
                cm.keymapOf(
                  [
                    cm.KeyBinding(
                      key: 'Mod-Enter'.toJS,
                      run: ((cm.EditorView _) {
                        if (!runButton!.disabled) {
                          onRun(pad);
                        }
                        return true.toJS;
                      }).toJS,
                    ),
                  ].toJS,
                ),
              cm.keymapOf(cm.extraKeymap),
              cm.basicSetup,
              cm.indentUnitOf('  '.toJS),
              cm.gotoDefinitionOnClick(),
              cm.keymapOf([cm.indentWithTab as cm.KeyBinding].toJS),
              cm.dartpadTheme,
              cm.lintGutter(),
              cm.linter(null),
              cm.syntaxHighlighting(cm.defaultHighlightStyle, cm.SyntaxHighlightingOptions(fallback: true)),
              cm.dart(),
              cm.EditorView.updateListener.of(
                ((cm.ViewUpdate update) {
                  if (update.docChanged) {
                    pad._setModified(pad.code != spec.code);
                  }
                }).toJS,
              ),
              pad._lspCompartment.of(JSArray<JSAny>()),
            ].toJS,
          ),
        ),
        parent: editorHost,
      ),
    );
    return pad;
  }

  /// The code currently in the editor.
  String get code => _view.state.doc.toJsString().toDart;

  /// Puts the original code back into the editor.
  void reset() {
    _view.dispatch(
      cm.TransactionSpec(changes: {'from': 0, 'to': _view.state.doc.length, 'insert': spec.code}.jsify()),
    );
    _view.focus();
  }

  void _setModified(bool modified) {
    _resetButton.hidden = (!modified).toJS;
    if (modified) {
      element.setAttribute('data-modified', '');
    } else {
      element.removeAttribute('data-modified');
    }
  }

  /// Connects the editor to a language server, or disconnects it when
  /// [extension] is `null`.
  void setLanguageServer(JSObject? extension) {
    _view.dispatch(cm.TransactionSpec(effects: _lspCompartment.reconfigure(extension ?? JSArray<JSAny>())));
  }

  /// Shows [text] as the status of a run in progress, or marks the pad idle
  /// again when `null`.
  void setStatus(String? text) {
    _status?.textContent = text ?? '';
    _runButton?.disabled = text != null;
    element.setAttribute('data-state', text != null ? 'running' : 'idle');
  }

  /// Clears the console.
  void clearConsole() {
    _console?.textContent = '';
  }

  /// Appends a line to the console.
  void appendConsole(String line, {bool error = false}) {
    final console = _console;
    if (console == null) {
      return;
    }
    final span = web.HTMLSpanElement()..textContent = '$line\n';
    if (error) {
      span.className = 'inline-dartpad-error';
    }
    console.append(span);
    console.scrollTop = console.scrollHeight;
  }
}

/// Makes [filenames] unique by inserting `~1`, `~2`, ... before the extension
/// of any name already taken by an earlier one: `main.dart`, `main.dart`
/// becomes `main.dart`, `main~1.dart`.
List<String> uniqueFilenames(Iterable<String> filenames) {
  final taken = <String>{};
  final result = <String>[];
  for (final filename in filenames) {
    final dot = filename.lastIndexOf('.');
    final (stem, extension) = dot > filename.lastIndexOf('/') + 1
        ? (filename.substring(0, dot), filename.substring(dot))
        : (filename, '');
    var candidate = filename;
    for (var i = 1; !taken.add(candidate); i++) {
      candidate = '$stem~$i$extension';
    }
    result.add(candidate);
  }
  return result;
}

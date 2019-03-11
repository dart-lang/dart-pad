// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library editor.codemirror;

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js';
import 'dart:math';

import 'package:codemirror/codemirror.dart' hide Position;
import 'package:codemirror/codemirror.dart' as pos show Position;
import 'package:codemirror/hints.dart';

import 'editor.dart' hide Position;
import 'editor.dart' as ed show Position;

export 'editor.dart';

final CodeMirrorFactory codeMirrorFactory = CodeMirrorFactory._();

class CodeMirrorFactory extends EditorFactory {
  CodeMirrorFactory._();

  String get version => CodeMirror.version;

  @override
  List<String> get modes => CodeMirror.MODES;

  @override
  List<String> get themes => CodeMirror.THEMES;

  @override
  Editor createFromElement(html.Element element, {Map options}) {
    options ??= {
      'continueComments': {'continueLineComment': false},
      'autofocus': false,
      // Removing this - with this enabled you can't type a forward slash.
      //'autoCloseTags': true,
      'autoCloseBrackets': true,
      'matchBrackets': true,
      'tabSize': 2,
      'lineWrapping': true,
      'indentUnit': 2,
      'cursorHeight': 0.85,
      // Increase the number of lines that are rendered above and before
      // what's visible.
      'viewportMargin': 100,
      //'gutters': [_gutterId],
      'extraKeys': {'Cmd-/': 'toggleComment', 'Ctrl-/': 'toggleComment'},
      'hintOptions': {'completeSingle': false},
      //'lint': true,
      'theme': 'zenburn' // ambiance, vibrant-ink, monokai, zenburn
    };

    CodeMirror editor = CodeMirror.fromElement(element, options: options);
    CodeMirror.addCommand('goLineLeft', _handleGoLineLeft);
    return _CodeMirrorEditor._(this, editor);
  }

  @override
  void registerCompleter(String mode, CodeCompleter completer) {
    Hints.registerHintsHelperAsync(mode, (CodeMirror editor,
        [HintsOptions options]) {
      return _completionHelper(editor, completer, options);
    });
  }

  // Change the cmd-left behavior to move the cursor to the leftmost non-ws char.
  void _handleGoLineLeft(CodeMirror editor) {
    editor.execCommand('goLineLeftSmart');
  }

  Future<HintResults> _completionHelper(
      CodeMirror editor, CodeCompleter completer, HintsOptions options) {
    _CodeMirrorEditor ed = _CodeMirrorEditor._fromExisting(this, editor);

    return completer
        .complete(ed, onlyShowFixes: ed._lookingForQuickFix)
        .then((CompletionResult result) {
      Doc doc = editor.getDoc();
      pos.Position from = doc.posFromIndex(result.replaceOffset);
      pos.Position to =
          doc.posFromIndex(result.replaceOffset + result.replaceLength);
      String stringToReplace = doc.getValue().substring(
          result.replaceOffset, result.replaceOffset + result.replaceLength);

      List<HintResult> hints = result.completions.map((Completion completion) {
        return HintResult(completion.value,
            displayText: completion.displayString,
            className: completion.type, hintApplier: (CodeMirror editor,
                HintResult hint, pos.Position from, pos.Position to) {
          doc.replaceRange(hint.text, from, to);
          if (completion.cursorOffset != null) {
            int diff = hint.text.length - completion.cursorOffset;
            doc.setCursor(pos.Position(
                editor.getCursor().line, editor.getCursor().ch - diff));
          }
          if (completion.type == 'type-quick_fix') {
            for (final edit in completion.quickFixes) {
              ed.document.applyEdit(edit);
            }
          }
        }, hintRenderer: (html.Element element, HintResult hint) {
          var escapeHtml = HtmlEscape().convert;
          if (completion.type != 'type-quick_fix') {
            element.innerHtml = escapeHtml(completion.displayString)
                .replaceFirst(escapeHtml(stringToReplace),
                    '<em>${escapeHtml(stringToReplace)}</em>');
          } else {
            element.innerHtml = escapeHtml(completion.displayString);
          }
        });
      }).toList();

      if (hints.isEmpty && ed._lookingForQuickFix) {
        hints = [
          HintResult(stringToReplace,
              displayText: 'No fixes available',
              className: 'type-no_suggestions')
        ];
      } else if (hints.isEmpty &&
          (ed.completionActive ||
              (!ed.completionActive && !ed.completionAutoInvoked))) {
        // Only show 'no suggestions' if the completion was explicitly invoked
        // or if the popup was already active.
        hints = [
          HintResult(stringToReplace,
              displayText: 'No suggestions', className: 'type-no_suggestions')
        ];
      }

      return HintResults.fromHints(hints, from, to);
    });
  }
}

class _CodeMirrorEditor extends Editor {
  // Map from JsObject codemirror instances to existing dartpad wrappers.
  static final Map _instances = <dynamic, _CodeMirrorEditor>{};

  final CodeMirror cm;

  _CodeMirrorDocument _document;

  bool _lookingForQuickFix;

  _CodeMirrorEditor._(CodeMirrorFactory factory, this.cm) : super(factory) {
    _document = _CodeMirrorDocument._(this, cm.getDoc());
    _instances[cm.jsProxy] = this;
  }

  factory _CodeMirrorEditor._fromExisting(
      CodeMirrorFactory factory, CodeMirror cm) {
    // TODO: We should ensure that the Dart `CodeMirror` wrapper returns the
    // same instances to us when possible (or, identity is based on the
    // underlying JS proxy).
    if (_instances.containsKey(cm.jsProxy)) {
      return _instances[cm.jsProxy];
    } else {
      return _CodeMirrorEditor._(factory, cm);
    }
  }

  @override
  Document get document => _document;

  @override
  Document createDocument({String content, String mode}) {
    if (mode == 'html') mode = 'text/html';
    content ??= '';

    // TODO: For `html`, enable and disable the 'autoCloseTags' option.
    return _CodeMirrorDocument._(this, Doc(content, mode));
  }

  @override
  void execCommand(String name) => cm.execCommand(name);

  @override
  void showCompletions({bool autoInvoked = false, bool onlyShowFixes = false}) {
    if (autoInvoked) {
      completionAutoInvoked = true;
    } else {
      completionAutoInvoked = false;
    }
    if (onlyShowFixes) {
      _lookingForQuickFix = true;
    } else {
      _lookingForQuickFix = false;
    }
    execCommand('autocomplete');
  }

  @override
  bool get completionActive {
    if (cm.jsProxy['state']['completionActive'] == null) {
      return false;
    } else {
      return cm.jsProxy['state']['completionActive']['widget'] != null;
    }
  }

  @override
  String get mode => cm.getMode();

  @override
  set mode(String str) => cm.setMode(str);

  @override
  String get theme => cm.getTheme();

  @override
  set theme(String str) => cm.setTheme(str);

  @override
  bool get hasFocus => cm.jsProxy['state']['focused'];

  @override
  Stream<html.MouseEvent> get onMouseDown => cm.onMouseDown;

  @override
  Point getCursorCoords({ed.Position position}) {
    JsObject js;
    if (position == null) {
      js = cm.call('cursorCoords');
    } else {
      js = cm.callArg('cursorCoords', _document._posToPos(position).toProxy());
    }
    return Point(js['left'], js['top']);
  }

  @override
  void focus() => cm.focus();

  @override
  void resize() => cm.refresh();

  @override
  bool get readOnly => cm.getReadOnly();

  @override
  set readOnly(bool ro) {
    cm.setReadOnly(ro);
  }

  @override
  void swapDocument(Document document) {
    _document = document;
    cm.swapDoc(_document.doc);
  }

  @override
  void dispose() {
    _instances.remove(cm.jsProxy);
  }
}

class _CodeMirrorDocument extends Document {
  final Doc doc;

  final List<LineWidget> widgets = [];
  final List<html.DivElement> nodes = [];

  /// We use `_lastSetValue` here to avoid a change notification when we
  /// programmatically change the `value` field.
  String _lastSetValue;

  _CodeMirrorDocument._(_CodeMirrorEditor editor, this.doc) : super(editor);

  _CodeMirrorEditor get parent => editor;

  @override
  String get value => doc.getValue();

  @override
  set value(String str) {
    _lastSetValue = str;
    doc.setValue(str);
    doc.markClean();
    doc.clearHistory();
  }

  @override
  void updateValue(String str) {
    doc.setValue(str);
  }

  @override
  ed.Position get cursor => _posFromPos(doc.getCursor());

  @override
  void select(ed.Position start, [ed.Position end]) {
    if (end != null) {
      doc.setSelection(_posToPos(start), head: _posToPos(end));
    } else {
      doc.setSelection(_posToPos(start));
    }
  }

  @override
  String get selection => doc.getSelection(value);

  @override
  String get mode => parent.mode;

  @override
  bool get isClean => doc.isClean();

  @override
  void markClean() => doc.markClean();

  @override
  void applyEdit(SourceEdit edit) {
    doc.replaceRange(edit.replacement, _posToPos(posFromIndex(edit.offset)),
        _posToPos(posFromIndex(edit.offset + edit.length)));
  }

  @override
  void setAnnotations(List<Annotation> annotations) {
    for (TextMarker marker in doc.getAllMarks()) {
      marker.clear();
    }

    for (LineWidget widget in widgets) {
      widget.clear();
    }
    widgets.clear();

    for (html.DivElement e in nodes) {
      e.parent.children.remove(e);
    }
    nodes.clear();

    // Sort annotations so that the errors are set first.
    annotations.sort();

    int lastLine = -1;

    for (Annotation an in annotations) {
      // Create in-line squiggles.
      doc.markText(_posToPos(an.start), _posToPos(an.end),
          className: 'squiggle-${an.type}', title: an.message);

      // Create markers in the margin.
      if (lastLine == an.line) continue;
      lastLine = an.line;
    }
  }

  @override
  int indexFromPos(ed.Position position) =>
      doc.indexFromPos(_posToPos(position));

  @override
  ed.Position posFromIndex(int index) => _posFromPos(doc.posFromIndex(index));

  pos.Position _posToPos(ed.Position position) =>
      pos.Position(position.line, position.char);

  ed.Position _posFromPos(pos.Position position) =>
      ed.Position(position.line, position.ch);

  @override
  Stream get onChange {
    return doc.onChange.where((_) {
      if (value != _lastSetValue) {
        _lastSetValue = null;
        return true;
      } else {
        //_lastSetValue = null;
        return false;
      }
    });
  }
}

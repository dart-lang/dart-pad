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

final CodeMirrorFactory codeMirrorFactory = new CodeMirrorFactory._();

class CodeMirrorFactory extends EditorFactory {
  //static final String cssRef = 'packages/dart_pad/editing/editor_codemirror.css';
  //static final String jsRef = 'packages/codemirror/codemirror.js';

  CodeMirrorFactory._();

  String get version => CodeMirror.version;

  List<String> get modes => CodeMirror.MODES;
  List<String> get themes => CodeMirror.THEMES;

  bool get inited {
    return true;
//    List scripts = html.querySelectorAll('head script');
//    return scripts.any((script) => script.src == jsRef);
  }

  Future init() {
    List<Future> futures = [];
    //html.Element head = html.querySelector('html head');

//    // <link href="packages/dart_pad/editing/editor_codemirror.css"
//    //   rel="stylesheet">
//    html.LinkElement link = new html.LinkElement();
//    link.rel = 'stylesheet';
//    link.href = cssRef;
//    futures.add(_appendNode(head, link));

//    // <script src="packages/codemirror/codemirror.js"></script>
//    html.ScriptElement script = new html.ScriptElement();
//    script.src = jsRef;
//    futures.add(_appendNode(head, script));

    return Future.wait(futures);
  }

  Editor createFromElement(html.Element element, {Map options}) {
    if (options == null) {
      options = {
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
    }

    CodeMirror editor = new CodeMirror.fromElement(element, options: options);
    CodeMirror.addCommand('goLineLeft', _handleGoLineLeft);
    return new _CodeMirrorEditor._(this, editor);
  }

  bool get supportsCompletionPositioning => true;

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
    _CodeMirrorEditor ed = new _CodeMirrorEditor._fromExisting(this, editor);

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
        return new HintResult(completion.value,
            displayText: completion.displayString,
            className: completion.type, hintApplier: (CodeMirror editor,
                HintResult hint, pos.Position from, pos.Position to) {
          doc.replaceRange(hint.text, from, to);
          if (completion.cursorOffset != null) {
            int diff = hint.text.length - completion.cursorOffset;
            doc.setCursor(new pos.Position(
                editor.getCursor().line, editor.getCursor().ch - diff));
          }
          if (completion.type == "type-quick_fix") {
            completion.quickFixes
                .forEach((SourceEdit edit) => ed.document.applyEdit(edit));
          }
        }, hintRenderer: (html.Element element, HintResult hint) {
          var escapeHtml = new HtmlEscape().convert;
          if (completion.type != "type-quick_fix") {
            element.innerHtml = escapeHtml(completion.displayString)
                .replaceFirst(escapeHtml(stringToReplace),
                    "<em>${escapeHtml(stringToReplace)}</em>");
          } else {
            element.innerHtml = escapeHtml(completion.displayString);
          }
        });
      }).toList();

      if (hints.isEmpty && ed._lookingForQuickFix) {
        hints = [
          new HintResult(stringToReplace,
              displayText: "No fixes available",
              className: "type-no_suggestions")
        ];
      } else if (hints.isEmpty &&
          (ed.completionActive ||
              (!ed.completionActive && !ed.completionAutoInvoked))) {
        // Only show 'no suggestions' if the completion was explicitly invoked
        // or if the popup was already active.
        hints = [
          new HintResult(stringToReplace,
              displayText: "No suggestions", className: "type-no_suggestions")
        ];
      }

      return new HintResults.fromHints(hints, from, to);
    });
  }
}

class _CodeMirrorEditor extends Editor {
  // Map from JsObject codemirror instances to existing dartpad wrappers.
  static Map<dynamic, _CodeMirrorEditor> _instances = {};

  final CodeMirror cm;

  _CodeMirrorDocument _document;

  bool _lookingForQuickFix;

  _CodeMirrorEditor._(CodeMirrorFactory factory, this.cm) : super(factory) {
    _document = new _CodeMirrorDocument._(this, cm.getDoc());
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
      return new _CodeMirrorEditor._(factory, cm);
    }
  }

  Document get document => _document;

  Document createDocument({String content, String mode}) {
    if (mode == 'html') mode = 'text/html';
    if (content == null) content = '';

    // TODO: For `html`, enable and disable the 'autoCloseTags' option.
    return new _CodeMirrorDocument._(this, new Doc(content, mode));
  }

  void execCommand(String name) => cm.execCommand(name);

  void showCompletions({bool autoInvoked: false, bool onlyShowFixes: false}) {
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
    execCommand("autocomplete");
  }

  bool get completionActive {
    if (cm.jsProxy['state']['completionActive'] == null) {
      return false;
    } else {
      return cm.jsProxy['state']['completionActive']['widget'] != null;
    }
  }

  String get mode => cm.getMode();
  set mode(String str) => cm.setMode(str);

  String get theme => cm.getTheme();
  set theme(String str) => cm.setTheme(str);

  bool get hasFocus => cm.jsProxy['state']['focused'];

  Stream<html.MouseEvent> get onMouseDown => cm.onMouseDown;

  Point getCursorCoords({ed.Position position}) {
    JsObject js;
    if (position == null) {
      js = cm.call("cursorCoords");
    } else {
      js = cm.callArg("cursorCoords", _document._posToPos(position).toProxy());
    }
    return new Point(js["left"], js["top"]);
  }

  void focus() => cm.focus();
  void resize() => cm.refresh();

  void swapDocument(Document document) {
    _document = document;
    cm.swapDoc(_document.doc);
  }

  void dispose() {
    _instances.remove(cm.jsProxy);
  }
}

class _CodeMirrorDocument extends Document {
  final Doc doc;

  final List<LineWidget> widgets = [];
  final List<html.DivElement> nodes = [];

  /**
   * We use `_lastSetValue` here to avoid a change notification when we
   * programatically change the `value` field.
   */
  String _lastSetValue;

  _CodeMirrorDocument._(_CodeMirrorEditor editor, this.doc) : super(editor);

  _CodeMirrorEditor get parent => editor;

  String get value => doc.getValue();

  set value(String str) {
    _lastSetValue = str;
    doc.setValue(str);
    doc.markClean();
    // TODO: Switch over to non-JS interop when this method is exposed.
    doc.jsProxy.callMethod('clearHistory');
  }

  void updateValue(String str) {
    doc.setValue(str);
  }

  ed.Position get cursor => _posFromPos(doc.getCursor());

  void select(ed.Position start, [ed.Position end]) {
    if (end != null) {
      doc.setSelection(_posToPos(start), head: _posToPos(end));
    } else {
      doc.setSelection(_posToPos(start));
    }
  }

  String get selection => doc.getSelection(value);

  String get mode => parent.mode;

  bool get isClean => doc.isClean();

  void markClean() => doc.markClean();

  void applyEdit(SourceEdit edit) {
    doc.replaceRange(edit.replacement, _posToPos(posFromIndex(edit.offset)),
        _posToPos(posFromIndex(edit.offset + edit.length)));
  }

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

//      html.DivElement node = new html.DivElement();
//      //node.style.position = 'absolute';
//      node.text = an.message;
//      node.style.backgroundColor = '#444';
//      //node.style.height = '40px';
//      //nodes.add(node);
//      //(editor as _CodeMirrorEditor).cm.addWidget(_posToPos(an.start), node);
//      widgets.add(
//          (editor as _CodeMirrorEditor).cm.addLineWidget(an.line - 1, node));
//
////      cm.setGutterMarker(an.line - 1, _gutterId,
////          _makeMarker(an.type, an.message, an.start, an.end));
    }
  }

  int indexFromPos(ed.Position position) =>
      doc.indexFromPos(_posToPos(position));

  ed.Position posFromIndex(int index) => _posFromPos(doc.posFromIndex(index));

  pos.Position _posToPos(ed.Position position) =>
      new pos.Position(position.line, position.char);

  ed.Position _posFromPos(pos.Position position) =>
      new ed.Position(position.line, position.ch);

//  html.Element _makeMarker(String severity, String tooltip, ed.Position start,
//      ed.Position end) {
//    html.Element marker = new html.DivElement();
//    marker.className = "CodeMirror-lint-marker-" + severity;
//    if (tooltip != null) marker.title = tooltip;
//    marker.onClick.listen((_) {
//      doc.setSelection(new pos.Position(start.line, start.char),
//          head: new pos.Position(end.line, end.char));
//    });
//    return marker;
//  }

  Stream get onChange => doc.onChange.where((_) {
        if (value != _lastSetValue) {
          _lastSetValue = null;
          return true;
        } else {
          //_lastSetValue = null;
          return false;
        }
      });
}

//Future _appendNode(html.Element parent, html.Element child) {
//  Completer completer = new Completer();
//  child.onLoad.listen((e) {
//    completer.complete();
//  });
//  parent.nodes.add(child);
//  return completer.future;
//}

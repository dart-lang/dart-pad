// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library editor.codemirror;

import 'dart:async';
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

final _gutterId = 'CodeMirror-lint-markers';

class CodeMirrorFactory extends EditorFactory {
  //static final String cssRef = 'packages/dart_pad/editing/editor_codemirror.css';
  static final String jsRef = 'packages/codemirror/codemirror.js';

  CodeMirrorFactory._();

  List<String> get modes => CodeMirror.MODES;
  List<String> get themes => CodeMirror.THEMES;

  bool get inited {
    List scripts = html.querySelectorAll('head script');
    return scripts.any((script) => script.src == jsRef);
  }

  Future init() {
    List futures = [];
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
        'autofocus': true,
        // Removing this - with this enabled you can't type a forward slash.
        //'autoCloseTags': true,
        'autoCloseBrackets': true,
        'matchBrackets': true,
        'tabSize': 2,
        'lineWrapping': true,
        'indentUnit': 2,
        'cursorHeight': 0.85,
        //'gutters': [_gutterId],
        'extraKeys': {
          'Cmd-/': 'toggleComment',
          'Ctrl-/': 'toggleComment'
        },
        'hintOptions': {
          'completeSingle': false
        },
        //'lint': true,
        'theme': 'zenburn' // ambiance, vibrant-ink, monokai, zenburn
      };
    }

    return new _CodeMirrorEditor._(this,
        new CodeMirror.fromElement(element, options: options));
  }

  bool get supportsCompletionPositioning => true;

  void registerCompleter(String mode, CodeCompleter completer) {
    Hints.registerHintsHelperAsync(mode, (CodeMirror editor, [HintsOptions options]) {
      return _completionHelper(editor, completer, options);
    });
  }

  Future<HintResults> _completionHelper(CodeMirror editor,
      CodeCompleter completer, HintsOptions options) {
    _CodeMirrorEditor ed = new _CodeMirrorEditor._(this, editor);

    return completer.complete(ed, onlyShowFixes: ed._lookingForQuickFix).then((CompletionResult result) {
      Doc doc = editor.getDoc();
      pos.Position from =  doc.posFromIndex(result.replaceOffset);
      pos.Position to = doc.posFromIndex(
          result.replaceOffset + result.replaceLength);
      String stringToReplace = doc.getValue().substring(
          result.replaceOffset, result.replaceOffset + result.replaceLength);

      List<HintResult> hints = result.completions.map((Completion completion) {
        return new HintResult(
            completion.value,
            displayText: completion.displayString,
            className: completion.type,
            hintApplier: (CodeMirror editor, HintResult hint, pos.Position from,
                pos.Position to) {
              doc.replaceRange(hint.text, from, to);
              if (completion.cursorOffset != null) {
                int diff = hint.text.length - completion.cursorOffset;
                doc.setCursor(new pos.Position(
                    editor.getCursor().line, editor.getCursor().ch - diff));
              }
              if (completion.type == "type-quick_fix") {
                completion.quickFixes.forEach(
                        (SourceEdit edit) => ed.document.applyEdit(edit));
              }
            },
            hintRenderer: (html.Element element, HintResult hint) {
              if (completion.type != "type-quick_fix") {
                element.innerHtml = completion.displayString.replaceFirst(
                    stringToReplace, "<em>${stringToReplace}</em>"
                );
              } else {
                element.innerHtml = completion.displayString;
              }

            }
        );
      }).toList();

      if (hints.isEmpty && ed._lookingForQuickFix) {
        hints = [
          new HintResult(stringToReplace,
          displayText: "No fixes available", className: "type-no_suggestions")
        ];
      }
      // Only show 'no suggestions' if the completion was explicitly invoked
      // or if the popup was already active.
      else if (hints.isEmpty
            && (ed.completionActive
                  || (!ed.completionActive && !ed.completionAutoInvoked))) {
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
  final CodeMirror cm;

  _CodeMirrorDocument _document;

  _CodeMirrorEditor._(CodeMirrorFactory factory, this.cm) : super(factory) {
    _document = new _CodeMirrorDocument._(this, cm.getDoc());
  }

  Document get document => _document;

  Document createDocument({String content, String mode}) {
    if (mode == 'html') mode = 'text/html';
    if (content == null) content = '';

    // TODO: For `html`, enable and disable the 'autoCloseTags' option.
    return new _CodeMirrorDocument._(this, new Doc(content, mode));
  }

  void execCommand(String name) {
    cm.execCommand(name);
  }

  void showCompletions({bool autoInvoked: false, bool onlyShowFixes: false}) {
    if (autoInvoked) {
      completionAutoInvoked = true;
    } else {
      completionAutoInvoked = false;
    }
    if (onlyShowFixes) {
      _lookingForQuickFix = true;
      // Codemirror autocompletion only works if there is no selected text.
      cm.getDoc().setCursor(_document._posToPos(_document.selectionStart));
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

  bool get completionAutoInvoked
      => cm.jsProxy['state']['completionAutoInvoked'];
  set completionAutoInvoked(bool value)
      => cm.jsProxy['state']['completionAutoInvoked'] = value;

  bool get _lookingForQuickFix
      => cm.jsProxy['state']['lookingForQuickFix'];
  set _lookingForQuickFix(bool value)
      => cm.jsProxy['state']['lookingForQuickFix'] = value;

  String get mode => cm.getMode();
  set mode(String str) => cm.setMode(str);

  String get theme => cm.getTheme();
  set theme(String str) => cm.setTheme(str);

  bool get hasFocus => cm.jsProxy['state']['focused'];

  Stream get onMouseDown {
    return cm.onMouseDown;
  }

  Point get cursorCoords {
    JsObject js = cm.call("cursorCoords");
    return new Point(js["left"], js["top"]);
  }

  void focus() => cm.focus();
  void resize() => cm.refresh();

  void swapDocument(Document document) {
    _document = document;
    cm.swapDoc(_document.doc);
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
    doc.replaceRange(
        edit.replacement,
        _posToPos(posFromIndex(edit.offset)),
        _posToPos(posFromIndex(edit.offset + edit.length))
    );
  }

  bool get hasIssueAtOffset {
    List<TextMarker> marks = doc.findMarksAt(_posToPos(cursor));
    for (TextMarker mark in marks) {
      String className = (mark.jsProxy["className"] as String);
      if (className.contains("squiggle")) {
        return true;
      }
    }
    return false;
  }

  ed.Position get selectionStart {
    int offset = indexFromPos(cursor) - doc.getSelection().length;
    return posFromIndex(offset);
  }

  ed.Position get selectionEnd => cursor;


  void setAnnotations(List<Annotation> annotations) {
    // TODO: Codemirror lint has no support for info markers - contribute some?
//    CodeMirror cm = parent.cm;
//    cm.clearGutter(_gutterId);

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

  List<TextMarker> findMarksAt(ed.Position pos) {
    return doc.findMarksAt(_posToPos(pos));
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

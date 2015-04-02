// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library editor.comid;

import 'dart:async';
import 'dart:html' as html;
import 'dart:math';

import 'package:comid/addon/comment/comment.dart' as comments;
import 'package:comid/addon/edit/closebrackets.dart';
import 'package:comid/addon/edit/matchbrackets.dart';
import 'package:comid/addon/edit/show-hint.dart' as hints;
import 'package:comid/addon/mode/css.dart';
import 'package:comid/addon/mode/dart.dart';
import 'package:comid/addon/mode/htmlmixed.dart';
import 'package:comid/codemirror.dart' hide Document;

import 'editor.dart' hide Position;
import 'editor.dart' as ed show Position;

export 'editor.dart';

final ComidFactory comidFactory = new ComidFactory._();

final _gutterId = 'CodeMirror-lint-markers';

class ComidFactory extends EditorFactory {
  ComidFactory._();

  List<String> get modes => ['dart', 'html', 'css'];
  List<String> get themes => ['zenburn'];

  bool get inited {
    // TODO: Comparing to `'null'` can't be right.
    return CodeMirror.getMode({}, 'dart').name != 'null';
  }

  Future init() {
    DartMode.initialize();
    HtmlMode.initialize();
    CssMode.initialize();
    hints.initialize();
    comments.initialize();
    initializeBracketMatching();
    initializeBracketClosing();

    List futures = [];
//    html.Element head = html.querySelector('html head');

//    // <link href="packages/dart_pad/editing/editor_codemirror.css"
//    //   rel="stylesheet">
//    html.LinkElement link = new html.LinkElement();
//    link.rel = 'stylesheet';
//    link.href = cssRef;
//    futures.add(_appendNode(head, link));

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
        'lineWrapping': false,
        'indentUnit': 2,
        'cursorHeight': 0.85,
        //'gutters': [_gutterId],
        'extraKeys': {
          'Ctrl-Space': 'autocomplete',
          (mac ? "Cmd-/" : "Ctrl-/"): "toggleComment"
        },
        //'lint': true,
        'theme': 'zenburn'
      };
    }

    CodeMirror.defaultCommands['autocomplete'] = showDartCompletions;
    return new _CodeMirrorEditor._(this,
        new CodeMirror(element, options));
  }

  hints.CompletionOptions options;
  CodeCompleter completer;
  String completoinMode;

  bool get supportsCompletionPositioning => false;

  void registerCompleter(String mode, CodeCompleter codeCompleter) {
    options = new hints.CompletionOptions(
        hint: computeProposals,
        completeOnSingleClick: true,
        async: true);
    completer = codeCompleter;
    completoinMode = mode;
  }

  showDartCompletions([CodeMirror cm, var _]) {
    if (cm.doc.mode.name == completoinMode) {
      hints.showHint(cm, options);
    } else {
      hints.showHint(cm, new hints.CompletionOptions(
          hint: CodeMirror.getNamedHelper('hint', 'auto'),
          completeOnSingleClick: true));
    }
  }

  hints.ProposalList computeProposals( // rtn val only used in sync mode
      CodeMirror cm,
      hints.CompletionOptions options,
      [hints.ShowProposals displayProposals]) {
    assert(displayProposals != null); // ensure async
    _CodeMirrorEditor ed = new _CodeMirrorEditor._(this, cm); // new instance!?
    Future<CompletionResult> props = completer.complete(ed);
    Pos pos = cm.getCursor();
    props.then((CompletionResult completions) {
      List<Completion> completionList = completions.completions;
      hints.ProposalList proposals;
      List<hints.Proposal> list = completionList.map((Completion completion) =>
          // this map is broken -- should use custom display ala Dart Editor
          new hints.Proposal(completion.value)).toList();
      proposals = new hints.ProposalList(list: list, from: pos, to: pos);
      displayProposals(proposals);
    });
    return null;
  }
}

class _CodeMirrorEditor extends Editor {
  final CodeMirror cm;

  _CodeMirrorDocument _document;

  _CodeMirrorEditor._(ComidFactory factory, this.cm) : super(factory) {
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

  // TODO: Implement completionActive for comid.
  bool get completionActive => false;

  // TODO: Implement completionActivelyInvoked for comid.
  bool get completionAutoInvoked => false;
  set completionAutoInvoked(bool value) { }

  String get mode => cm.doc.getMode().name;
  set mode(String str) => cm.setOption('mode', str);

  String get theme => cm.getOption('theme');
  set theme(String str) => cm.setOption('theme', str);

  // TODO: Add a cursorCoords getter for comid
  Point get cursorCoords => null;

  bool get hasFocus => cm.state.focused;

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

  String _lastSetValue;

  _CodeMirrorDocument._(_CodeMirrorEditor editor, this.doc) : super(editor);

  _CodeMirrorEditor get parent => editor;

  String get value => doc.getValue();

  set value(String str) {
    _lastSetValue = str;
    doc.setValue(str);
    doc.markClean();
    doc.clearHistory();
  }

  ed.Position get cursor => _posFromPos(doc.getCursor());

  void select(ed.Position start, [ed.Position end]) {
    if (end != null) {
      doc.setSelection(_posToPos(start), _posToPos(end));
    } else {
      doc.setSelection(_posToPos(start));
    }
  }

  String get selection => doc.getSelection(value);

  String get mode => parent.mode;

  bool get isClean => doc.isClean();

  void markClean() => doc.markClean();

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
      doc.cm.markText(_posToPos(an.start), _posToPos(an.end),
          className: 'squiggle-${an.type}', title: an.message);

      // Create markers in the margin.
      if (lastLine == an.line) continue;
      lastLine = an.line;
    }
  }

  int indexFromPos(ed.Position position) =>
      doc.indexFromPos(_posToPos(position));

  ed.Position posFromIndex(int index) => _posFromPos(doc.posFromIndex(index));

  Pos _posToPos(ed.Position position) =>
      new Pos(position.line, position.char);

  ed.Position _posFromPos(Pos position) =>
      new ed.Position(position.line, position.char);

  Stream get onChange => doc.onEvent('change', 2).where((_) {
      if (value != _lastSetValue) return true;
      _lastSetValue = null;
      return false;
    });

  /**
   * This method should be called if any events listeners were added to the
   * object.
   */
  void dispose() {
    doc.dispose();
  }
}

// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library editor.ace;

import 'dart:async';
import 'dart:html' as html;
import 'dart:math';

import 'package:ace/ace.dart' as ace;
import 'package:ace/proxy.dart';

import 'editor.dart';

export 'editor.dart';

final AceFactory aceFactory = new AceFactory._();

// TODO: underline errors and warnings

// TODO: improve the styling for error and warning icons

class AceFactory extends EditorFactory {
  static final String cssRef = 'packages/dart_pad/editing/editor_ace.css';
  static final String jsRef = 'packages/ace/src/js/ace.js';

  AceFactory._();

  List<String> get modes => ace.Mode.MODES;
  List<String> get themes => ace.Theme.THEMES;

  bool get inited => ace.implementation != null;

  Future init() {
    // TODO: This injection is slower then hardcoding in the html file.
    html.Element head = html.querySelector('html head');

    // <link href="packages/dart_pad/editing/editor_codemirror.css" rel="stylesheet">
    html.LinkElement link = new html.LinkElement();
    link.rel = 'stylesheet';
    link.href = cssRef;
    Future cssFuture = _appendNode(head, link);

    // <script src="packages/ace/src/js/ace.js"></script>
    html.ScriptElement script = new html.ScriptElement();
    script.src = jsRef;
    Future jsFuture = _appendNode(head, script);

    // <script src="packages/ace/src/js/ext-language_tools.js"></script>
    script = new html.ScriptElement();
    script.src = 'packages/ace/src/js/ext-language_tools.js';
    jsFuture = jsFuture.then((_) {
      return _appendNode(head, script);
    });

    return Future.wait([cssFuture, jsFuture]).then((_) {
      ace.implementation = ACE_PROXY_IMPLEMENTATION;
      ace.require('ace/ext/language_tools');
    });
  }

  Editor createFromElement(html.Element element, {Map options}) {
    ace.Editor editor = ace.edit(element);

    //editor.renderer.showGutter = false;
    editor.renderer.fixedWidthGutter = true;
    editor.theme = new ace.Theme.named('monokai');
    editor.highlightActiveLine = false;
    editor.highlightGutterLine = false;
    editor.showPrintMargin = false;
    editor.showFoldWidgets = false;

    if (options == null) {
      options = {'enableBasicAutocompletion': false, 'showLineNumbers': false};
    }

    editor.setOptions(options);
    // Remove the `ctrl-,` binding.
    editor.commands.removeCommand('showSettingsMenu');
    // Remove the default find and goto line dialogs - they're UI is awful.
    editor.commands.removeCommand('gotoline');
    editor.commands.removeCommand('find');

    return new _AceEditor._(this, editor);
  }

  bool get supportsCompletionPositioning => false;

  void registerCompleter(String mode, CodeCompleter completer) {
    // TODO:
//    ace.LanguageTools langTools = ace.require('ace/ext/language_tools');
//    langTools.addCompleter(new ace.AutoCompleter(_aceCompleter));
  }
}

class _AceEditor extends Editor {
  final ace.Editor editor;

  bool completionAutoInvoked = false;

  _AceDocument _document;

  _AceEditor._(AceFactory factory, this.editor) : super(factory) {
    _document = new _AceDocument._(this, editor.session);
  }

  Document get document => _document;

  Document createDocument({String content, String mode}) {
    if (content == null) content = '';
    ace.EditSession session = ace.createEditSession(
        content, new ace.Mode.named(mode));
    session.tabSize = 2;
    session.useSoftTabs = true;
    session.useWorker = false;

    return new _AceDocument._(this, session);
  }

  // TODO: Implement execCommand for ace.
  void execCommand(String name) { }

  // TODO: Implement completionActive for ace.
  bool get completionActive => false;

  String get mode => _document.session.mode.name;
  set mode(String str) => _document.session.mode = new ace.Mode.named(str);

  String get theme => editor.theme.name;
  set theme(String str) {
    editor.theme = new ace.Theme.named(str);
  }

  bool get hasFocus => editor.isFocused;

  // TODO: Add a cursorCoords getter for ace.
  Point get cursorCoords => null;

  // TODO: Add a onMouseDown getter for ace.
  Stream get onMouseDown => null;

  void focus() => editor.focus();
  void resize() => editor.resize(true);

  void swapDocument(Document document) {
    _document = document;
    editor.session = _document.session;
  }
}

class _AceDocument extends Document {
  final ace.EditSession session;

  //List<int> markers = [];

  _AceDocument._(_AceEditor editor, this.session) : super(editor);

  _AceEditor get _aceEditor => editor;

  String get value => session.value;
  set value(String str) {
    session.value = str;
  }

  Position get cursor => _ptToPosition(_aceEditor.editor.selection.cursor);

  void select(Position start, [Position end]) {
    // TODO: Implement.

  }

  String get selection => _aceEditor.editor.copyText;

  String get mode => session.mode.name;

  bool get isClean => session.undoManager.isClean;

  void markClean() => session.undoManager.markClean();

  void setAnnotations(List<Annotation> annotations) {
//    if (markers.isNotEmpty) {
//      for (int markerId in markers) {
//        session.removeMarker(markerId);
//      }
//      markers.clear();
//    }

    // Sort annotations so that the errors are set first.
    annotations.sort();

    session.setAnnotations(annotations.map((Annotation annotation) {
      return new ace.Annotation(text: annotation.message,
          type: annotation.type, row: annotation.line - 1);
    }).toList());

//    for (Annotation annotation in annotations) {
//      // TODO: use the positions from the source we analyzed, not the current source
//      // TODO: we need tooltips too
//      ace.Point start = new ace.Point(annotation.start.line, annotation.start.char);
//      ace.Point end = new ace.Point(annotation.end.line, annotation.end.char);
//
//      int markerId = session.addMarker(new ace.Range.fromPoints(start, end),
//          '${annotation.type}marker');
//      markers.add(markerId);
//    }
  }

  void clearAnnotations() => session.clearAnnotations();

  int indexFromPos(Position position) {
    return session.document.positionToIndex(_positionToPoint(position));
  }

  Position posFromIndex(int index) {
    return _ptToPosition(session.document.indexToPosition(index));
  }

  Stream get onChange => session.onChange;
}

Future _appendNode(html.Element parent, html.Element child) {
  Completer completer = new Completer();
  child.onLoad.listen((e) {
    completer.complete();
  });
  parent.nodes.add(child);
  return completer.future;
}

Position _ptToPosition(ace.Point point) =>
    new Position(point.row, point.column);

ace.Point _positionToPoint(Position position) =>
    new ace.Point(position.line, position.char);

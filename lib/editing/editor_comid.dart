// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library editor.comid;

import 'dart:async';
import 'dart:html' as html;
import 'dart:math';
import 'dart:convert';

import 'package:comid/addon/comment/comment.dart' as comments;
import 'package:comid/addon/edit/closebrackets.dart';
import 'package:comid/addon/edit/matchbrackets.dart';
import 'package:comid/addon/edit/show_hint.dart' as hints;
import 'package:comid/addon/edit/html_hint.dart' as html_hints;
import 'package:comid/addon/mode/css.dart';
import 'package:comid/addon/mode/dart.dart';
import 'package:comid/addon/mode/htmlmixed.dart';
import 'package:comid/codemirror.dart' hide Document;
import "package:comid/addon/search/search.dart";

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
    return CodeMirror.getMode({}, 'dart').name != 'null';
  }

  Future init() {
    DartMode.initialize();
    HtmlMode.initialize();
    CssMode.initialize();
    hints.initialize();
    html_hints.initialize();
    comments.initialize();
    initializeBracketMatching();
    initializeBracketClosing();
    initializeSearch();

    List futures = [];

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
        'extraKeys': {(mac ? "Cmd-/" : "Ctrl-/"): "toggleComment"},
        //'lint': true,
        'theme': 'zenburn'
      };
    }

    CodeMirror.defaultCommands['autocomplete'] = showDartCompletions;
    return new _CodeMirrorEditor._(this, new CodeMirror(element, options));
  }

  hints.CompletionOptions options;
  CodeCompleter completer;
  String completionMode;

  bool get supportsCompletionPositioning => true;

  void registerCompleter(String mode, CodeCompleter codeCompleter) {
    options = new hints.CompletionOptions(
        hint: computeProposals, completeOnSingleClick: true, async: true);
    completer = codeCompleter;
    completionMode = mode;
  }

  showDartCompletions([CodeMirror cm, var _]) {
    if (cm.doc.mode.name == completionMode) {
      hints.showHint(cm, options);
    } else {
      hints.showHint(
          cm,
          new hints.CompletionOptions(
              hint: CodeMirror.getNamedHelper('hint', 'auto'),
              completeOnSingleClick: true));
    }
  }

  hints.ProposalList computeProposals(
      // rtn val only used in sync mode
      CodeMirror cm,
      hints.CompletionOptions options,
      [hints.ShowProposals displayProposals]) {
    assert(displayProposals != null); // ensure async
    _CodeMirrorEditor ed = new _CodeMirrorEditor._fromExisting(this, cm);
    Future<CompletionResult> props =
        completer.complete(ed, onlyShowFixes: ed._lookingForQuickFix);
    Future futureProposals = props.then((CompletionResult result) {
      Doc doc = cm.getDoc();
      var from = doc.posFromIndex(result.replaceOffset);
      var to = doc.posFromIndex(result.replaceOffset + result.replaceLength);
      String stringToReplace = doc.getValue().substring(
          result.replaceOffset, result.replaceOffset + result.replaceLength);

      List<Completion> completionList = result.completions;
      List<Proposal> list = completionList.map((Completion completion) {
        return new Proposal(completion.value,
            displayText: completion.displayString,
            className: completion.type, hintApplier:
                (CodeMirror editor, hints.ProposalList list, Proposal hint) {
          doc.replaceRange(hint.text, list.from, list.to);
          if (completion.cursorOffset != null) {
            int diff = hint.text.length - completion.cursorOffset;
            doc.setCursor(new Pos(
                editor.getCursor().line, editor.getCursor().char - diff));
          }
          if (completion.type == "type-quick_fix") {
            completion.quickFixes
                .forEach((SourceEdit edit) => ed.document.applyEdit(edit));
          }
        }, hintRenderer: (html.Element element, list, hints.Proposal hint) {
          var escapeHtml = new HtmlEscape().convert;
          if (completion.type != "type-quick_fix") {
            var escDispl = escapeHtml(completion.displayString);
            var escRepl = escapeHtml(stringToReplace);
            element.innerHtml =
                escDispl.replaceFirst(escRepl, "<em>${escRepl}</em>");
          } else {
            element.innerHtml = escapeHtml(completion.displayString);
          }
        });
      }).toList();

      if (list.isEmpty && ed._lookingForQuickFix) {
        list.add(new Proposal(stringToReplace,
            displayText: "No fixes available",
            className: "type-no_suggestions"));
      } else if (list.isEmpty &&
          (ed.completionActive ||
              (!ed.completionActive && !ed.completionAutoInvoked))) {
        // Only show 'no suggestions' if the completion was explicitly invoked
        // or if the popup was already active.
        list.add(new Proposal(stringToReplace,
            displayText: "No suggestions", className: "type-no_suggestions"));
      }

      hints.ProposalList proposals;
      proposals = new hints.ProposalList(list: list, from: from, to: to);
      return proposals;
    });
    futureProposals.then((proposals) {
      displayProposals(proposals);
    });
    return null;
  }
}

class _CodeMirrorEditor extends Editor {
  static List<_CodeMirrorEditor> _instances = [];

  final CodeMirror cm;

  _CodeMirrorDocument _document;
  bool _lookingForQuickFix = false;

  _CodeMirrorEditor._(ComidFactory factory, this.cm) : super(factory) {
    _document = new _CodeMirrorDocument._(this, cm.getDoc());
    _instances.add(this);
  }

  factory _CodeMirrorEditor._fromExisting(ComidFactory fac, CodeMirror cm) {
    var existing = _instances.firstWhere((ed) => ed.cm == cm);
    if (existing != null) {
      return existing;
    } else {
      return new _CodeMirrorEditor._(fac, cm);
    }
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

  bool get completionActive {
    hints.Completion completion = cm.state.completionActive;
    if (completion == null) return false;
    return completion.widget != null;
  }

  void showCompletions({bool autoInvoked: false, bool onlyShowFixes: false}) {
    completionAutoInvoked = autoInvoked;
    _lookingForQuickFix = onlyShowFixes;
    execCommand("autocomplete");
  }

  String get mode => cm.doc.getMode().name;
  set mode(String str) => cm.setOption('mode', str);

  String get theme => cm.getOption('theme');
  set theme(String str) => cm.setOption('theme', str);

  Point getCursorCoords({ed.Position position}) {
    Rect loc;
    if (position == null) {
      loc = cm.cursorCoords(position);
    } else {
      loc = cm.cursorCoords(_document._posToPos(position));
    }
    return new Point(loc.left, loc.top);
  }

  Stream<html.MouseEvent> get onMouseDown => cm.onMousedown;

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

  void applyEdit(SourceEdit edit) {
    doc.replaceRange(edit.replacement, _posToPos(posFromIndex(edit.offset)),
        _posToPos(posFromIndex(edit.offset + edit.length)));
  }

  void setAnnotations(List<Annotation> annotations) {
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

  Pos _posToPos(ed.Position position) => new Pos(position.line, position.char);

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

class Proposal extends hints.Proposal {
  Function hintApplier;
  String displayText;

  Proposal(text, {className, this.displayText, this.hintApplier, hintRenderer})
      : super(text, className: className, render: hintRenderer);

  /// Function f(CodeMirror, ProposalList, Proposal) called to do custom
  /// editing. It should replace the editor's selection with the proposal text.
  Function get hint => hintApplier;
}

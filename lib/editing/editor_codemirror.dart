// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library editor.codemirror;

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

  SearchUpdateCallback? _searchUpdateCallback;

  String? get version => CodeMirror.version;

  @override
  List<String> get modes => CodeMirror.modes;

  @override
  List<String> get themes => CodeMirror.themes;

  @override
  Editor createFromElement(html.Element element, {Map? options}) {
    options ??= {
      'continueComments': {'continueLineComment': false},
      'autofocus': false,
      'autoCloseTags': {
        'whenOpening': true,
        'whenClosing': true,
        'indentTags':
            [] // Android Studio/VSCode do not auto indent/add newlines for any completed tags
        //  The default (below) would be the following tags cause indenting and blank line inserted
        // ['applet', 'blockquote', 'body', 'button', 'div', 'dl', 'fieldset',
        //    'form', 'frameset', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'head',
        //    'html', 'iframe', 'layer', 'legend', 'object', 'ol', 'p', 'select', \
        //    'table', 'ul']
      },
      'autoCloseBrackets': true,
      'matchBrackets': true,
      'tabSize': 2,
      'lineWrapping': true,
      'indentUnit': 2,
      'cursorHeight': 0.85,
      // Increase the number of lines that are rendered above and before what's
      // visible.
      'viewportMargin': 100,
      //'gutters': [_gutterId],
      'extraKeys': {
        'Cmd-/': 'toggleComment',
        'Ctrl-/': 'toggleComment',
        'Shift-Tab': 'indentLess',
        'Tab': 'indentIfMultiLineSelectionElseInsertSoftTab',
        'Ctrl-F': 'weHandleElsewhere',
        'Ctrl-H': 'weHandleElsewhere',
        'Cmd-F': 'weHandleElsewhere',
        'Cmd-H': 'weHandleElsewhere',        
        'F4': 'weHandleElsewhere',
        'Shift-F4': 'weHandleElsewhere',
      },
      'hintOptions': {'completeSingle': false},
      'highlightSelectionMatches': {
        'style': 'highlight-selection-matches',
        'showToken': false,
        'annotateScrollbar': true,
      },
      //'lint': true,
      'theme': 'zenburn' // ambiance, vibrant-ink, monokai, zenburn
    };

    final editor = CodeMirror.fromElement(element, options: options);
    CodeMirror.addCommand('goLineLeft', _handleGoLineLeft);
    CodeMirror.addCommand('indentIfMultiLineSelectionElseInsertSoftTab',
        _indentIfMultiLineSelectionElseInsertSoftTab);
    CodeMirror.addCommand('weHandleElsewhere', _weHandleElsewhere);
    CodeMirror.addCommand(
        'ourSearchQueryUpdatedCallback', _ourSearchQueryUpdatedCallback);
    return _CodeMirrorEditor._(this, editor);
  }

  @override
  void registerCompleter(String mode, CodeCompleter completer) {
    Hints.registerHintsHelperAsync(mode, (CodeMirror editor,
        [HintsOptions? options]) {
      return _completionHelper(editor, completer, options);
    });
  }

  /// used to set the search update callback that will be called when
  /// the editors update their search annonations
  @override
  void registerSearchUpdateCallback(SearchUpdateCallback sac) {
    _searchUpdateCallback = sac;
  }

  // Change the cmd-left behavior to move the cursor to the leftmost non-ws char.
  void _handleGoLineLeft(CodeMirror editor) {
    editor.execCommand('goLineLeftSmart');
  }

  // make it so that we can insertSoftTab when no selection or selection on 1 line
  // but if there is multiline selection we indentMore
  // (this gives us a more typical coding editor behavior)
  void _indentIfMultiLineSelectionElseInsertSoftTab(CodeMirror editor) {
    if (editor.doc.somethingSelected()) {
      final String? selection = editor.doc.getSelection('\n');
      if (selection != null && selection.contains('\n')) {
        // Multi-line selection
        editor.execCommand('indentMore');
      } else {
        editor.execCommand('insertSoftTab');
      }
    } else {
      editor.execCommand('insertSoftTab');
    }
  }

  void _weHandleElsewhere(CodeMirror editor) {
    // DO NOTHING HERE - we bind/handle this at the top level html page, not
    //    within codemorror
  }

  void _ourSearchQueryUpdatedCallback(CodeMirror editor) {
    // This is called by our codemirror extension when the search query
    // results and annotation
    if (_searchUpdateCallback != null) {
      // they have a callback set, so get the info
      _searchUpdateCallback!();
    }
  }

  Future<HintResults> _completionHelper(
      CodeMirror editor, CodeCompleter completer, HintsOptions? options) {
    final ed = _CodeMirrorEditor._fromExisting(this, editor);

    return completer
        .complete(ed, onlyShowFixes: ed._lookingForQuickFix)
        .then((CompletionResult result) {
      final doc = editor.doc;
      final from = doc.posFromIndex(result.replaceOffset);
      final to = doc.posFromIndex(result.replaceOffset + result.replaceLength);
      final stringToReplace = doc.getValue()!.substring(
          result.replaceOffset, result.replaceOffset + result.replaceLength);

      var hints = result.completions.map((completion) {
        return HintResult(
          completion.value,
          displayText: completion.displayString,
          className: completion.type,
          hintApplier: (CodeMirror editor, HintResult hint, pos.Position? from,
              pos.Position? to) {
            doc.replaceRange(hint.text!, from!, to);

            if (completion.type == 'type-quick_fix') {
              for (final edit in completion.quickFixes) {
                ed.document.applyEdit(edit);
              }
            }

            if (completion.absoluteCursorPosition != null) {
              doc.setCursor(
                  doc.posFromIndex(completion.absoluteCursorPosition!));
            } else if (completion.cursorOffset != null) {
              final diff = hint.text!.length - completion.cursorOffset!;
              doc.setCursor(pos.Position(
                  editor.getCursor().line, editor.getCursor().ch! - diff));
            }
          },
          hintRenderer: (html.Element element, HintResult hint) {
            final escapeHtml = HtmlEscape().convert as String Function(String?);
            if (completion.type != 'type-quick_fix') {
              element.innerHtml = escapeHtml(completion.displayString)
                  .replaceFirst(escapeHtml(stringToReplace),
                      '<em>${escapeHtml(stringToReplace)}</em>');
            } else {
              element.innerHtml = escapeHtml(completion.displayString);
            }
          },
        );
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
  static final Map<dynamic, _CodeMirrorEditor> _instances = {};

  final CodeMirror cm;

  late _CodeMirrorDocument _document;

  late bool _lookingForQuickFix;

  _CodeMirrorEditor._(CodeMirrorFactory factory, this.cm) : super(factory) {
    _document = _CodeMirrorDocument._(this, cm.doc);
    _instances[cm.jsProxy] = this;
  }

  factory _CodeMirrorEditor._fromExisting(
      CodeMirrorFactory factory, CodeMirror cm) {
    // TODO: We should ensure that the Dart `CodeMirror` wrapper returns the
    // same instances to us when possible (or, identity is based on the
    // underlying JS proxy).
    if (_instances.containsKey(cm.jsProxy)) {
      return _instances[cm.jsProxy]!;
    } else {
      return _CodeMirrorEditor._(factory, cm);
    }
  }

  @override
  Document get document => _document;

  @override
  Document createDocument({String? content, String? mode}) {
    if (mode == 'html') mode = 'text/html';
    content ??= '';

    return _CodeMirrorDocument._(this, Doc(content, mode));
  }

  @override
  void execCommand(String name) => cm.execCommand(name);

  @override
  Map<String, dynamic> startSearch(String query, bool reverse,
      bool highlightOnly, bool matchCase, bool wholeWord, bool regEx) {
    final JsObject? jsobj = cm.callArgs('searchFromDart', [
      query,
      reverse,
      highlightOnly,
      matchCase,
      wholeWord,
      regEx
    ]) as JsObject?;
    if (jsobj != null) {
      return {
        'total': (jsobj['total'] ?? 0) as int,
        'curMatchNum': (jsobj['curMatchNum'] ?? -1) as int,
      };
    } else {
      return {'total': 0, 'curMatchNum': -1};
    }
  }

  @override
  int searchAndReplace(String query, String replaceText, bool replaceAll,
      bool matchCase, bool wholeWord, bool regEx) {
    JsObject? jsobj;
    if (replaceAll) {
      jsobj = cm.callArgs('replaceAllFromDart',
          [query, replaceText, matchCase, wholeWord, regEx]) as JsObject?;
    } else {
      jsobj = cm.callArgs('replaceNextFromDart',
          [query, replaceText, matchCase, wholeWord, regEx]) as JsObject?;
    }
    if (jsobj != null) {
      return (jsobj['total'] ?? 0) as int;
    } else {
      return 0;
    }
  }

  @override
  String? getTokenWeAreOnOrNear([String? regEx]) {
    final String? foundToken =
        cm.callArg('getTokenWeAreOnOrNear', regEx) as String?;
    return foundToken;
  }

  @override
  Map<String, dynamic> getMatchesFromSearchQueryUpdatedCallback() {
    final JsObject? jsobj = cm.callArg(
        'getMatchesFromSearchQueryUpdatedCallback', null) as JsObject?;
    if (jsobj != null) {
      return {
        'total': (jsobj['total'] ?? 0) as int,
        'curMatchNum': (jsobj['curMatchNum'] ?? -1) as int,
      };
    } else {
      return {'total': 0, 'curMatchNum': -1};
    }
  }

  @override
  void clearActiveSearch() {
    cm.callArg('clearActiveSearch', null);
  }

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
    final completionActive = _jsProxyState!['completionActive'];
    if (completionActive is Map) {
      return completionActive['widget'] != null;
    } else {
      return false;
    }
  }

  @override
  bool? get autoCloseBrackets => cm.getOption('autoCloseBrackets') as bool?;

  @override
  set autoCloseBrackets(bool? value) =>
      cm.setOption('autoCloseBrackets', value);

  @override
  String get mode => cm.getMode()!;

  @override
  set mode(String str) => cm.setMode(str);

  @override
  String get theme => cm.getTheme()!;

  @override
  set theme(String str) => cm.setTheme(str);

  @override
  dynamic getOption(String option) => cm.getOption(option);

  @override
  void setOption(String option, dynamic value) => cm.setOption(option, value);

  @override
  String get keyMap {
    dynamic keymap = cm.getOption('keyMap');
    if (keymap == null || (keymap as String).isEmpty) keymap = 'default';
    return keymap;
  }

  /// Valid options are `default` or `vim`
  /// (in order to use `emacs` or `sublime` we MUST also INCLUDE those keymaps.js files in the html containers)
  @override
  set keyMap(String? newkeymap) {
    if (newkeymap == null || newkeymap.isEmpty) newkeymap = 'default';
    cm.setOption('keyMap', newkeymap);
  }

  @override
  bool get hasFocus => _jsProxyState?['focused'] == true;

  @override
  Stream<html.MouseEvent> get onMouseDown => cm.onMouseDown;

  @override
  Point getCursorCoords({ed.Position? position}) {
    JsObject? js;
    if (position == null) {
      js = cm.call('cursorCoords') as JsObject?;
    } else {
      final proxyPos = _document._posToPos(position).toProxy();
      js = cm.callArg('cursorCoords', proxyPos) as JsObject?;
    }
    return Point(js!['left'] as num, js['top'] as num);
  }

  @override
  void focus() => cm.focus();

  @override
  void resize() => cm.refresh();

  @override
  bool get readOnly => cm.getReadOnly();

  @override
  set readOnly(bool ro) => cm.setReadOnly(ro);

  @override
  bool get showLineNumbers => cm.getLineNumbers()!;

  @override
  set showLineNumbers(bool ln) => cm.setLineNumbers(ln);

  @override
  void swapDocument(Document document) {
    _document = document as _CodeMirrorDocument;
    cm.swapDoc(_document.doc);
  }

  @override
  void dispose() {
    _instances.remove(cm.jsProxy);
  }

  JsObject? get _jsProxy => cm.jsProxy;

  JsObject? get _jsProxyState => _jsProxy?['state'] as JsObject?;
}

class _CodeMirrorDocument extends Document<_CodeMirrorEditor> {
  final Doc doc;

  final List<LineWidget> widgets = [];
  final List<html.DivElement> nodes = [];

  /// We use `_lastSetValue` here to avoid a change notification when we
  /// programmatically change the `value` field.
  String? _lastSetValue;

  _CodeMirrorDocument._(_CodeMirrorEditor editor, this.doc) : super(editor);

  _CodeMirrorEditor get parent => editor;

  @override
  String get value => doc.getValue()!;

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
  void select(ed.Position start, [ed.Position? end]) {
    if (end != null) {
      doc.setSelection(_posToPos(start), head: _posToPos(end));
    } else {
      doc.setSelection(_posToPos(start));
    }
  }

  @override

  /// is there anything selected
  bool get somethingSelected => doc.somethingSelected();

  @override
  String get selection => doc.getSelection(
      value)!; //KLUDGE 'value' seems wrong, supposed to be line separator and value is THE ENTIRE DOCUMENT

  @override
  void replaceSelection(String replacement, [String? select]) {
    doc.replaceSelection(replacement, value);
  }

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
    for (final marker in doc.getAllMarks()) {
      marker.clear();
    }

    for (final widget in widgets) {
      widget.clear();
    }
    widgets.clear();

    for (final e in nodes) {
      e.parent!.children.remove(e);
    }
    nodes.clear();

    // Sort annotations so that the errors are set first.
    annotations.sort();

    var lastLine = -1;

    for (final an in annotations) {
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
      doc.indexFromPos(_posToPos(position))!;

  @override
  ed.Position posFromIndex(int index) => _posFromPos(doc.posFromIndex(index));

  pos.Position _posToPos(ed.Position position) =>
      pos.Position(position.line, position.char);

  ed.Position _posFromPos(pos.Position position) =>
      ed.Position(position.line!, position.ch!);

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

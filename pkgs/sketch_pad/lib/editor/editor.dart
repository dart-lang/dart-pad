// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:ui_web' as ui_web;

import 'package:dartpad_shared/services.dart' as services;
import 'package:flutter/material.dart';
import 'package:web/helpers.dart' as web_helpers;
import 'package:web/web.dart' as web;

import '../model.dart';
import 'codemirror.dart';

const String _viewType = 'dartpad-editor';

bool _viewFactoryInitialized = false;
CodeMirror? codeMirrorInstance;

final Key _elementViewKey = UniqueKey();

void _initViewFactory() {
  if (_viewFactoryInitialized) return;
  _viewFactoryInitialized = true;

  ui_web.platformViewRegistry
      .registerViewFactory(_viewType, _codeMirrorFactory);
}

web.Element _codeMirrorFactory(int viewId) {
  final div = web_helpers.createElementTag('div') as web.HTMLDivElement
    ..style.width = '100%'
    ..style.height = '100%';

  codeMirrorInstance = CodeMirror(
      div,
      <String, dynamic>{
        'lineNumbers': true,
        'lineWrapping': true,
        'mode': 'dart',
        'theme': 'darkpad',
        ...codeMirrorOptions,
      }.jsify());

  CodeMirror.commands.goLineLeft =
      ((JSObject? _) => _handleGoLineLeft(codeMirrorInstance!)).toJS;
  CodeMirror.commands.indentIfMultiLineSelectionElseInsertSoftTab =
      ((JSObject? _) =>
              _indentIfMultiLineSelectionElseInsertSoftTab(codeMirrorInstance!))
          .toJS;
  CodeMirror.commands.weHandleElsewhere =
      ((JSObject? _) => _weHandleElsewhere(codeMirrorInstance!)).toJS;

  return div;
}

class EditorWidget extends StatefulWidget {
  final AppModel appModel;
  final AppServices appServices;

  EditorWidget({
    required this.appModel,
    required this.appServices,
    super.key,
  }) {
    _initViewFactory();
  }

  @override
  State<EditorWidget> createState() => _EditorWidgetState();
}

class _EditorWidgetState extends State<EditorWidget> implements EditorService {
  StreamSubscription<void>? listener;
  CodeMirror? codeMirror;
  CompletionType completionType = CompletionType.auto;

  @override
  void showCompletions() {
    completionType = CompletionType.manual;

    codeMirror?.execCommand('autocomplete');
  }

  @override
  void showQuickFixes() {
    completionType = CompletionType.quickfix;

    codeMirror?.execCommand('autocomplete');
  }

  @override
  void jumpTo(services.AnalysisIssue issue) {
    final line = math.max(issue.location.line - 1, 0);
    final column = math.max(issue.location.column - 1, 0);

    if (issue.location.line != -1) {
      codeMirror!.getDoc().setSelection(
            Position(line: line, ch: column),
            Position(line: line, ch: column + issue.location.charLength),
          );
    } else {
      codeMirror?.getDoc().setSelection(Position(line: 0, ch: 0));
    }

    codeMirror?.focus();
  }

  @override
  void initState() {
    super.initState();

    widget.appModel.appReady.addListener(_updateEditableStatus);
  }

  void _platformViewCreated(int id, {required bool darkMode}) {
    codeMirror = codeMirrorInstance;

    // read only
    final readOnly = !widget.appModel.appReady.value;
    if (readOnly) {
      codeMirror!.setReadOnly(true);
    }

    // contents
    final contents = widget.appModel.sourceCodeController.text;
    codeMirror!.getDoc().setValue(contents);

    // darkmode
    _updateCodemirrorMode(darkMode);

    Timer.run(() => codeMirror!.refresh());

    codeMirror!.on(
      'change',
      ([JSAny? _, JSAny? __, JSAny? ___]) {
        _updateModelFromCodemirror(codeMirror!.getDoc().getValue());
      }.toJS,
    );

    final appModel = widget.appModel;

    appModel.sourceCodeController.addListener(_updateCodemirrorFromModel);
    appModel.analysisIssues
        .addListener(() => _updateIssues(appModel.analysisIssues.value));

    widget.appServices.registerEditorService(this);

    CodeMirror.commands.autocomplete = (CodeMirror codeMirror) {
      _completions().then((completions) {
        codeMirror.showHint(
            HintOptions(hint: CodeMirror.hint.dart, results: completions));
      });
      return JSObject();
    }.toJS;

    CodeMirror.registerHelper(
        'hint',
        'dart',
        (CodeMirror editor, [HintOptions? options]) {
          return options!.results;
        }.toJS);
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = Theme.of(context).brightness == Brightness.dark;

    _updateCodemirrorMode(darkMode);

    return HtmlElementView(
      key: _elementViewKey,
      viewType: _viewType,
      onPlatformViewCreated: (id) =>
          _platformViewCreated(id, darkMode: darkMode),
    );
  }

  @override
  void dispose() {
    listener?.cancel();

    widget.appServices.registerEditorService(null);

    widget.appModel.sourceCodeController
        .removeListener(_updateCodemirrorFromModel);
    widget.appModel.appReady.removeListener(_updateEditableStatus);

    super.dispose();
  }

  void _updateModelFromCodemirror(String value) {
    final model = widget.appModel;

    model.sourceCodeController.removeListener(_updateCodemirrorFromModel);
    widget.appModel.sourceCodeController.text = value;
    model.sourceCodeController.addListener(_updateCodemirrorFromModel);
  }

  void _updateCodemirrorFromModel() {
    final value = widget.appModel.sourceCodeController.text;
    codeMirror?.getDoc().setValue(value);
  }

  void _updateEditableStatus() {
    codeMirror?.setReadOnly(!widget.appModel.appReady.value);
  }

  void _updateIssues(List<services.AnalysisIssue> issues) {
    final doc = codeMirror!.getDoc();

    for (final marker in doc.getAllMarks().toDart.cast<TextMarker>()) {
      marker.clear();
    }

    for (final issue in issues) {
      final line = math.max(issue.location.line - 1, 0);
      final column = math.max(issue.location.column - 1, 0);

      doc.markText(
        Position(line: line, ch: column),
        Position(line: line, ch: column + issue.location.charLength),
        MarkTextOptions(
          className: 'squiggle-${issue.kind}',
          title: issue.message,
        ),
      );
    }
  }

  void _updateCodemirrorMode(bool darkMode) {
    codeMirror?.setTheme(darkMode ? 'darkpad' : 'dartpad');
  }

  Future<HintResults> _completions() async {
    final operation = completionType;
    completionType = CompletionType.auto;

    final appServices = widget.appServices;

    final editor = codeMirror!;
    final doc = editor.getDoc();
    final source = doc.getValue();
    final sourceOffset = doc.indexFromPos(editor.getCursor()) ?? 0;

    if (operation == CompletionType.quickfix) {
      final response = await appServices.services
          .fixes(services.SourceRequest(source: source, offset: sourceOffset))
          .onError((error, st) => services.FixesResponse.empty);

      if (response.fixes.isEmpty && response.assists.isEmpty) {
        widget.appModel.editorStatus.showToast('No quick fixes available.');
      }

      return HintResults(
        list: [
          ...response.fixes.map((change) => change.toHintResult(editor)),
          ...response.assists.map((change) => change.toHintResult(editor)),
        ].jsify() as JSArray,
        from: doc.posFromIndex(sourceOffset),
        to: doc.posFromIndex(0),
      );
    } else {
      final response = await appServices.services
          .complete(
              services.SourceRequest(source: source, offset: sourceOffset))
          .onError((error, st) => services.CompleteResponse.empty);

      final offset = response.replacementOffset;
      final length = response.replacementLength;
      final hints = response.suggestions
          .map((suggestion) => suggestion.toHintResult())
          .toList();

      // Remove hints where both the replacement text and the display text are the
      // same.
      final memos = <String>{};
      hints.retainWhere((hint) {
        return memos.add('${hint.text}:${hint.displayText}');
      });

      return HintResults(
          list: hints.jsify() as JSArray,
          from: doc.posFromIndex(offset),
          to: doc.posFromIndex(offset + length));
    }
  }
}

// codemirror commands

JSAny? _handleGoLineLeft(CodeMirror editor) {
  // Change the cmd-left behavior to move the cursor to the leftmost non-ws
  // char.
  editor.execCommand('goLineLeftSmart');
  return JSObject();
}

void _indentIfMultiLineSelectionElseInsertSoftTab(CodeMirror editor) {
  // Make it so that we can insertSoftTab when no selection or selection on 1
  // line but if there is multiline selection we indentMore (this gives us a
  // more typical coding editor behavior).
  if (editor.getDoc().somethingSelected()) {
    final selection = editor.getDoc().getSelection('\n');
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
  // within codemorror.
}

// codemirror options

const codeMirrorOptions = {
  'autoCloseBrackets': true,
  'autoCloseTags': {
    'whenOpening': true,
    'whenClosing': true,
  },
  'autofocus': false,
  'cursorHeight': 0.85,
  'continueComments': {
    'continueLineComment': false,
  },
  'extraKeys': {
    'Esc': '...',
    'Esc Tab': false,
    'Esc Shift-Tab': false,
    'Cmd-/': 'toggleComment',
    'Ctrl-/': 'toggleComment',
    'Shift-Tab': 'indentLess',
    'Tab': 'indentIfMultiLineSelectionElseInsertSoftTab',
    'Cmd-F': 'weHandleElsewhere',
    'Cmd-H': 'weHandleElsewhere',
    'Ctrl-F': 'weHandleElsewhere',
    'Ctrl-H': 'weHandleElsewhere',
    'Cmd-G': 'weHandleElsewhere',
    'Shift-Ctrl-G': 'weHandleElsewhere',
    'Ctrl-G': 'weHandleElsewhere',
    'Shift-Cmd-G': 'weHandleElsewhere',
    'F4': 'weHandleElsewhere',
    'Shift-F4': 'weHandleElsewhere',
    'Shift-Ctrl-F': 'weHandleElsewhere',
    'Shift-Cmd-F': 'weHandleElsewhere',
    'Cmd-Alt-F': false,
    // vscode folding key combos (pc/mac)
    'Shift-Ctrl-[': 'ourFoldWithCursorToStart',
    'Cmd-Alt-[': 'ourFoldWithCursorToStart',
    'Shift-Ctrl-]': 'unfold',
    'Cmd-Alt-]': 'unfold',
    // made our own keycombo since VSCode and AndroidStudio's
    'Shift-Ctrl-Alt-[': 'foldAll',
    // are taken by browser
    'Shift-Cmd-Alt-[': 'foldAll',
    'Shift-Ctrl-Alt-]': 'unfoldAll',
    'Shift-Cmd-Alt-]': 'unfoldAll',
  },
  'foldGutter': true,
  'foldOptions': {
    'minFoldSize': 1,
    // like '...', but middle dots
    'widget': '\u00b7\u00b7\u00b7',
  },
  'gutters': [
    'CodeMirror-linenumbers',
    'CodeMirror-foldgutter',
  ],
  'highlightSelectionMatches': {
    'style': 'highlight-selection-matches',
    'showToken': false,
    'annotateScrollbar': true,
  },
  'hintOptions': {
    'completeSingle': false,
  },
  'indentUnit': 2,
  'matchBrackets': true,
  'matchTags': {
    'bothTags': true,
  },
  'tabSize': 2,
  'viewportMargin': 100,
};

enum CompletionType {
  auto,
  manual,
  quickfix,
}

extension CompletionSuggestionExtension on services.CompletionSuggestion {
  HintResult toHintResult() {
    var altDisplay = completion;
    if (elementKind == 'FUNCTION' ||
        elementKind == 'METHOD' ||
        elementKind == 'CONSTRUCTOR') {
      altDisplay = '$altDisplay()';
    }

    return HintResult(
      text: completion,
      displayText: displayText ?? altDisplay,
      className: this.deprecated ? 'deprecated' : null,
    );
  }
}

extension SourceChangeExtension on services.SourceChange {
  HintResult toHintResult(CodeMirror codeMirror) {
    return HintResult(text: message, hint: _applySourceChange(codeMirror));
  }

  JSFunction _applySourceChange(CodeMirror codeMirror) {
    return (HintResult hint, Position? from, Position? to) {
      final doc = codeMirror.getDoc();

      for (final edit in edits) {
        doc.replaceRange(
          edit.replacement,
          doc.posFromIndex(edit.offset),
          doc.posFromIndex(edit.offset + edit.length),
        );
      }
    }.toJS;
  }
}

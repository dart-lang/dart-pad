// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:ui_web' as ui_web;

import 'package:codemirror/codemirror.dart';
import 'package:codemirror/hints.dart';
import 'package:dartpad_shared/services.dart' as services;
import 'package:flutter/material.dart';

import '../model.dart';

final Key _elementViewKey = UniqueKey();

html.Element _codeMirrorFactory(int viewId) {
  final div = html.DivElement()
    ..style.width = '100%'
    ..style.height = '100%';

  final codeMirror = CodeMirror.fromElement(div, options: <String, dynamic>{
    'lineNumbers': true,
    'lineWrapping': true,
    'mode': 'dart',
    'theme': 'darkpad',
    ...codeMirrorOptions,
  });

  CodeMirror.addCommand('goLineLeft', _handleGoLineLeft);
  CodeMirror.addCommand(
    'indentIfMultiLineSelectionElseInsertSoftTab',
    _indentIfMultiLineSelectionElseInsertSoftTab,
  );
  CodeMirror.addCommand('weHandleElsewhere', _weHandleElsewhere);

  _expando[div] = codeMirror;

  return div;
}

const String _viewType = 'dartpad-editor';
final Expando _expando = Expando(_viewType);

bool _viewFactoryInitialized = false;

void _initViewFactory() {
  if (_viewFactoryInitialized) return;
  _viewFactoryInitialized = true;

  ui_web.platformViewRegistry
      .registerViewFactory(_viewType, _codeMirrorFactory);
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
      codeMirror!.doc.setSelection(
        Position(line, column),
        head: Position(line, column + issue.location.charLength),
      );
    } else {
      codeMirror?.doc.setSelection(Position(0, 0));
    }

    codeMirror?.focus();
  }

  @override
  void initState() {
    super.initState();

    widget.appModel.appReady.addListener(_updateEditableStatus);
  }

  void _platformViewCreated(int id, {required bool darkMode}) {
    final div = ui_web.platformViewRegistry.getViewById(id) as html.Element;
    codeMirror = _expando[div] as CodeMirror;

    // read only
    final readOnly = !widget.appModel.appReady.value;
    if (readOnly) {
      codeMirror!.setReadOnly(true);
    }

    // contents
    final contents = widget.appModel.sourceCodeController.text;
    codeMirror!.doc.setValue(contents);

    // darkmode
    _updateCodemirrorMode(darkMode);

    Timer.run(() => codeMirror!.refresh());

    listener?.cancel();
    listener = codeMirror!.onChange.listen((event) {
      _updateModelFromCodemirror(codeMirror!.doc.getValue() ?? '');
    });

    final appModel = widget.appModel;

    appModel.sourceCodeController.addListener(_updateCodemirrorFromModel);
    appModel.analysisIssues
        .addListener(() => _updateIssues(appModel.analysisIssues.value));

    widget.appServices.registerEditorService(this);

    Hints.registerHintsHelperAsync('dart', _completions);
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
    codeMirror!.doc.setValue(value);
  }

  void _updateEditableStatus() {
    codeMirror?.setReadOnly(!widget.appModel.appReady.value);
  }

  void _updateIssues(List<services.AnalysisIssue> issues) {
    final doc = codeMirror!.doc;

    for (final marker in doc.getAllMarks()) {
      marker.clear();
    }

    for (final issue in issues) {
      final line = math.max(issue.location.line - 1, 0);
      final column = math.max(issue.location.column - 1, 0);

      doc.markText(
        Position(line, column),
        Position(line, column + issue.location.charLength),
        className: 'squiggle-${issue.kind}',
        title: issue.message,
      );
    }
  }

  void _updateCodemirrorMode(bool darkMode) {
    codeMirror?.setTheme(darkMode ? 'darkpad' : 'dartpad');
  }

  Future<HintResults> _completions(CodeMirror _, [HintsOptions? __]) async {
    final operation = completionType;
    completionType = CompletionType.auto;

    final appServices = widget.appServices;

    final editor = codeMirror!;
    final doc = editor.doc;
    final source = doc.getValue() ?? '';
    final sourceOffset = doc.indexFromPos(doc.getCursor()) ?? 0;

    if (operation == CompletionType.quickfix) {
      final response = await appServices.services
          .fixes(services.SourceRequest(source: source, offset: sourceOffset))
          .onError((error, st) => services.FixesResponse.empty);

      if (response.fixes.isEmpty && response.assists.isEmpty) {
        widget.appModel.editorStatus.showToast('No quick fixes available.');
      }

      return HintResults.fromHints([
        ...response.fixes.map((change) => change.toHintResult()),
        ...response.assists.map((change) => change.toHintResult()),
      ], doc.posFromIndex(sourceOffset), doc.posFromIndex(0));
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

      return HintResults.fromHints(
          hints, doc.posFromIndex(offset), doc.posFromIndex(offset + length));
    }
  }
}

// codemirror commands

void _handleGoLineLeft(CodeMirror editor) {
  // Change the cmd-left behavior to move the cursor to the leftmost non-ws
  // char.
  editor.execCommand('goLineLeftSmart');
}

void _indentIfMultiLineSelectionElseInsertSoftTab(CodeMirror editor) {
  // Make it so that we can insertSoftTab when no selection or selection on 1
  // line but if there is multiline selection we indentMore (this gives us a
  // more typical coding editor behavior).
  if (editor.doc.somethingSelected()) {
    final selection = editor.doc.getSelection('\n');
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
      completion,
      displayText: displayText ?? altDisplay,
      className: this.deprecated ? 'deprecated' : null,
    );
  }
}

extension SourceChangeExtension on services.SourceChange {
  HintResult toHintResult() {
    return HintResult(message, hintApplier: _applySourceChange);
  }

  void _applySourceChange(
      CodeMirror editor, HintResult hint, Position? from, Position? to) {
    final doc = editor.doc;

    for (final edit in edits) {
      doc.replaceRange(
        edit.replacement,
        doc.posFromIndex(edit.offset),
        doc.posFromIndex(edit.offset + edit.length),
      );
    }
  }
}

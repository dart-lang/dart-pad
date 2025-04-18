// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/model.dart';
import 'package:flutter/widgets.dart';

import '../model.dart';
import '_codemirror.dart';

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:ui_web' as ui_web;

import 'package:dartpad_shared/services.dart' as services;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pretty_diff_text/pretty_diff_text.dart';
import 'package:web/web.dart' as web;

import '../local_storage/local_storage.dart';
import '../model.dart';
import '_codemirror.dart';
import '_shared.dart';
import '_stub.dart' as stub;

CodeMirror? codeMirrorInstance;

enum _CompletionType { auto, manual, quickfix }

bool _viewFactoryInitialized = false;

class ConcreteEditorServiceImpl implements stub.ConcreteEditorServiceImpl {
  CodeMirror? _codeMirror;
  late final FocusNode _focusNode;
  _CompletionType _completionType = _CompletionType.auto;
  final Key _elementViewKey = UniqueKey();

  ConcreteEditorServiceImpl() {
    _initViewFactory();

    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (!node.hasFocus) {
          return KeyEventResult.ignored;
        }

        // If focused, allow CodeMirror to handle tab.
        if (event.logicalKey == LogicalKeyboardKey.tab) {
          return KeyEventResult.skipRemainingHandlers;
        } else if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.period) {
          // On a period, auto-invoke code completions.

          // If any modifiers keys are depressed, ignore this event. Note that
          // directly querying `HardwareKeyboard.instance` could have a race
          // condition (we'd like to read this information directly from the
          // event).
          if (HardwareKeyboard.instance.isAltPressed ||
              HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed ||
              HardwareKeyboard.instance.isShiftPressed) {
            return KeyEventResult.ignored;
          }

          // We introduce a delay here to allow codemirror to process the key
          // event.
          Timer.run(() => showCompletions(autoInvoked: true));

          return KeyEventResult.skipRemainingHandlers;
        }

        if (event.logicalKey == LogicalKeyboardKey.escape) {
          if (_codeMirror == null) {
            return KeyEventResult.ignored;
          }

          CodeMirror.vim.handleEsc(_codeMirror!);
        }

        return KeyEventResult.ignored;
      },
    );
  }

  @override
  int get cursorOffset {
    final pos = _codeMirror?.getCursor();
    if (pos == null) return 0;

    return _codeMirror?.getDoc().indexFromPos(pos) ?? 0;
  }

  @override
  void focus() {
    _focusNode.requestFocus();
  }

  @override
  void jumpTo(services.AnalysisIssue issue) {
    final line = math.max(issue.location.line - 1, 0);
    final column = math.max(issue.location.column - 1, 0);

    if (issue.location.line != -1) {
      _codeMirror!.getDoc().setSelection(
        Position(line: line, ch: column),
        Position(line: line, ch: column + issue.location.charLength),
      );
    } else {
      _codeMirror?.getDoc().setSelection(Position(line: 0, ch: 0));
    }

    focus();
  }

  @override
  void refreshViewAfterWait() {
    // Use a longer delay so that the platform view is displayed
    // correctly when compiled to Wasm.
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      _codeMirror?.refresh();
    });
  }

  @override
  void showCompletions({required bool autoInvoked}) {
    _completionType =
        autoInvoked ? _CompletionType.auto : _CompletionType.manual;

    _codeMirror?.execCommand('autocomplete');
  }

  @override
  void showQuickFixes() {
    _completionType = _CompletionType.quickfix;

    _codeMirror?.execCommand('autocomplete');
  }

  @override
  FocusableActionDetector focusableActionDetector(bool darkMode) {
    return FocusableActionDetector(
      autofocus: true,
      focusNode: _focusNode,
      onFocusChange: (isFocused) {
        // If focus is entering or leaving, convey this to CodeMirror.
        if (isFocused) {
          _codeMirror?.focus();
        } else {
          _codeMirror?.getInputField().blur();
        }
      },
      // TODO(parlough): Add shortcut for focus traversal to escape editor.
      // shortcuts: {
      //   // Add Esc and Shift+Esc as shortcuts for focus to leave editor.
      //   LogicalKeySet(LogicalKeyboardKey.escape):
      //       VoidCallbackIntent(_focusNode.nextFocus),
      //   LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.escape):
      //       VoidCallbackIntent(_focusNode.previousFocus),
      // },
      child: HtmlElementView(
        key: _elementViewKey,
        viewType: editorViewType,
        onPlatformViewCreated:
            (id) => _platformViewCreated(id, darkMode: darkMode),
      ),
    );
  }

  void _platformViewCreated(int id, {required bool darkMode}) {
    _codeMirror = codeMirrorInstance;

    final appModel = widget.appModel;

    // read only
    final readOnly = !appModel.appReady.value;
    if (readOnly) {
      _codeMirror!.setReadOnly(true);
    }

    // contents
    final contents = appModel.sourceCodeController.text;
    _codeMirror!.getDoc().setValue(contents);

    // darkmode
    _updateCodemirrorMode(darkMode);

    refreshViewAfterWait();

    _codeMirror!.on(
      'change',
      ([JSAny? _, JSAny? __, JSAny? ___]) {
        _updateModelFromCodemirror(_codeMirror!.getDoc().getValue());
      }.toJS,
    );

    _codeMirror!.on(
      'focus',
      ([JSAny? _, JSAny? __]) {
        _focusNode.requestFocus();
      }.toJS,
    );

    _codeMirror!.on(
      'blur',
      ([JSAny? _, JSAny? __]) {
        _focusNode.unfocus();
      }.toJS,
    );

    appModel.sourceCodeController.addListener(_updateCodemirrorFromModel);
    appModel.analysisIssues.addListener(
      () => _updateIssues(appModel.analysisIssues.value),
    );
    appModel.vimKeymapsEnabled.addListener(_updateCodemirrorKeymap);

    widget.appServices.registerEditorService(this);

    CodeMirror.commands.autocomplete =
        (CodeMirror codeMirror) {
          _completions().then((completions) {
            codeMirror.showHint(
              HintOptions(hint: CodeMirror.hint.dart, results: completions),
            );
          });
          return JSObject();
        }.toJS;

    CodeMirror.registerHelper(
      'hint',
      'dart',
      (CodeMirror editor, [HintOptions? options]) {
        return options!.results;
      }.toJS,
    );

    // Listen for document body to be visible, then force a code mirror refresh.
    final observer = web.IntersectionObserver(
      (
        JSArray<web.IntersectionObserverEntry> entries,
        web.IntersectionObserver observer,
      ) {
        for (final entry in entries.toDart) {
          if (entry.isIntersecting) {
            observer.unobserve(web.document.body!);
            refreshViewAfterWait();
            return;
          }
        }
      }.toJS,
    );

    observer.observe(web.document.body!);
  }
}

void _initViewFactory() {
  if (_viewFactoryInitialized) return;
  _viewFactoryInitialized = true;

  ui_web.platformViewRegistry.registerViewFactory(
    editorViewType,
    _codeMirrorFactory,
  );
}

web.Element _codeMirrorFactory(int viewId) {
  final div =
      web.document.createElement('div') as web.HTMLDivElement
        ..style.width = '100%'
        ..style.height = '100%';

  codeMirrorInstance = CodeMirror(
    div,
    <String, Object?>{
      'lineNumbers': true,
      'lineWrapping': true,
      'mode': 'dart',
      'theme': 'darkpad',
      ..._codeMirrorOptions,
    }.jsify(),
  );

  CodeMirror.commands.goLineLeft =
      ((JSObject? _) => _handleGoLineLeft(codeMirrorInstance!)).toJS;
  CodeMirror.commands.indentIfMultiLineSelectionElseInsertSoftTab =
      ((JSObject? _) =>
              _indentIfMultiLineSelectionElseInsertSoftTab(codeMirrorInstance!))
          .toJS;
  CodeMirror.commands.weHandleElsewhere =
      ((JSObject? _) => _weHandleElsewhere(codeMirrorInstance!)).toJS;

  // Prevent the flutter web engine from handling (and preventing default on)
  // wheel events over CodeMirror's HtmlElementView.
  //
  // This is needed so users can scroll code with their mouse wheel.
  div.addEventListener(
    'wheel',
    (web.WheelEvent e) {
      e.stopPropagation();
    }.toJS,
  );

  return div;
}

JSAny? _handleGoLineLeft(CodeMirror editor) {
  // Change the cmd-left behavior to move the cursor to leftmost non-ws char.
  return editor.execCommand('goLineLeftSmart');
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

const _codeMirrorOptions = {
  'autoCloseBrackets': true,
  'autoCloseTags': {'whenOpening': true, 'whenClosing': true},
  'autofocus': false,
  'cursorHeight': 0.85,
  'continueComments': {'continueLineComment': false},
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
  },
  'gutters': ['CodeMirror-linenumbers'],
  'highlightSelectionMatches': {
    'style': 'highlight-selection-matches',
    'showToken': false,
    'annotateScrollbar': true,
  },
  'hintOptions': {'completeSingle': false},
  'indentUnit': 2,
  'matchBrackets': true,
  'matchTags': {'bothTags': true},
  'tabSize': 2,
  'viewportMargin': 100,
  'scrollbarStyle': 'simple',
};

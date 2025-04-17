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

class ConcreteEditorServiceImpl implements EditorService {
  CodeMirror? _codeMirror;
  late final FocusNode _focusNode;

  EditorServiceImpl() {
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
  void jumpTo(AnalysisIssue issue) {}

  @override
  void refreshViewAfterWait() {}

  @override
  void showCompletions({required bool autoInvoked}) {}

  @override
  void showQuickFixes() {}
}

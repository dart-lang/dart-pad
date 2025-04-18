// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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
import '_editor_service_impl.dart';
import '_shared.dart';

// TODO: implement find / find next

class EditorWidget extends StatefulWidget {
  final AppModel appModel;
  final AppServices appServices;

  EditorWidget({
    required this.appModel,
    required this.appServices,
    super.key,
  }) {}

  @override
  State<EditorWidget> createState() => _EditorWidgetState();
}

class _EditorWidgetState extends State<EditorWidget> {
  StreamSubscription<void>? _listener;
  final _editorService = EditorServiceImpl();

  @override
  void initState() {
    super.initState();
    _autosaveTimer = Timer.periodic(const Duration(seconds: 5), _autosave);
    widget.appModel.appReady.addListener(_updateEditableStatus);
  }

  Timer? _autosaveTimer;
  void _autosave([Timer? timer]) {
    final content = widget.appModel.sourceCodeController.text;
    if (content.isEmpty) return;
    DartPadLocalStorage.instance.saveUserCode(content);
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = Theme.of(context).brightness == Brightness.dark;
    _updateCodemirrorMode(darkMode);
    return _editorService.focusableActionDetector(darkMode);
  }

  @override
  void dispose() {
    _listener?.cancel();
    _autosaveTimer?.cancel();

    widget.appServices.registerEditorService(null);

    widget.appModel.sourceCodeController.removeListener(
      _updateCodemirrorFromModel,
    );
    widget.appModel.appReady.removeListener(_updateEditableStatus);
    widget.appModel.vimKeymapsEnabled.removeListener(_updateCodemirrorKeymap);

    super.dispose();
  }

  void _updateModelFromCodemirror(String value) {
    final model = widget.appModel;

    model.sourceCodeController.removeListener(_updateCodemirrorFromModel);
    widget.appModel.sourceCodeController.text = value;
    model.sourceCodeController.addListener(_updateCodemirrorFromModel);
  }

  void _updateCodemirrorFromModel() {
    final value = widget.appModel.sourceCodeController.value;
    final cursorOffset = value.selection.baseOffset;
    final cm = _codeMirror!;
    final doc = cm.getDoc();

    if (cursorOffset == -1) {
      doc.setValue(value.text);
    } else {
      final scrollInfo = cm.getScrollInfo();
      doc.setValue(value.text);
      doc.setSelection(doc.posFromIndex(cursorOffset));
      cm.scrollTo(scrollInfo.left, scrollInfo.top);
    }
  }

  void _updateEditableStatus() {
    _codeMirror?.setReadOnly(!widget.appModel.appReady.value);
  }

  void _updateIssues(List<services.AnalysisIssue> issues) {
    final doc = _codeMirror!.getDoc();

    for (final marker in doc.getAllMarks().toDart.cast<TextMarker>()) {
      marker.clear();
    }

    for (final issue in issues) {
      final line = math.max(issue.location.line - 1, 0);
      final column = math.max(issue.location.column - 1, 0);
      final isDeprecation =
          issue.code?.contains('deprecated_member_use') ?? false;
      final kind = isDeprecation ? 'deprecation' : issue.kind;

      doc.markText(
        Position(line: line, ch: column),
        Position(line: line, ch: column + issue.location.charLength),
        MarkTextOptions(className: 'squiggle-$kind', title: issue.message),
      );
    }
  }

  void _updateCodemirrorMode(bool darkMode) {
    _codeMirror?.setTheme(darkMode ? 'darkpad' : 'dartpad');
  }

  Future<HintResults> _completions() async {
    final operation = completionType;
    completionType = CompletionType.auto;

    final appServices = widget.appServices;

    final editor = _codeMirror!;
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
        list:
            [
              ...response.fixes.map((change) => change.toHintResult(editor)),
              ...response.assists.map((change) => change.toHintResult(editor)),
            ].toJS,
        from: doc.posFromIndex(sourceOffset),
        to: doc.posFromIndex(0),
      );
    } else {
      final response = await appServices.services
          .complete(
            services.SourceRequest(source: source, offset: sourceOffset),
          )
          .onError((error, st) => services.CompleteResponse.empty);

      final offset = response.replacementOffset;
      final length = response.replacementLength;
      final hints =
          response.suggestions
              .map((suggestion) => suggestion.toHintResult())
              .toList();

      // Remove hints where both the replacement text and the display text are
      // the same.
      final memos = <String>{};
      hints.retainWhere((hint) {
        return memos.add('${hint.text}:${hint.displayText}');
      });

      return HintResults(
        list: hints.toJS,
        from: doc.posFromIndex(offset),
        to: doc.posFromIndex(offset + length),
      );
    }
  }

  void _updateCodemirrorKeymap() {
    final enabled = widget.appModel.vimKeymapsEnabled.value;
    final cm = _codeMirror!;

    if (enabled) {
      cm.setKeymap('vim');
      DartPadLocalStorage.instance.saveUserKeybinding('vim');
    } else {
      cm.setKeymap('default');
      DartPadLocalStorage.instance.saveUserKeybinding('default');
    }
  }
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

class ReadOnlyCodeWidget extends StatefulWidget {
  const ReadOnlyCodeWidget(this.source, {super.key});
  final String source;

  @override
  State<ReadOnlyCodeWidget> createState() => _ReadOnlyCodeWidgetState();
}

class _ReadOnlyCodeWidgetState extends State<ReadOnlyCodeWidget> {
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _textController.text = widget.source;
  }

  @override
  void didUpdateWidget(covariant ReadOnlyCodeWidget oldWidget) {
    if (widget.source != oldWidget.source) {
      setState(() {
        _textController.text = widget.source;
      });
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: SizedBox(
        height: 500,
        child: TextField(
          controller: _textController,
          readOnly: true,
          maxLines: null,
          style: GoogleFonts.robotoMono(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          decoration: const InputDecoration(border: InputBorder.none),
        ),
      ),
    );
  }
}

class ReadOnlyDiffWidget extends StatelessWidget {
  const ReadOnlyDiffWidget({
    required this.existingSource,
    required this.newSource,
    super.key,
  });

  final String existingSource;
  final String newSource;

  // NOTE: the focus is needed to enable GeneratingCodeDialog to process
  // keyboard shortcuts, e.g. cmd+enter
  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: SizedBox(
        height: 500,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: PrettyDiffText(
            oldText: existingSource,
            newText: newSource,
            defaultTextStyle: GoogleFonts.robotoMono(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            addedTextStyle: const TextStyle(
              color: Colors.black,
              backgroundColor: Color.fromARGB(255, 201, 255, 201),
            ),
            deletedTextStyle: const TextStyle(
              color: Colors.black,
              backgroundColor: Color.fromARGB(255, 249, 199, 199),
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ),
      ),
    );
  }
}

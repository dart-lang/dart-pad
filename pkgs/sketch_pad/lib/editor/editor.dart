// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:ui_web' as ui_web;

import 'package:codemirror/codemirror.dart';
import 'package:flutter/material.dart';

import '../model.dart';
import '../services/dartservices.dart';

// TODO: support code completion

final Key _elementViewKey = UniqueKey();

html.Element _codeMirrorFactory(int viewId) {
  final div = html.DivElement()
    ..style.width = '100%'
    ..style.height = '100%';

  // TODO: comments config, tab behavior, ...
  final codeMirror = CodeMirror.fromElement(div, options: <String, dynamic>{
    'mode': 'dart',
    'theme': 'monokai',
    'lineNumbers': true,
    'lineWrapping': true,
  });

  _expando[div] = codeMirror;

  return div;
}

const String _viewType = 'dartpad-editor';
final Expando _expando = Expando(_viewType);

bool _viewFactoryInitialized = false;

void _initViewFactory() {
  if (_viewFactoryInited) return;

  _viewFactoryInited = true;

  ui_web.platformViewRegistry
      .registerViewFactory(_viewType, _codeMirrorFactory);
}

class EditorWidget extends StatefulWidget {
  final AppModel appModel;

  EditorWidget({
    required this.appModel,
    super.key,
  }) {
    _initViewFactory();
  }

  @override
  State<EditorWidget> createState() => _EditorWidgetState();
}

class _EditorWidgetState extends State<EditorWidget> {
  StreamSubscription<void>? listener;
  CodeMirror? codeMirror;

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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final darkMode = colorScheme.brightness == Brightness.dark;

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
    var value = widget.appModel.sourceCodeController.text;
    codeMirror!.doc.setValue(value);
  }

  void _updateEditableStatus() {
    codeMirror?.setReadOnly(!widget.appModel.appReady.value);
  }

  void _updateIssues(List<AnalysisIssue> issues) {
    final doc = codeMirror!.doc;

    for (final marker in doc.getAllMarks()) {
      marker.clear();
    }

    for (final issue in issues) {
      final line = math.max(issue.line - 1, 0);
      final column = math.max(issue.column - 1, 0);

      doc.markText(
        Position(line, column),
        Position(line, column + issue.charLength),
        className: 'squiggle-${issue.kind}',
        title: issue.message,
      );
    }
  }

  void _updateCodemirrorMode(bool darkMode) {
    codeMirror?.setTheme(darkMode ? 'monokai' : 'default');
  }
}

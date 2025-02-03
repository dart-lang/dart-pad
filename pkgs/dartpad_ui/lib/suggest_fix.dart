// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'model.dart';
import 'utils.dart';
import 'widgets.dart';

Future<void> suggestFix({
  required BuildContext context,
  required String errorMessage,
  int? line,
  int? column,
}) async {
  final appModel = Provider.of<AppModel>(context, listen: false);
  final appServices = Provider.of<AppServices>(context, listen: false);
  final existingSource = appModel.sourceCodeController.text;

  try {
    final stream = appServices.suggestFix(
      SuggestFixRequest(
        errorMessage: errorMessage,
        line: line,
        column: column,
        source: existingSource,
      ),
    );

    final result = await showDialog<GeneratingCodeDialogResponse>(
      context: context,
      builder: (context) => GeneratingCodeDialog(
        stream: stream,
        title: 'Generating Fix Suggestion',
        existingSource: existingSource,
      ),
    );

    if (!context.mounted || result == null || result.source.isEmpty) return;

    if (result.source == existingSource) {
      appModel.editorStatus.showToast('No suggested fix');
    } else {
      appModel.editorStatus.showToast('Fix suggested');
      appModel.sourceCodeController.textNoScroll = result.source;
      appServices.editorService!.focus();
      if (result.runNow) appServices.performCompileAndRun();
    }
  } catch (error) {
    appModel.editorStatus.showToast('Error suggesting fix');
    appModel.appendLineToConsole('Suggesting fix issue: $error');
  }
}

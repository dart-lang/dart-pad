// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'model.dart';
import 'utils.dart';
import 'simple_widgets.dart';

Future<void> suggestFix({
  required BuildContext context,
  required AppType appType,
  required String errorMessage,
  int? line,
  int? column,
}) async {
  assert(errorMessage.isNotEmpty);

  final appModel = Provider.of<AppModel>(context, listen: false);
  final appServices = Provider.of<AppServices>(context, listen: false);
  final existingSource = appModel.sourceCodeController.text;

  try {
    final stream = appServices.suggestFix(
      SuggestFixRequest(
        appType: appType,
        errorMessage: errorMessage,
        line: line,
        column: column,
        source: existingSource,
      ),
    );

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => GeneratingCodeDialog(
            stream: stream,
            title: 'Generating fix suggestion',
            existingSource: existingSource,
          ),
    );

    if (!context.mounted || result == null || result.isEmpty) return;

    if (result == existingSource) {
      appModel.editorStatus.showToast('No suggested fix');
    } else {
      appModel.editorStatus.showToast('Fix suggested');
      appModel.sourceCodeController.textNoScroll = result;
      appServices.editorService!.focus();
      appServices.performCompileAndReloadOrRun();
    }
  } catch (error) {
    appModel.editorStatus.showToast('Error suggesting fix');
    appModel.appendLineToConsole('Suggesting fix issue: $error');
  }
}

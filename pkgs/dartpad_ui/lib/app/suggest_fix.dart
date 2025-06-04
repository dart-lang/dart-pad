// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/model.dart';

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

  appModel.genAiManager.enterSuggestingFix();
  appModel.genAiManager.preGenAiSourceCode.value = existingSource;

  try {
    appModel.genAiManager.startStream(
      appServices.suggestFix(
        SuggestFixRequest(
          appType: appType,
          errorMessage: errorMessage,
          line: line,
          column: column,
          source: existingSource,
        ),
      ),
    );
  } catch (error) {
    appModel.editorStatus.showToast('Error suggesting fix');
    appModel.appendLineToConsole('Suggesting fix issue: $error');
    appModel.genAiManager.finishActivity();
  }
}

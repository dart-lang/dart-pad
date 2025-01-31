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

    final newSource = await showDialog<String>(
      context: context,
      builder: (context) => GeneratingCodeDialog(
        stream: stream,
        title: 'Generating Fix Suggestion',
      ),
    );

    if (!context.mounted || newSource == null || newSource.isEmpty) return;

    if (newSource == existingSource) {
      appModel.editorStatus.showToast('No suggested fix');
    } else {
      appModel.editorStatus.showToast('Fix suggested');
      appModel.sourceCodeController.textNoScroll = newSource;
      appServices.editorService!.focus();
    }
  } catch (error) {
    appModel.editorStatus.showToast('Error suggesting fix');
    appModel.appendLineToConsole('Suggesting fix issue: $error');
  }
}

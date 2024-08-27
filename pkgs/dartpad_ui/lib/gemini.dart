// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/services.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';

import 'model.dart';
import 'theme.dart';
import 'widgets.dart';

// TODO: have a 'suggest better prompt' button

// TODO: the disabled buttons should look disabled

// TODO: show errors from the gemini call

const initialGeminiPrompt =
    'Create a stoplight app, containing three lights, controlled by buttons.';

class GeminiStatus {
  final AppModel appModel;

  GeminiStatus({required this.appModel});

  final ValueNotifier<bool> generatingBusy = ValueNotifier(false);
  final ValueNotifier<bool> hasResults = ValueNotifier(false);
  final ValueNotifier<String?> geminiError = ValueNotifier(null);

  String? userSource;
  String? proposedSource;
  bool closed = false;

  void generationProposal(String source) {
    if (closed) return;

    if (proposedSource == null) {
      userSource = appModel.sourceCodeController.text;
    }

    proposedSource = source;
    appModel.sourceCodeController.text = proposedSource!;

    hasResults.value = true;
  }

  void applyAccept(BuildContext context) {
    Navigator.pop(context, proposedSource!);

    closed = true;
  }

  void revertTempChanges() {
    if (proposedSource != null) {
      proposedSource = null;
      appModel.sourceCodeController.text = userSource!;
    }

    closed = true;
  }
}

class GeminiButton extends StatelessWidget {
  final bool smallIcon;

  const GeminiButton({this.smallIcon = false, super.key});

  @override
  Widget build(BuildContext context) {
    final appServices = Provider.of<AppServices>(context);

    if (smallIcon) {
      return IconButton(
        icon: const Logo(type: 'gemini'),
        onPressed: () => _showDialog(context, appServices),
      );
    } else {
      return TextButton.icon(
        icon: const Logo(type: 'gemini'),
        label: const Text('Gemini'),
        onPressed: () => _showDialog(context, appServices),
      );
    }
  }

  void _showDialog(BuildContext context, AppServices appServices) {
    final geminiStatus = GeminiStatus(appModel: appServices.appModel);

    final future = showDialog<String>(
      context: context,
      builder: (context) {
        return GeminiDialog(
          title: 'Gemini Prompt',
          appServices: appServices,
          status: geminiStatus,
        );
      },
    );

    future.then((String? result) {
      if (result == null) {
        geminiStatus.revertTempChanges();
      }
    });
  }
}

class GeminiDialog extends StatefulWidget {
  final String title;
  final AppServices appServices;
  final GeminiStatus status;

  const GeminiDialog({
    required this.title,
    required this.appServices,
    required this.status,
    super.key,
  });

  @override
  State<GeminiDialog> createState() => _GeminiDialogState();
}

class _GeminiDialogState extends State<GeminiDialog> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const width = 600.0;
      const height = 300.0;

      return PointerInterceptor(
        child: AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Text(widget.title),
          contentTextStyle: Theme.of(context).textTheme.bodyMedium,
          contentPadding: const EdgeInsets.fromLTRB(24, defaultSpacing, 24, 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: width,
                height: height,
                child: ClipRect(child: _contents(context)),
              ),
              const Divider(),
            ],
          ),
          actions: <Widget>[
            ValueListenableBuilder(
              valueListenable: widget.status.generatingBusy,
              builder: (context, busy, _) {
                return TextButton.icon(
                  onPressed: busy ? null : _generate,
                  label: const Text('Generate'),
                );
              },
            ),
            const SizedBox(
              height: smallIconSize,
              child: VerticalDivider(),
            ),
            ValueListenableBuilder(
              valueListenable: widget.status.hasResults,
              builder: (context, hasResults, _) {
                return TextButton.icon(
                  onPressed: hasResults
                      ? () => widget.status.applyAccept(context)
                      : null,
                  label: const Text('Accept'),
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    });
  }

  Widget _contents(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Row(
          children: [
            const Text('Create a new snippet using Gemini.'),
            const Expanded(child: SizedBox()),
            ValueListenableBuilder(
              valueListenable: widget.status.generatingBusy,
              builder: (context, busy, _) {
                return SizedBox(
                  height: defaultSpacing,
                  width: defaultSpacing,
                  child: busy
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const SizedBox(),
                );
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        const Divider(),
        const SizedBox(height: denseSpacing),
        Expanded(
          child: TextField(
            controller: widget.appServices.appModel.geminiPrompt,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
      ],
    );
  }

  void _generate() {
    final text = widget.appServices.appModel.geminiPrompt.text;

    final request = GeminiRequest(
      source: createSnippetPrompt(text),
      tidySourceResponse: true,
    );

    widget.status.generatingBusy.value = true;
    widget.status.geminiError.value = null;

    widget.appServices.gemini(request).then((GeminiResponse response) {
      if (mounted) {
        widget.status.generationProposal(response.response);
      }
    }).catchError((Object e) {
      if (mounted) {
        widget.status.geminiError.value = 'Error: $e';
      }
    }).whenComplete(() {
      widget.status.generatingBusy.value = false;
    });
  }
}

String createSnippetPrompt(String userText) {
  final prompt = '''
You are a software engineer and an expert in writing Dart and Flutter code.
Given the following prompt from a user, return the source code for either
a Dart or Flutter app.

The source must run.
The source must not contain any static analysis errors.
Return only source code - no other text. You may include helpful comments as
necessary.
Prefer shorter examples.

User prompt follows:

$userText
''';

  return prompt;
}

// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_shared/model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import 'editor/editor.dart';
import 'enable_gen_ai.dart';
import 'local_storage/local_storage.dart';
import 'model.dart';
import 'simple_widgets.dart';
import 'theme.dart';
import 'utils.dart';

Future<void> openCodeGenerationDialog(
  BuildContext context,
  AppType? appType,
) async {
  final appModel = Provider.of<AppModel>(context, listen: false);
  final appServices = Provider.of<AppServices>(context, listen: false);
  final lastPrompt = DartPadLocalStorage.instance.getLastCreateCodePrompt();
  final promptResponse = await showDialog<PromptDialogResponse>(
    context: context,
    builder:
        (context) => PromptDialog(
          title: 'Generate new code',
          hint: 'Describe the code you want to generate',
          initialAppType:
              appType ??
              DartPadLocalStorage.instance.getLastCreateCodeAppType(),
          flutterPromptButtons: {
            'to-do app':
                'Generate a Flutter to-do app with add, remove, and complete task functionality',
            'login screen':
                'Generate a Flutter login screen with email and password fields, validation, and a submit button',
            'tic-tac-toe':
                'Generate a Flutter tic-tac-toe game with two players, win detection, and a reset button',
            if (lastPrompt != null) 'your last prompt': lastPrompt,
          },
          dartPromptButtons: {
            'hello, world': 'Generate a Dart hello world program',
            'fibonacci':
                'Generate a Dart program that prints the first 10 numbers in the Fibonacci sequence',
            'factorial':
                'Generate a Dart program that prints the factorial of 5',
            if (lastPrompt != null) 'your last prompt': lastPrompt,
          },
        ),
  );

  if (!context.mounted ||
      promptResponse == null ||
      promptResponse.prompt.isEmpty) {
    return;
  }

  DartPadLocalStorage.instance.saveLastCreateCodeAppType(
    promptResponse.appType,
  );
  DartPadLocalStorage.instance.saveLastCreateCodePrompt(promptResponse.prompt);

  try {
    final Stream<String> stream;
    if (useGenUI) {
      stream = appServices.generateUi(
        GenerateUiRequest(prompt: promptResponse.prompt),
      );
    } else {
      stream = appServices.generateCode(
        GenerateCodeRequest(
          appType: promptResponse.appType,
          prompt: promptResponse.prompt,
          attachments: promptResponse.attachments,
        ),
      );
    }

    final generateResponse = await showDialog<String>(
      context: context,
      builder:
          (context) => GeneratingCodeDialog(
            stream: stream,
            title: 'Generating new code',
          ),
    );

    if (!context.mounted ||
        generateResponse == null ||
        generateResponse.isEmpty) {
      return;
    }

    appModel.sourceCodeController.textNoScroll = generateResponse;
    appServices.editorService!.focus();
    appServices.performCompileAndReloadOrRun();
  } catch (error) {
    appModel.editorStatus.showToast('Error generating code');
    appModel.appendError('Generating code issue: $error');
  }
}

class PromptDialog extends StatefulWidget {
  const PromptDialog({
    required this.title,
    required this.hint,
    required this.flutterPromptButtons,
    required this.dartPromptButtons,
    required this.initialAppType,
    super.key,
  });

  final String title;
  final String hint;
  final Map<String, String> flutterPromptButtons;
  final Map<String, String> dartPromptButtons;
  final AppType initialAppType;

  @override
  State<PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<PromptDialog> {
  final _controller = TextEditingController();
  final _attachments = List<Attachment>.empty(growable: true);
  final _focusNode = FocusNode();
  late AppType _appType;

  @override
  void initState() {
    super.initState();
    _appType = widget.initialAppType;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PointerInterceptor(
      child: AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        title: Text(widget.title),
        contentTextStyle: theme.textTheme.bodyMedium,
        contentPadding: const EdgeInsets.fromLTRB(24, defaultSpacing, 24, 8),
        content: SizedBox(
          width: 700,
          child: CallbackShortcuts(
            bindings: {
              SingleActivator(
                LogicalKeyboardKey.enter,
                meta: isMac,
                control: isNonMac,
              ): () {
                if (_controller.text.isNotEmpty) _onGenerate();
              },
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OverflowBar(
                        spacing: 8,
                        alignment: MainAxisAlignment.start,
                        children: [
                          for (final entry
                              in _appType == AppType.flutter
                                  ? widget.flutterPromptButtons.entries
                                  : widget.dartPromptButtons.entries)
                            TextButton(
                              onPressed: () {
                                _controller.text = entry.value;
                                _focusNode.requestFocus();
                              },
                              child: Text(entry.key),
                            ),
                        ],
                      ),
                    ),
                    SegmentedButton<AppType>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment<AppType>(
                          value: AppType.dart,
                          label: Text('Dart'),
                          tooltip: 'Generate Dart code',
                        ),
                        ButtonSegment<AppType>(
                          value: AppType.flutter,
                          label: Text('Flutter'),
                          tooltip: 'Generate Flutter code',
                        ),
                      ],
                      selected: {_appType},
                      onSelectionChanged: (selected) {
                        setState(() => _appType = selected.first);
                        _focusNode.requestFocus();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: widget.hint,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 128,
                  child: EditableImageList(
                    attachments: _attachments,
                    onRemove: _removeAttachment,
                    onAdd: _addAttachment,
                    maxAttachments: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ValueListenableBuilder(
            valueListenable: _controller,
            builder:
                (context, controller, _) => TextButton(
                  onPressed: controller.text.isEmpty ? null : _onGenerate,
                  child: Text(
                    'Generate',
                    style: TextStyle(
                      color:
                          controller.text.isEmpty ? theme.disabledColor : null,
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  void _onGenerate() {
    assert(_controller.text.isNotEmpty);
    Navigator.pop(
      context,
      PromptDialogResponse(
        appType: _appType,
        prompt: _controller.text,
        attachments: _attachments,
      ),
    );
  }

  void _removeAttachment(int index) =>
      setState(() => _attachments.removeAt(index));

  Future<void> _addAttachment() async {
    final pic = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pic == null) return;

    final bytes = await pic.readAsBytes();
    setState(
      () => _attachments.add(
        Attachment.fromBytes(
          name: pic.name,
          bytes: bytes,
          mimeType: pic.mimeType ?? lookupMimeType(pic.name) ?? 'image',
        ),
      ),
    );
  }
}

class GeneratingCodeDialog extends StatefulWidget {
  const GeneratingCodeDialog({
    required this.stream,
    required this.title,
    this.existingSource,
    super.key,
  });

  final Stream<String> stream;
  final String title;
  final String? existingSource;
  @override
  State<GeneratingCodeDialog> createState() => _GeneratingCodeDialogState();
}

class _GeneratingCodeDialogState extends State<GeneratingCodeDialog> {
  final _generatedCode = StringBuffer();
  final _focusNode = FocusNode();
  bool _done = false;
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();

    _subscription = widget.stream.listen(
      (text) => setState(() => _generatedCode.write(text)),
      onDone:
          () => setState(() {
            final source = _generatedCode.toString().trim();
            _generatedCode.clear();
            _generatedCode.write(source);
            _done = true;
            _focusNode.requestFocus();
          }),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PointerInterceptor(
      child: CallbackShortcuts(
        bindings: {
          SingleActivator(
            LogicalKeyboardKey.enter,
            meta: isMac,
            control: isNonMac,
          ): () {
            if (_done) _onAcceptAndRun();
          },
        },
        child: AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: theme.colorScheme.outline),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.title),
              if (!_done) const CircularProgressIndicator(),
            ],
          ),
          contentTextStyle: theme.textTheme.bodyMedium,
          contentPadding: const EdgeInsets.fromLTRB(24, defaultSpacing, 24, 8),
          content: SizedBox(
            width: 700,
            child: Focus(
              autofocus: true,
              focusNode: _focusNode,
              child:
                  widget.existingSource == null
                      ? ReadOnlyCodeWidget(_generatedCode.toString())
                      : ReadOnlyDiffWidget(
                        existingSource: widget.existingSource!,
                        newSource: _generatedCode.toString(),
                      ),
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: RichText(
                      text: TextSpan(
                        text: 'Powered by ',
                        style: DefaultTextStyle.of(context).style,
                        children: [
                          TextSpan(
                            text: 'Google AI',
                            style: TextStyle(color: theme.colorScheme.primary),
                            recognizer:
                                TapGestureRecognizer()
                                  ..onTap = () {
                                    url_launcher.launchUrl(
                                      Uri.parse('https://ai.google.dev/'),
                                    );
                                  },
                          ),
                          TextSpan(
                            text: ' and the Gemini API',
                            style: DefaultTextStyle.of(context).style,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _done ? _onAcceptAndRun : null,
                  child: Text(
                    'Accept',
                    style: TextStyle(
                      color: !_done ? theme.disabledColor : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onAcceptAndRun() {
    assert(_done);
    Navigator.pop(context, _generatedCode.toString());
  }
}

// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_shared/services.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../docs.dart';
import '../model.dart';
import '../problems.dart';
import '../prompt_dialog.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

import 'editor.dart';
import 'generating_panel.dart';

class EditorWithButtons extends StatelessWidget {
  const EditorWithButtons({
    super.key,
    required this.appModel,
    required this.appServices,
    required this.onFormat,
    required this.onCompileAndRun,
    required this.onCompileAndReload,
  });

  final AppModel appModel;
  final AppServices appServices;
  final VoidCallback onFormat;
  final VoidCallback onCompileAndRun;
  final VoidCallback onCompileAndReload;

  Future<void> _requestGeminiCodeUpdate(
    BuildContext context,
    PromptDialogResponse promptInfo,
  ) async {
    appModel.genAiManager.preGenAiSourceCode.value =
        appModel.sourceCodeController.text;
    appModel.genAiManager.enterGeneratingEdit();
    try {
      final source = appModel.sourceCodeController.text;
      appModel.genAiManager.startStream(
        appServices.updateCode(
          UpdateCodeRequest(
            appType: promptInfo.appType,
            source: source,
            prompt: promptInfo.prompt,
            attachments: promptInfo.attachments,
          ),
        ),
      );
    } catch (error) {
      appModel.editorStatus.showToast('Error updating code');
      appModel.appendError('Updating code issue: $error');
      appModel.genAiManager.enterStandby();
    }
  }

  void _handleAcceptUpdateCode() {
    assert(appModel.genAiManager.streamIsDone.value);
    appModel.genAiManager.resetInputs();
    appModel.genAiManager.enterStandby();
  }

  void _handleEditUpdateCodePrompt(BuildContext context) async {
    appModel.sourceCodeController.textNoScroll =
        appModel.genAiManager.preGenAiSourceCode.value;
    appServices.performCompileAndReloadOrRun();
    appModel.genAiManager.enterStandby();
    openCodeGenerationDialog(context, changeLastPrompt: true);
  }

  void _handleCancelUpdateCode() {
    appModel.genAiManager.resetInputs();
    appModel.genAiManager.enterStandby();
  }

  void _handleRejectSuggestedCode() {
    appModel.genAiManager.resetInputs();
    appModel.genAiManager.enterStandby();
    appModel.sourceCodeController.textNoScroll =
        appModel.genAiManager.preGenAiSourceCode.value;
    appServices.performCompileAndReloadOrRun();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GenAiState>(
      valueListenable: appModel.genAiManager.currentState,
      builder: (BuildContext context, GenAiState genAiState, Widget? child) {
        return Column(
          children: [
            Expanded(
              child: SectionWidget(
                child: Stack(
                  children: [
                    if (genAiState == GenAiState.standby) ...[
                      EditorWidget(
                        appModel: appModel,
                        appServices: appServices,
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: denseSpacing,
                        horizontal: defaultSpacing,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        // We use explicit directionality here in order to have the
                        // format and run buttons on the right hand side of the
                        // editing area.
                        textDirection: TextDirection.ltr,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dartdoc help button
                          ValueListenableBuilder<bool>(
                            valueListenable: appModel.docHelpBusy,
                            builder: (_, bool value, __) {
                              return PointerInterceptor(
                                child: MiniIconButton(
                                  icon: const Icon(Icons.help_outline),
                                  tooltip: 'Show docs',
                                  // small: true,
                                  onPressed:
                                      value ? null : () => _showDocs(context),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: denseSpacing),
                          // Format action
                          ValueListenableBuilder<bool>(
                            valueListenable: appModel.formattingBusy,
                            builder: (_, bool value, __) {
                              return PointerInterceptor(
                                child: MiniIconButton(
                                  icon: const Icon(Icons.format_align_left),
                                  tooltip: 'Format',
                                  small: true,
                                  onPressed: value ? null : onFormat,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: defaultSpacing),
                          // Run action
                          ValueListenableBuilder(
                            valueListenable: appModel.showReload,
                            builder: (_, bool value, __) {
                              if (!value) return const SizedBox();
                              return ValueListenableBuilder<bool>(
                                valueListenable: appModel.canReload,
                                builder: (_, bool value, __) {
                                  return PointerInterceptor(
                                    child: ReloadButton(
                                      onPressed:
                                          value ? onCompileAndReload : null,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(width: defaultSpacing),
                          // Run action
                          ValueListenableBuilder<CompilingState>(
                            valueListenable: appModel.compilingState,
                            builder: (_, compiling, __) {
                              return PointerInterceptor(
                                child: RunButton(
                                  onPressed:
                                      compiling.busy ? null : onCompileAndRun,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Container(
                      alignment: Alignment.bottomRight,
                      padding: const EdgeInsets.all(denseSpacing),
                      child: StatusWidget(status: appModel.editorStatus),
                    ),

                    if (genAiState == GenAiState.standby) ...[
                      SizedBox(width: 0, height: 0),
                    ] else ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                        ),
                        alignment: Alignment.topLeft,
                        padding: const EdgeInsets.all(denseSpacing),
                        child: GeneratingCodePanel(
                          appModel: appModel,
                          appServices: appServices,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            GeminiCodeEditTool(
              appModel: appModel,
              enabled: appModel.genAiManager.state.value == GenAiState.standby,
              onUpdateCode: _requestGeminiCodeUpdate,
              onAcceptUpdateCode: _handleAcceptUpdateCode,
              onCancelUpdateCode: _handleCancelUpdateCode,
              onEditUpdateCodePrompt: _handleEditUpdateCodePrompt,
              onRejectSuggestedCode: _handleRejectSuggestedCode,
            ),
            MultiValueListenableBuilder(
              listenables: [
                appModel.analysisIssues,
                appModel.genAiManager.state,
              ],
              builder: (_) {
                if (genAiState != GenAiState.awaitingAcceptReject &&
                    genAiState != GenAiState.generating) {
                  return ProblemsTableWidget(
                    problems: appModel.analysisIssues.value,
                  );
                }
                return SizedBox(width: 0, height: 0);
              },
            ),
          ],
        );
      },
    );
  }

  static final RegExp identifierChar = RegExp(r'[\w\d_<=>]');

  void _showDocs(BuildContext context) async {
    try {
      final source = appModel.sourceCodeController.text;
      final offset = appServices.editorService?.cursorOffset ?? -1;

      var valid = true;
      if (offset < 0 || offset >= source.length) {
        valid = false;
      } else {
        valid = identifierChar.hasMatch(source.substring(offset, offset + 1));
      }

      if (!valid) {
        appModel.editorStatus.showToast('No docs at location.');
        return;
      }

      final result = await appServices.document(
        SourceRequest(source: source, offset: offset),
      );

      if (result.elementKind == null) {
        appModel.editorStatus.showToast('No docs at location.');
        return;
      } else if (context.mounted) {
        // show result

        showDialog<void>(
          context: context,
          builder: (context) {
            const longTitle = 40;

            var title = result.cleanedUpTitle ?? 'Dartdoc';
            if (title.length > longTitle) {
              title = '${title.substring(0, longTitle)}…';
            }
            return MediumDialog(
              title: title,
              child: DocsWidget(appModel: appModel, documentResponse: result),
            );
          },
        );
      }

      appServices.editorService!.focus();
    } catch (error) {
      appModel.editorStatus.showToast('Error retrieving docs');
      appModel.appendError('$error');
      return;
    }
  }
}

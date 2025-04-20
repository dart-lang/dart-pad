// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/model.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'docs.dart';
import 'editor/_web/editor.dart';
import 'model.dart';
import 'problems.dart';
import 'simple_widgets.dart';
import 'theme.dart';

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SectionWidget(
            child: Stack(
              children: [
                EditorWidget(appModel: appModel, appServices: appServices),
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
                                  onPressed: value ? onCompileAndReload : null,
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
              ],
            ),
          ),
        ),
        ValueListenableBuilder<List<AnalysisIssue>>(
          valueListenable: appModel.analysisIssues,
          builder: (context, issues, _) {
            return ProblemsTableWidget(problems: issues);
          },
        ),
      ],
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

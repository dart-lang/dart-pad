// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';
import '../../bottom_panel/views/console_panel.dart';
import '../../shared/components/button_group.dart';
import '../../shared/components/task_status_indicator.dart';
import '../../shared/node_container.dart';
import '../../shared/task_status.dart';
import '../components/runtime_button.dart';
import '../models/preview_state.dart';
import '../view_models/preview_view_model.dart';

/// A container component that hosts the preview toolbar, task status, and the
/// sandbox node where the compiled application runs.
class PreviewContainer extends StatefulComponent {
  const PreviewContainer({
    required this.preview,
    required this.taskStatus,
    required this.activeFile,
    required this.onOpenConsole,
    this.workspacePreparationFailure,
    super.key,
  });

  /// The view model that manages compilation and run operations for the preview.
  final PreviewViewModel preview;

  /// Tracks prerequisite and runtime tasks shown in an empty preview.
  final TaskStatusController taskStatus;

  /// The path of the currently active file in the editor workspace.
  final String activeFile;

  /// A persistent failure from the one-time workspace preparation lifecycle.
  final String? workspacePreparationFailure;

  /// Opens the workspace Console tab.
  final void Function() onOpenConsole;

  @override
  State<PreviewContainer> createState() => _PreviewContainerState();

  @css
  static List<StyleRule> get styles => _PreviewContainerState.styles;
}

class _PreviewContainerState extends State<PreviewContainer> {
  @override
  Component build(BuildContext context) {
    final viewModel = component.preview;
    final state = viewModel.state;
    final isRunning = viewModel.isRunning;

    final previewFailure = state is PreviewCompileError ? state : null;
    final failureKind =
        previewFailure?.failedTask ??
        (component.workspacePreparationFailure == null ? null : TaskKind.preparingWorkspace);
    final failureMessage = previewFailure?.message ?? component.workspacePreparationFailure;
    final taskStatusMode = switch (state) {
      PreviewInitial() => PreviewTaskStatusMode.workspacePreparation,
      PreviewStarting() => PreviewTaskStatusMode.startup,
      PreviewRestarting() => PreviewTaskStatusMode.restart,
      PreviewCompileError(:final action) => switch (action) {
        PreviewLaunchAction.start => PreviewTaskStatusMode.startup,
        PreviewLaunchAction.restart => PreviewTaskStatusMode.restart,
      },
      _ => null,
    };

    return div(classes: 'preview-container', [
      div(classes: 'preview-toolbar', [
        div(classes: 'preview-controls', [
          ListenableBuilder(
            listenable: component.taskStatus,
            builder: (context) => ButtonGroup(
              children: [
                if (isRunning)
                  RuntimeButton.restart(previewViewModel: viewModel)
                else
                  RuntimeButton.start(
                    previewViewModel: viewModel,
                    activeFile: component.activeFile,
                  ),
                RuntimeButton.hotReload(previewViewModel: viewModel),
                RuntimeButton.stop(previewViewModel: viewModel),
              ],
            ),
          ),
        ]),
      ]),
      div(
        classes: 'preview-content ${!isRunning ? 'status-stopped' : ''} ${!viewModel.isFlutter ? 'is-dart' : ''}',
        [
          NodeContainer(viewModel.containerElement),
          if (taskStatusMode != null)
            PreviewTaskStatus(
              controller: component.taskStatus,
              mode: taskStatusMode,
              persistentFailureKind: failureKind,
              persistentFailureMessage: failureMessage,
              onOpenConsole: component.onOpenConsole,
            ),
          if (isRunning && !viewModel.isFlutter) ConsolePanel(logs: viewModel.appLogs),
        ],
      ),
    ]);
  }

  static List<StyleRule> get styles => [
    ...PreviewTaskStatus.styles,
    css('.preview-container', [
      css('&').styles(
        display: .flex,
        position: const .relative(),
        overflow: .hidden,
        flexDirection: .column,
        flex: const .grow(1),
        backgroundColor: colorContainer,
      ),
      css('.active-icon-btn').styles(
        color: colorOnPrimary,
        backgroundColor: colorPrimary,
      ),
      css('.active-icon-btn:not(.disabled):hover').styles(
        backgroundColor: colorPrimary,
      ),
      css('.preview-toolbar', [
        css('&').styles(
          display: .flex,
          padding: .symmetric(vertical: 4.px, horizontal: 12.px),
          border: .only(
            bottom: .solid(color: colorBorder, width: 1.px),
          ),
          justifyContent: .spaceBetween,
          alignItems: .center,
          flex: const .shrink(0),
          backgroundColor: colorSurface,
        ),
        css('.preview-controls').styles(
          display: .flex,
          alignItems: .center,
          flex: const .grow(1),
          raw: {'flex-basis': '0%'},
        ),
      ]),
      css('.preview-content', [
        css('&').styles(
          display: .flex,
          position: const .relative(),
          padding: Padding.zero,
          boxSizing: .borderBox,
          justifyContent: .center,
          alignItems: .center,
          flex: const .grow(1),
        ),
        css('& .preview, & iframe').styles(
          width: 100.percent,
          height: 100.percent,
          border: .none,
        ),
        css('&.status-stopped > .preview').styles(
          visibility: .hidden,
        ),
        css('&.is-dart > .preview').styles(
          position: const .absolute(),
          width: .zero,
          height: .zero,
          visibility: .hidden,
        ),
        css('&.is-dart > .console-panel').styles(
          width: 100.percent,
          height: 100.percent,
        ),
        css('& > .preview').styles(
          width: 100.percent,
          height: 100.percent,
          border: .none,
          radius: .circular(0.px),
          shadow: .none,
        ),
      ]),
    ]),
  ];
}

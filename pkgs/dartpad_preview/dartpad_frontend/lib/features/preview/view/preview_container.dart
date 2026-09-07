// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_interop';
import 'dart:math';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../../bottom_panel/views/console_panel.dart';
import '../../shared/components/button_group.dart';
import '../../shared/components/icon_button.dart';
import '../../shared/components/task_status_indicator.dart';
import '../../shared/node_container.dart';
import '../../shared/task_status.dart';
import '../components/device_mode_dropdown.dart';
import '../components/runtime_button.dart';
import '../models/device_mode.dart';
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
  final GlobalNodeKey<web.HTMLElement> _contentKey = GlobalNodeKey();
  web.ResizeObserver? _resizeObserver;

  DeviceMode mode = .mobile;
  bool isRotated = false;

  @override
  void initState() {
    super.initState();
    context.binding.addPostFrameCallback(_setupObserver);
  }

  void _setupObserver() {
    if (!mounted || _resizeObserver != null) {
      return;
    }
    final element = _contentKey.currentNode;
    if (element != null) {
      _resizeObserver = web.ResizeObserver(
        (JSArray<web.ResizeObserverEntry> entries, web.ResizeObserver observer) {
          _updateScale();
        }.toJS,
      );
      _resizeObserver!.observe(element);
      _updateScale();
    }
  }

  void _updateScale() {
    final element = _contentKey.currentNode;
    if (element == null) {
      return;
    }

    final size = mode.size;

    if (size == null) {
      element.style.removeProperty('--device-width');
      element.style.removeProperty('--device-height');
      element.style.removeProperty('--device-scale');
      return;
    }

    final baseW = size.$1;
    final baseH = size.$2;
    final deviceW = isRotated ? baseH : baseW;
    final deviceH = isRotated ? baseW : baseH;

    final parentRect = element.getBoundingClientRect();
    final availableW = parentRect.width - 32;
    final availableH = parentRect.height - 32;

    if (availableW <= 0 || availableH <= 0) {
      return;
    }

    final scaleW = availableW / deviceW;
    final scaleH = availableH / deviceH;
    final newScale = min(1.0, scaleW < scaleH ? scaleW : scaleH);

    element.style.setProperty('--device-width', '${deviceW}px');
    element.style.setProperty('--device-height', '${deviceH}px');
    element.style.setProperty('--device-scale', newScale.toStringAsFixed(4));
  }

  @override
  void dispose() {
    _resizeObserver?.disconnect();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    context.binding.addPostFrameCallback(_updateScale);

    final viewModel = component.preview;
    final state = viewModel.state;
    final isRunning = viewModel.isRunning;

    final previewFailure = state is PreviewCompileError ? state : null;
    final failureKind = previewFailure?.failedTask;
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
          if (viewModel.isFlutter)
            ButtonGroup(
              children: [
                DeviceModeDropdown(
                  mode: mode,
                  disabled: !isRunning,
                  onModeSelected: (m) {
                    setState(() {
                      mode = m;
                      isRotated = false;
                    });
                    context.binding.addPostFrameCallback(_updateScale);
                  },
                ),
                if (mode.size != null)
                  IconButton(
                    icon: 'screen_rotation',
                    tooltip: 'Rotate orientation',
                    disabled: !isRunning,
                    onClick: (_) {
                      setState(() => isRotated = !isRotated);
                      context.binding.addPostFrameCallback(_updateScale);
                    },
                  ),
              ],
            ),
        ]),
      ]),
      div(
        key: _contentKey,
        classes: [
          'preview-content',
          'mode-${mode.name}',
          if (!isRunning) 'status-stopped',
          if (!viewModel.isFlutter) 'is-dart',
        ].join(' '),
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
          flexWrap: .wrap,
          justifyContent: .center,
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
        css('&.mode-mobile, &.mode-tablet').styles(
          padding: Padding.all(16.px),
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
        css('&.mode-current > .preview').styles(
          width: 100.percent,
          height: 100.percent,
          border: .none,
          radius: .circular(0.px),
          shadow: .none,
        ),
        css('&.mode-mobile > .preview').styles(
          position: .absolute(top: 50.percent, left: 50.percent),
          border: .all(color: colorBorder, width: 1.px),
          radius: .circular(12.px),
          overflow: .hidden,
          shadow: BoxShadow(
            offsetX: 0.px,
            offsetY: 8.px,
            blur: 24.px,
            color: Colors.black.withOpacity(0.4),
          ),
          backgroundColor: Colors.white,
          raw: {
            'width': 'var(--device-width, 390px)',
            'height': 'var(--device-height, 846px)',
            'transform': 'translate(-50%, -50%) scale(var(--device-scale, 1))',
            'transform-origin': 'center center',
          },
        ),
        css('&.mode-tablet > .preview').styles(
          position: .absolute(top: 50.percent, left: 50.percent),
          border: .all(color: colorBorder, width: 1.px),
          radius: .circular(12.px),
          overflow: .hidden,
          shadow: BoxShadow(
            offsetX: 0.px,
            offsetY: 8.px,
            blur: 24.px,
            color: Colors.black.withOpacity(0.4),
          ),
          backgroundColor: Colors.white,
          raw: {
            'width': 'var(--device-width, 760px)',
            'height': 'var(--device-height, 576px)',
            'transform': 'translate(-50%, -50%) scale(var(--device-scale, 1))',
            'transform-origin': 'center center',
          },
        ),
      ]),
    ]),
  ];
}

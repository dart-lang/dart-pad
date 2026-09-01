// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../analyzer_status.dart';
import '../icons.dart';
import '../task_status.dart';

/// Compact footer status with a detailed recent-task popover.
final class TaskStatusIndicator extends StatefulComponent {
  const TaskStatusIndicator({required this.controller, super.key});

  final TaskStatusController controller;

  @override
  State<TaskStatusIndicator> createState() => _TaskStatusIndicatorState();

  @css
  static List<StyleRule> get styles => _TaskStatusIndicatorState.styles;
}

class _TaskStatusIndicatorState extends State<TaskStatusIndicator> {
  final GlobalNodeKey<web.HTMLElement> _anchorKey = GlobalNodeKey();
  StreamSubscription<web.KeyboardEvent>? _keySubscription;
  StreamSubscription<web.MouseEvent>? _mouseSubscription;
  Timer? _ticker;
  bool _hovered = false;
  bool _focused = false;
  bool _pinned = false;
  bool _forceClosed = false;

  bool get _showPopover =>
      component.controller.entries.isNotEmpty && !_forceClosed && (_hovered || _focused || _pinned);

  @override
  void initState() {
    super.initState();
    component.controller.addListener(_onTasksChanged);
    _keySubscription = web.EventStreamProviders.keyDownEvent.forTarget(web.document).listen(_onKeyDown);
    _mouseSubscription = web.EventStreamProviders.mouseDownEvent.forTarget(web.document).listen(_onMouseDown);
    _syncTicker();
  }

  @override
  void didUpdateComponent(TaskStatusIndicator oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(oldComponent.controller, component.controller)) {
      oldComponent.controller.removeListener(_onTasksChanged);
      component.controller.addListener(_onTasksChanged);
      _syncTicker();
    }
  }

  void _onTasksChanged() {
    if (!mounted) {
      return;
    }
    _syncTicker();
    setState(() {});
  }

  void _syncTicker() {
    final needsTicker = component.controller.entries.any((entry) => entry.isRunning);
    if (!needsTicker) {
      _ticker?.cancel();
      _ticker = null;
    } else {
      _ticker ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _onKeyDown(web.KeyboardEvent event) {
    if (!mounted || event.key != 'Escape' || !_showPopover) {
      return;
    }
    event.preventDefault();
    setState(() {
      _pinned = false;
      _forceClosed = true;
    });
  }

  void _onMouseDown(web.MouseEvent event) {
    if (!mounted || !_pinned) {
      return;
    }
    final anchor = _anchorKey.currentNode;
    final target = event.target as web.Node?;
    if (anchor != null && target != null && !anchor.contains(target)) {
      setState(() {
        _pinned = false;
        _forceClosed = true;
      });
    }
  }

  void _onFocusOut(web.Event event) {
    if (!mounted) {
      return;
    }
    final anchor = _anchorKey.currentNode;
    final relatedTarget = (event as web.FocusEvent).relatedTarget as web.Node?;
    if (anchor == null || relatedTarget == null || !anchor.contains(relatedTarget)) {
      setState(() {
        _focused = false;
        if (!_pinned) {
          _forceClosed = false;
        }
      });
    }
  }

  @override
  void dispose() {
    component.controller.removeListener(_onTasksChanged);
    _keySubscription?.cancel();
    _mouseSubscription?.cancel();
    _ticker?.cancel();
    _keySubscription = null;
    _mouseSubscription = null;
    _ticker = null;
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final entries = component.controller.entries;
    final current = entries.firstOrNull;
    final now = DateTime.now();
    final label = current?.label ?? 'Ready';
    final duration = current == null ? null : formatTaskDuration(current.durationAt(now));

    return div(
      key: _anchorKey,
      classes: 'task-status-anchor',
      events: {
        'mouseenter': (_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _hovered = true;
            _forceClosed = false;
          });
        },
        'mouseleave': (_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _hovered = false;
            _forceClosed = false;
          });
        },
        'focusin': (_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _focused = true;
            _forceClosed = false;
          });
        },
        'focusout': _onFocusOut,
      },
      [
        button(
          classes: 'task-status-trigger${entries.isEmpty ? ' empty' : ''}',
          attributes: {
            'aria-label': current == null ? 'Task status: Ready' : 'Task status: $label, $duration',
            'aria-expanded': _showPopover.toString(),
            if (entries.isNotEmpty) 'aria-controls': 'task-status-popover',
          },
          onClick: () {
            if (!mounted || entries.isEmpty) {
              return;
            }
            setState(() {
              _pinned = !_pinned;
              _forceClosed = false;
            });
          },
          [
            _TaskStatusIcon(entry: current, size: 16),
            span(classes: 'task-status-label', [.text(label)]),
            if (duration != null)
              span(
                classes: 'task-status-duration',
                attributes: {'aria-hidden': 'true'},
                [.text(duration)],
              ),
          ],
        ),
        if (_showPopover)
          div(
            id: 'task-status-popover',
            classes: 'task-status-popover',
            attributes: {'role': 'dialog', 'aria-label': 'Recent tasks'},
            [
              const div(classes: 'task-status-popover-title', [.text('Recent tasks')]),
              table(classes: 'task-status-table', [
                tbody([
                  for (final entry in entries)
                    tr([
                      td(classes: 'task-status-cell-icon', [_TaskStatusIcon(entry: entry, size: 16)]),
                      td(classes: 'task-status-cell-name', [.text(entry.label)]),
                      td(
                        classes: 'task-status-cell-duration',
                        attributes: {'aria-label': formatTaskDuration(entry.durationAt(now))},
                        [.text(formatTaskDuration(entry.durationAt(now)))],
                      ),
                    ]),
                ]),
              ]),
            ],
          ),
      ],
    );
  }

  static List<StyleRule> get styles => [
    css.keyframes('task-status-spin', {
      '0%': Styles(transform: .rotate(0.deg)),
      '100%': Styles(transform: .rotate(360.deg)),
    }),
    css('.task-status-anchor').styles(
      position: const .relative(),
      minWidth: .zero,
    ),
    css('.task-status-trigger').styles(
      display: .flex,
      height: 28.px,
      maxWidth: 260.px,
      padding: .symmetric(horizontal: 8.px),
      border: .none,
      radius: .circular(4.px),
      outline: const Outline(style: .none),
      cursor: .pointer,
      alignItems: .center,
      gap: Gap.all(6.px),
      color: colorOnSurface,
      fontFamily: const .list([FontFamilies.sansSerif]),
      fontSize: 11.px,
      backgroundColor: Colors.transparent,
    ),
    css('.task-status-trigger:hover, .task-status-trigger:focus-visible').styles(
      backgroundColor: colorSurface.highlight(colorOnSurface, 0.1),
    ),
    css('.task-status-trigger.empty').styles(raw: {'cursor': 'default'}),
    css('.task-status-label').styles(
      minWidth: .zero,
      overflow: .hidden,
      textOverflow: .ellipsis,
      whiteSpace: .noWrap,
    ),
    css('.task-status-duration').styles(
      flex: const .shrink(0),
      color: colorOnContainer,
      raw: {'font-variant-numeric': 'tabular-nums'},
    ),
    css('.task-status-icon').styles(
      display: .flex,
      justifyContent: .center,
      alignItems: .center,
      flex: const .shrink(0),
    ),
    css('.task-status-icon.running').styles(
      width: 14.px,
      height: 14.px,
      border: .only(
        top: .solid(color: colorPrimary, width: 2.px),
        right: .solid(color: colorBorder, width: 2.px),
        bottom: .solid(color: colorBorder, width: 2.px),
        left: .solid(color: colorBorder, width: 2.px),
      ),
      radius: .circular(50.percent),
      animation: Animation(name: 'task-status-spin', duration: 1.seconds, curve: .linear, count: 10e6),
    ),
    css('.task-status-icon.succeeded').styles(color: colorSuccess),
    css('.task-status-icon.failed').styles(color: colorError),
    css('.task-status-popover').styles(
      position: .absolute(bottom: 100.percent, right: 0.px),
      zIndex: const ZIndex(100),
      minWidth: 320.px,
      maxWidth: 480.px,
      maxHeight: 320.px,
      padding: .all(8.px),
      margin: Margin.only(bottom: 4.px),
      border: .all(color: colorBorder, width: 1.px),
      radius: .circular(8.px),
      overflow: .auto,
      shadow: BoxShadow(
        offsetX: .zero,
        offsetY: (-4).px,
        blur: 12.px,
        color: const .rgba(0, 0, 0, 0.15),
      ),
      color: colorOnContainer,
      backgroundColor: colorContainer,
    ),
    css('.task-status-popover-title').styles(
      padding: .symmetric(horizontal: 8.px, vertical: 6.px),
      fontSize: 12.px,
      fontWeight: .w700,
    ),
    css('.task-status-table').styles(
      width: 100.percent,
      fontSize: 12.px,
      raw: {'border-collapse': 'collapse'},
    ),
    css('.task-status-table td').styles(
      padding: .symmetric(horizontal: 8.px, vertical: 6.px),
      border: .only(
        top: .solid(color: colorBorder, width: 1.px),
      ),
    ),
    css('.task-status-cell-icon').styles(width: 24.px),
    css('.task-status-cell-name').styles(
      maxWidth: 320.px,
      overflow: .hidden,
      textOverflow: .ellipsis,
      whiteSpace: .noWrap,
    ),
    css('.task-status-cell-duration').styles(
      textAlign: .right,
      whiteSpace: .noWrap,
      raw: {'font-variant-numeric': 'tabular-nums'},
    ),
    css.media(MediaQuery.screen(maxWidth: 700.px), [
      css('.task-status-popover').styles(
        position: .fixed(bottom: 38.px, left: 8.px, right: 8.px),
        minWidth: .zero,
        raw: {'max-width': 'none'},
      ),
    ]),
  ];
}

/// Stable analyzer readiness indicator with a non-timed update pulse.
final class AnalyzerStatusIndicator extends StatefulComponent {
  const AnalyzerStatusIndicator({required this.controller, super.key});

  final AnalyzerStatusController controller;

  @override
  State<AnalyzerStatusIndicator> createState() => _AnalyzerStatusIndicatorState();

  @css
  static List<StyleRule> get styles => _AnalyzerStatusIndicatorState.styles;
}

class _AnalyzerStatusIndicatorState extends State<AnalyzerStatusIndicator> {
  @override
  void initState() {
    super.initState();
    component.controller.addListener(_onStatusChanged);
  }

  @override
  void didUpdateComponent(AnalyzerStatusIndicator oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(oldComponent.controller, component.controller)) {
      oldComponent.controller.removeListener(_onStatusChanged);
      component.controller.addListener(_onStatusChanged);
    }
  }

  void _onStatusChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    component.controller.removeListener(_onStatusChanged);
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final phase = component.controller.phase;
    final unavailable = phase == AnalyzerStatusPhase.unavailable;
    final running = phase == AnalyzerStatusPhase.waiting || phase == AnalyzerStatusPhase.analyzing;

    return div(
      classes: 'analyzer-status ${phase.name}',
      attributes: {'aria-label': 'Analyzer: ${phase.name}'},
      [
        _TaskStatusIcon.outcome(
          outcome: running
              ? TaskStatusOutcome.running
              : unavailable
              ? TaskStatusOutcome.failed
              : TaskStatusOutcome.succeeded,
          size: 16,
        ),
        const span(classes: 'analyzer-status-label', [.text('Analyzer')]),
      ],
    );
  }

  static List<StyleRule> get styles => [
    css('.analyzer-status').styles(
      display: .flex,
      height: 28.px,
      minWidth: .zero,
      padding: .symmetric(horizontal: 6.px),
      alignItems: .center,
      gap: Gap.all(6.px),
      fontSize: 11.px,
      whiteSpace: .noWrap,
    ),
    css('.analyzer-status-label').styles(
      minWidth: .zero,
      overflow: .hidden,
      textOverflow: .ellipsis,
    ),
    css('.analyzer-status .task-status-icon.running').styles(
      width: 10.px,
      height: 10.px,
      border: .only(
        top: .solid(color: colorPrimary, width: 2.px),
        right: .solid(color: colorBorder, width: 2.px),
        bottom: .solid(color: colorBorder, width: 2.px),
        left: .solid(color: colorBorder, width: 2.px),
      ),
    ),
  ];
}

/// The exclusive task group shown in an empty preview panel.
enum PreviewTaskStatusMode { workspacePreparation, startup, restart }

/// A prominent status surface for the initial workspace and preview startup.
final class PreviewTaskStatus extends StatefulComponent {
  const PreviewTaskStatus({
    required this.controller,
    required this.mode,
    required this.onOpenConsole,
    this.persistentFailureKind,
    this.persistentFailureMessage,
    super.key,
  });

  final TaskStatusController controller;
  final PreviewTaskStatusMode mode;
  final void Function() onOpenConsole;
  final TaskKind? persistentFailureKind;
  final String? persistentFailureMessage;

  @override
  State<PreviewTaskStatus> createState() => _PreviewTaskStatusState();

  @css
  static List<StyleRule> get styles => _PreviewTaskStatusState.styles;
}

class _PreviewTaskStatusState extends State<PreviewTaskStatus> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    component.controller.addListener(_onTasksChanged);
    _syncTicker();
  }

  @override
  void didUpdateComponent(PreviewTaskStatus oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!identical(oldComponent.controller, component.controller)) {
      oldComponent.controller.removeListener(_onTasksChanged);
      component.controller.addListener(_onTasksChanged);
    }
    _syncTicker();
  }

  void _onTasksChanged() {
    if (mounted) {
      _syncTicker();
      setState(() {});
    }
  }

  TaskStatusEntry? get _visibleTask {
    final entries = component.controller.entries;
    final visibleKinds = switch (component.mode) {
      PreviewTaskStatusMode.workspacePreparation => const [
        TaskKind.initializingDartPadWorker,
        TaskKind.loadingCode,
        TaskKind.pubGet,
      ],
      PreviewTaskStatusMode.startup => const [
        TaskKind.compilingApplication,
        TaskKind.startingPreview,
      ],
      PreviewTaskStatusMode.restart => const [
        TaskKind.compilingApplication,
        TaskKind.restartingPreview,
      ],
    };
    for (final kind in visibleKinds) {
      final entry = entries
          .where((entry) => entry.kind == kind && entry.outcome != TaskStatusOutcome.succeeded)
          .firstOrNull;
      if (entry != null) {
        return entry;
      }
    }
    return null;
  }

  void _syncTicker() {
    if (_visibleTask?.isRunning ?? false) {
      _ticker ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) {
          setState(() {});
        }
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    component.controller.removeListener(_onTasksChanged);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final task = _visibleTask;
    final failureKind = component.persistentFailureKind;
    final failureMessage = component.persistentFailureMessage;
    if (task == null && failureKind == null && failureMessage == null) {
      return const div(classes: 'preview-task-status idle', [
        span(classes: 'preview-task-title', [
          .text('Start the preview when you’re ready.'),
        ]),
      ]);
    }

    final failed = failureKind != null || failureMessage != null || task?.outcome == TaskStatusOutcome.failed;
    final label = failureKind?.label ?? task?.label ?? 'Workspace preparation';
    final duration = task == null ? null : formatTaskDuration(task.durationAt(DateTime.now()));
    return div(
      classes: 'preview-task-status ${failed ? 'failed' : 'running'}',
      attributes: {
        'aria-label': failed ? '$label failed' : '$label running',
      },
      [
        _TaskStatusIcon.outcome(
          outcome: failed ? TaskStatusOutcome.failed : TaskStatusOutcome.running,
          size: 24,
        ),
        span(classes: 'preview-task-title', [.text(label)]),
        if (duration != null)
          span(
            classes: 'preview-task-duration',
            attributes: {'aria-hidden': 'true'},
            [.text(duration)],
          ),
        if (failed) ...[
          if (component.persistentFailureMessage case final String message when message.isNotEmpty)
            span(classes: 'preview-task-error', [.text(message)]),
          button(
            classes: 'preview-task-console-link',
            onClick: component.onOpenConsole,
            [const .text('Open Console')],
          ),
        ],
      ],
    );
  }

  static List<StyleRule> get styles => [
    css('.preview-task-status').styles(
      display: .flex,
      position: .absolute(top: 0.px, left: 0.px, right: 0.px, bottom: 0.px),
      zIndex: const ZIndex(5),
      padding: .all(24.px),
      flexDirection: .column,
      justifyContent: .center,
      alignItems: .center,
      gap: Gap.all(8.px),
      color: colorOnSurface,
      textAlign: .center,
      backgroundColor: colorContainer,
    ),
    css('.preview-task-status .task-status-icon.running').styles(
      width: 24.px,
      height: 24.px,
      border: .only(
        top: .solid(color: colorPrimary, width: 3.px),
        right: .solid(color: colorBorder, width: 3.px),
        bottom: .solid(color: colorBorder, width: 3.px),
        left: .solid(color: colorBorder, width: 3.px),
      ),
    ),
    css('.preview-task-title').styles(fontSize: 16.px, fontWeight: .w600),
    css('.preview-task-duration').styles(
      fontSize: 13.px,
      raw: {'font-variant-numeric': 'tabular-nums'},
    ),
    css('.preview-task-error').styles(
      maxWidth: 560.px,
      overflow: .hidden,
      color: colorOnSurface,
      fontSize: 13.px,
      raw: {
        'display': '-webkit-box',
        '-webkit-box-orient': 'vertical',
        '-webkit-line-clamp': '4',
        'white-space': 'pre-wrap',
      },
    ),
    css('.preview-task-console-link').styles(
      padding: .zero,
      border: .none,
      cursor: .pointer,
      color: colorPrimary,
      fontFamily: const .list([FontFamilies.sansSerif]),
      fontSize: 13.px,
      textDecoration: const TextDecoration(line: .underline),
      backgroundColor: Colors.transparent,
    ),
    css('.preview-task-status.failed .preview-task-title').styles(color: colorError),
  ];
}

final class _TaskStatusIcon extends StatelessComponent {
  _TaskStatusIcon({required TaskStatusEntry? entry, required this.size}) : outcome = entry?.outcome;

  const _TaskStatusIcon.outcome({required this.outcome, required this.size});

  final TaskStatusOutcome? outcome;
  final double size;

  @override
  Component build(BuildContext context) {
    return switch (outcome) {
      TaskStatusOutcome.running => const span(
        classes: 'task-status-icon running',
        attributes: {'aria-label': 'Running'},
        [],
      ),
      TaskStatusOutcome.failed => span(
        classes: 'task-status-icon failed',
        attributes: {
          'aria-label': 'Failed',
          'title': "See 'Console' for details",
        },
        [Icon('close', size: size)],
      ),
      TaskStatusOutcome.succeeded || null => span(
        classes: 'task-status-icon succeeded',
        attributes: {'aria-label': 'Succeeded'},
        [Icon('check', size: size)],
      ),
    };
  }
}

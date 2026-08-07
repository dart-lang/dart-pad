// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';

import 'package:codemirror_dart/codemirror_dart.dart' show LSPCodeAction;
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';

/// Displays the quick fixes returned for the current diagnostic or selection.
final class CodeActionPanel extends StatefulComponent {
  const CodeActionPanel({required this.controller, super.key});

  final CodeActionsController controller;

  @override
  State<CodeActionPanel> createState() => _CodeActionPanelState();

  @css
  static List<StyleRule> get styles => _CodeActionPanelState.styles;
}

final class _CodeActionPanelState extends State<CodeActionPanel> {
  final GlobalNodeKey _panelKey = GlobalNodeKey();
  StreamSubscription<web.MouseEvent>? _clickSubscription;
  List<LSPCodeAction>? _focusedActions;

  @override
  void initState() {
    super.initState();
    Timer.run(() {
      if (!mounted) {
        return;
      }
      _clickSubscription = web.EventStreamProviders.mouseDownEvent.forTarget(web.document).listen((event) {
        final panel = _panelKey.currentNode;
        final target = event.target as web.Node?;
        if (panel != null && target != null && !panel.contains(target)) {
          component.controller.hideCodeActionPanel();
        }
      });
      _focusFirstAction();
      _adjustPosition();
    });
  }

  @override
  void didUpdateComponent(CodeActionPanel oldComponent) {
    super.didUpdateComponent(oldComponent);
    Timer.run(() {
      _focusFirstAction();
      _adjustPosition();
    });
  }

  @override
  void dispose() {
    unawaited(_clickSubscription?.cancel());
    super.dispose();
  }

  void _adjustPosition() {
    if (!mounted) {
      return;
    }
    final panel = _panelKey.currentNode as web.HTMLElement?;
    if (panel == null) {
      return;
    }

    final rect = panel.getBoundingClientRect();
    final panelHeight = rect.height;
    final panelWidth = rect.width;
    final viewportHeight = web.window.innerHeight;
    final viewportWidth = web.window.innerWidth;

    final anchorTop = component.controller.anchorTop != 0
        ? component.controller.anchorTop
        : component.controller.panelTop;
    final anchorBottom = component.controller.anchorBottom != 0
        ? component.controller.anchorBottom
        : component.controller.panelTop;
    final anchorLeft = component.controller.panelLeft;

    const margin = 8.0;
    final spaceBelow = viewportHeight - anchorBottom - margin;
    final spaceAbove = anchorTop - margin;

    double top;
    if (anchorBottom + panelHeight > viewportHeight - margin && spaceAbove > spaceBelow) {
      top = (anchorTop - panelHeight).clamp(
        margin,
        (viewportHeight - panelHeight - margin).clamp(margin, viewportHeight.toDouble()),
      );
    } else {
      top = anchorBottom.clamp(
        margin,
        (viewportHeight - panelHeight - margin).clamp(margin, viewportHeight.toDouble()),
      );
    }

    final left = anchorLeft.clamp(
      margin,
      (viewportWidth - panelWidth - margin).clamp(margin, viewportWidth.toDouble()),
    );

    panel.style.top = '${top}px';
    panel.style.left = '${left}px';
  }

  void _focusFirstAction() {
    if (!mounted) {
      return;
    }
    final actions = component.controller.codeActions;
    if (actions == null || actions.isEmpty || identical(actions, _focusedActions)) {
      return;
    }
    _focusedActions = actions;
    final panel = _panelKey.currentNode as web.Element?;
    (panel?.querySelector('.code-action-btn') as web.HTMLButtonElement?)?.focus();
  }

  void _handleKeyDown(web.Event event) {
    final keyboardEvent = event as web.KeyboardEvent;
    final panel = _panelKey.currentNode as web.Element?;
    final buttons = panel?.querySelectorAll('.code-action-btn');
    if (buttons == null || buttons.length == 0) {
      return;
    }

    final activeElement = web.document.activeElement;
    var activeIndex = 0;
    for (var i = 0; i < buttons.length; i++) {
      if (identical(buttons.item(i), activeElement)) {
        activeIndex = i;
        break;
      }
    }

    int? nextIndex;
    switch (keyboardEvent.key) {
      case 'ArrowDown':
        nextIndex = (activeIndex + 1) % buttons.length;
      case 'ArrowUp':
        nextIndex = (activeIndex - 1 + buttons.length) % buttons.length;
      case 'Home':
        nextIndex = 0;
      case 'End':
        nextIndex = buttons.length - 1;
      case 'Enter' || ' ':
        keyboardEvent.preventDefault();
        keyboardEvent.stopPropagation();
        (buttons.item(activeIndex) as web.HTMLButtonElement).click();
        return;
      case 'Escape':
        keyboardEvent.preventDefault();
        keyboardEvent.stopPropagation();
        component.controller.hideCodeActionPanel();
        component.controller.codeEditor.focus();
        return;
    }

    if (nextIndex != null) {
      keyboardEvent.preventDefault();
      keyboardEvent.stopPropagation();
      (buttons.item(nextIndex) as web.HTMLButtonElement).focus();
    }
  }

  @override
  Component build(BuildContext context) {
    final actions = component.controller.codeActions;
    final children = switch (actions) {
      null => const <Component>[
        div(classes: 'code-action-empty-item', [.text('Loading code actions...')]),
      ],
      [] => const <Component>[
        div(classes: 'code-action-empty-item', [.text('No code actions available')]),
      ],
      _ => _buildGroupedActions(actions),
    };

    return div(
      key: _panelKey,
      classes: 'code-action-floating-panel',
      styles: Styles(
        raw: {
          'left': '${component.controller.panelLeft}px',
          'top': '${component.controller.panelTop}px',
        },
      ),
      children,
    );
  }

  List<Component> _buildGroupedActions(List<LSPCodeAction> actions) {
    final groups = <String, List<LSPCodeAction>>{};
    for (final action in actions) {
      final group = _kindGroup(action.kind?.toDart);
      (groups[group] ??= []).add(action);
    }

    // Stable display order: Quick Fix first, then Flutter, Extract, Refactor, Source, Other.
    const order = ['Quick Fix', 'Flutter', 'Extract', 'Refactor', 'Source', 'Other'];
    final sortedKeys = groups.keys.toList()
      ..sort((groupA, groupB) {
        final indexA = order.indexOf(groupA);
        final indexB = order.indexOf(groupB);
        return (indexA == -1 ? order.length : indexA).compareTo(indexB == -1 ? order.length : indexB);
      });

    return <Component>[
      for (final group in sortedKeys) ...[
        div(classes: 'code-action-group-header', [.text(group)]),
        div(
          classes: 'code-action-group-list',
          events: {'keydown': _handleKeyDown},
          [
            for (final action in groups[group]!)
              button(
                classes: 'code-action-btn',
                type: .button,
                onClick: () => unawaited(component.controller.applyCodeAction(action)),
                [.text(action.title.toDart)],
              ),
          ],
        ),
      ],
    ];
  }

  static String _kindGroup(String? kind) {
    if (kind == null || kind.startsWith('quickfix')) {
      return 'Quick Fix';
    }
    if (kind.startsWith('refactor.extract')) {
      return 'Extract';
    }
    if (kind.startsWith('refactor.flutter')) {
      return 'Flutter';
    }
    if (kind.startsWith('refactor')) {
      return 'Refactor';
    }
    if (kind.startsWith('source')) {
      return 'Source';
    }
    return 'Other';
  }
  static List<StyleRule> get styles => [
    css('.code-action-floating-panel').styles(
      display: .flex,
      position: const .fixed(),
      zIndex: const ZIndex(100),
      minWidth: 180.px,
      maxWidth: 320.px,
      maxHeight: const Unit.expression('min(360px, calc(100vh - 32px))'),
      border: .all(color: colorBorder, width: 1.px),
      radius: .circular(8.px),
      shadow: BoxShadow(
        offsetX: .zero,
        offsetY: 8.px,
        blur: 24.px,
        color: const .rgba(0, 0, 0, 0.5),
      ),
      flexDirection: .column,
      color: colorOnSurface,
      fontFamily: const .list([FontFamily('Inter'), FontFamilies.sansSerif]),
      fontSize: 12.px,
      backgroundColor: colorSurface,
      raw: {
        'overflow-y': 'auto',
      },
    ),
    css('.code-action-group-header').styles(
      padding: .only(top: 8.px, right: 12.px, bottom: 4.px, left: 12.px),
      color: colorOnContainer,
      fontSize: 10.px,
      fontWeight: .w700,
      raw: {
        'text-transform': 'uppercase',
        'letter-spacing': '0.5px',
      },
    ),
    css('.code-action-group-list').styles(
      display: .flex,
      padding: .only(bottom: 4.px),
      flexDirection: .column,
    ),
    css('.code-action-btn').styles(
      padding: .symmetric(vertical: 7.px, horizontal: 12.px),
      border: .none,
      cursor: .pointer,
      transition: Transition('background-color', duration: 100.ms),
      color: colorOnSurface,
      textAlign: .left,
      fontSize: 12.px,
      backgroundColor: Colors.transparent,
    ),
    css('.code-action-btn:hover, .code-action-btn:focus-visible').styles(
      outline: const Outline(style: .none),
      backgroundColor: const .rgba(255, 255, 255, 0.08),
    ),
    css('.code-action-empty-item').styles(
      padding: .symmetric(vertical: 12.px, horizontal: 16.px),
      color: colorOnContainer,
      textAlign: .center,
    ),
  ];
}

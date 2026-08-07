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
    });
  }

  @override
  void didUpdateComponent(CodeActionPanel oldComponent) {
    super.didUpdateComponent(oldComponent);
    Timer.run(_focusFirstAction);
  }

  @override
  void dispose() {
    unawaited(_clickSubscription?.cancel());
    super.dispose();
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
        div(classes: 'code-action-empty-item', [.text('Loading quick fixes...')]),
      ],
      [] => const <Component>[
        div(classes: 'code-action-empty-item', [.text('No quick fixes available')]),
      ],
      _ => <Component>[
        const div(classes: 'code-action-group-header', [.text('Quick Fix')]),
        div(
          classes: 'code-action-group-list',
          events: {'keydown': _handleKeyDown},
          [
            for (final action in actions)
              button(
                classes: 'code-action-btn',
                type: .button,
                onClick: () => unawaited(component.controller.applyCodeAction(action)),
                [.text(action.title.toDart)],
              ),
          ],
        ),
      ],
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

  static List<StyleRule> get styles => [
    css('.code-action-floating-panel').styles(
      display: .flex,
      position: const .fixed(),
      zIndex: const ZIndex(100),
      minWidth: 180.px,
      maxWidth: 320.px,
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

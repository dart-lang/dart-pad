// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../models/debug_console_entry.dart';

/// Displays the application's structured log events.
class DebugConsolePanel extends StatefulComponent {
  const DebugConsolePanel({required this.logs, super.key});

  final List<DebugConsoleEntry> logs;

  @override
  State<DebugConsolePanel> createState() => _DebugConsolePanelState();

  @css
  static List<StyleRule> get styles => _DebugConsolePanelState.styles;
}

class _DebugConsolePanelState extends State<DebugConsolePanel> {
  final GlobalNodeKey<web.HTMLElement> _listKey = GlobalNodeKey();

  @override
  void initState() {
    super.initState();
    if (component.logs.isNotEmpty) {
      context.binding.addPostFrameCallback(_scrollToBottom);
    }
  }

  @override
  void didUpdateComponent(covariant DebugConsolePanel oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (component.logs.length != oldComponent.logs.length) {
      context.binding.addPostFrameCallback(_scrollToBottom);
    }
  }

  void _scrollToBottom() {
    if (!mounted) {
      return;
    }
    final element = _listKey.currentNode;
    if (element != null) {
      element.scrollTop = element.scrollHeight;
    }
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'debug-console-panel', [
      div(
        key: _listKey,
        classes: 'debug-console-list',
        [
          if (component.logs.isEmpty)
            const div(classes: 'debug-console-empty', [.text('No debug output yet')])
          else
            for (final log in component.logs)
              div(classes: 'log-row ${log.level.debugConsoleCssClass}', [
                pre(classes: 'log-message', [.text(log.message)]),
              ]),
        ],
      ),
    ]);
  }

  static List<StyleRule> get styles => [
    css('.debug-console-panel').styles(
      display: .flex,
      minHeight: .zero,
      overflow: .hidden,
      flexDirection: .column,
      flex: const Flex(grow: 1, basis: .zero),
      backgroundColor: colorContainerLow,
    ),
    css('.debug-console-list').styles(
      minHeight: .zero,
      overflow: const .only(y: .auto),
      flex: const Flex(grow: 1, basis: .zero),
    ),
    css('.debug-console-empty').styles(
      display: .flex,
      minHeight: 48.px,
      padding: .symmetric(horizontal: 12.px),
      alignItems: .center,
      color: colorOnSurfaceVariant,
      fontSize: 12.px,
    ),
    css('.log-row').styles(
      display: .block,
      padding: .symmetric(horizontal: 12.px, vertical: 2.px),
      border: .only(
        left: .solid(color: Colors.transparent, width: 2.px),
      ),
      backgroundColor: Colors.transparent,
    ),
    css('.log-row.warning').styles(
      border: .only(
        left: .solid(color: colorWarning, width: 2.px),
      ),
      backgroundColor: colorWarning.withOpacity(0.08),
    ),
    css('.log-row.error').styles(
      border: .only(
        left: .solid(color: colorError, width: 2.px),
      ),
      backgroundColor: colorError.withOpacity(0.08),
    ),
    css('.log-row.warning .log-message').styles(color: colorWarning),
    css('.log-row.error .log-message').styles(color: colorError),
    css('.log-message').styles(
      margin: .zero,
      overflow: const .only(x: .auto),
      color: colorOnSurface.withOpacity(0.82),
      fontFamily: const .list([FontFamilies.courierNew, FontFamilies.monospace]),
      fontSize: 12.px,
      lineHeight: 18.px,
      whiteSpace: .preWrap,
    ),
  ];
}

extension DebugConsoleLevelStyling on Level {
  String get debugConsoleCssClass {
    if (this > Level.WARNING) {
      return 'error';
    }
    if (this == Level.WARNING) {
      return 'warning';
    }
    return 'info';
  }
}

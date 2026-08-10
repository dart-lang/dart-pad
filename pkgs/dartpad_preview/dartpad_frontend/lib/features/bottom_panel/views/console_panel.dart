// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../models/console_entry.dart';

/// Displays the application's structured log events.
class ConsolePanel extends StatefulComponent {
  const ConsolePanel({required this.logs, super.key});

  final List<ConsoleEntry> logs;

  @override
  State<ConsolePanel> createState() => _DebugConsolePanelState();

  @css
  static List<StyleRule> get styles => _DebugConsolePanelState.styles;
}

class _DebugConsolePanelState extends State<ConsolePanel> {
  final GlobalNodeKey<web.HTMLElement> _listKey = GlobalNodeKey();

  @override
  void initState() {
    super.initState();
    if (component.logs.isNotEmpty) {
      context.binding.addPostFrameCallback(_scrollToBottom);
    }
  }

  @override
  void didUpdateComponent(covariant ConsolePanel oldComponent) {
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
    return div(classes: 'console-panel', [
      div(
        key: _listKey,
        classes: 'console-list',
        [
          if (component.logs.isEmpty)
            const div(classes: 'console-empty', [.text('No output yet')])
          else
            for (final log in component.logs)
              div(classes: 'log-row ${log.level.consoleCssClass}', [
                pre(classes: 'log-message', [.text(log.message)]),
              ]),
        ],
      ),
    ]);
  }

  static List<StyleRule> get styles => [
    css('.console-panel').styles(
      display: .flex,
      minHeight: .zero,
      overflow: .hidden,
      flexDirection: .column,
      flex: const Flex(grow: 1, basis: .zero),
      backgroundColor: colorContainer,
    ),
    css('.console-list').styles(
      minHeight: .zero,
      padding: .symmetric(vertical: 4.px),
      overflow: const .only(y: .auto),
      flex: const Flex(grow: 1, basis: .zero),
    ),
    css('.console-empty').styles(
      display: .flex,
      minHeight: 48.px,
      padding: .symmetric(horizontal: 12.px),
      alignItems: .center,
      color: colorOnContainer,
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
      color: colorOnContainer,
      fontSize: 12.px,
      lineHeight: 18.px,
      whiteSpace: .preWrap,
    ),
  ];
}

extension ConsoleLevelStyling on Level {
  String get consoleCssClass {
    if (this > Level.WARNING) {
      return 'error';
    }
    if (this == Level.WARNING) {
      return 'warning';
    }
    return 'info';
  }
}

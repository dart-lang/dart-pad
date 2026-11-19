// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../models/console_entry.dart';

/// A one-time request to show the console, created each time it is opened.
///
/// A request with a [revealIndex] scrolls that line to the top of the console
/// and stops following new output. A request without one resumes following.
final class ConsoleOpenRequest {
  ConsoleOpenRequest({this.revealIndex});

  final int? revealIndex;

  /// Whether a [ConsolePanel] has applied this request. A remounted panel
  /// ignores handled requests.
  bool _handled = false;
}

/// Displays the application's structured log events.
class ConsolePanel extends StatefulComponent {
  const ConsolePanel({
    required this.logs,
    this.openRequest,
    super.key,
  });

  final List<ConsoleEntry> logs;

  /// The latest request to show the console, if it is not handled yet.
  final ConsoleOpenRequest? openRequest;

  @override
  State<ConsolePanel> createState() => _DebugConsolePanelState();

  @css
  static List<StyleRule> get styles => _DebugConsolePanelState.styles;
}

class _DebugConsolePanelState extends State<ConsolePanel> {
  final GlobalNodeKey<web.HTMLElement> _listKey = GlobalNodeKey();

  /// Whether new output scrolls the console to the bottom.
  bool _followOutput = true;

  /// The scroll position set by [_reveal], used to tell it apart from scrolls
  /// made by the user.
  double? _revealedScrollTop;

  @override
  void initState() {
    super.initState();
    if (component.openRequest != null) {
      context.binding.addPostFrameCallback(_applyOpenRequest);
    } else if (component.logs.isNotEmpty) {
      context.binding.addPostFrameCallback(_scrollToBottom);
    }
  }

  @override
  void didUpdateComponent(covariant ConsolePanel oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (component.logs.isEmpty) {
      _followOutput = true;
    }
    if (!identical(component.openRequest, oldComponent.openRequest) && component.openRequest != null) {
      context.binding.addPostFrameCallback(_applyOpenRequest);
    } else if (component.logs.length != oldComponent.logs.length && _followOutput) {
      context.binding.addPostFrameCallback(_scrollToBottom);
    }
  }

  void _applyOpenRequest() {
    final request = component.openRequest;
    if (!mounted || request == null || request._handled) {
      return;
    }
    request._handled = true;
    final index = request.revealIndex;
    if (index == null || !_reveal(index)) {
      _followOutput = true;
      _scrollToBottom();
    }
  }

  /// Scrolls the line at [index] to the top and stops following output.
  /// Returns `false` when the line is not displayed.
  bool _reveal(int index) {
    final element = _listKey.currentNode;
    if (element == null || index < 0 || index >= component.logs.length) {
      return false;
    }
    final row = element.children.item(index);
    if (row == null) {
      return false;
    }
    _followOutput = false;
    element.scrollTop += row.getBoundingClientRect().top - element.getBoundingClientRect().top;
    _revealedScrollTop = element.scrollTop;
    return true;
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

  /// Resumes following output once the user scrolls back to the bottom.
  void _onScroll() {
    final element = _listKey.currentNode;
    if (_followOutput || element == null || element.scrollTop == _revealedScrollTop) {
      return;
    }
    _revealedScrollTop = null;
    if (element.scrollTop + element.clientHeight >= element.scrollHeight - 1) {
      _followOutput = true;
    }
  }

  @override
  Component build(BuildContext context) {
    return div(
      classes: 'console-panel',
      [
        div(
          key: _listKey,
          classes: 'console-list',
          events: {'scroll': (_) => _onScroll()},
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
      ],
    );
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

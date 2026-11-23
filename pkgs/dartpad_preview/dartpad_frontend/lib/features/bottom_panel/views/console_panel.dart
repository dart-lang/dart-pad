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
}

/// Displays the application's structured log events.
class ConsolePanel extends StatefulComponent {
  const ConsolePanel({
    required this.logs,
    this.openRequest,
    this.onOpenRequestApplied,
    this.scrollTop,
    this.onScrollTopChanged,
    super.key,
  });

  final List<ConsoleEntry> logs;

  /// The latest request to show the console, if it is not applied yet.
  final ConsoleOpenRequest? openRequest;

  /// Called once [openRequest] is applied, so the owner can drop it.
  final void Function()? onOpenRequestApplied;

  /// The scroll position restored when the console is shown, or `null` to
  /// follow new output at the bottom.
  final double? scrollTop;

  /// Called with the position to restore when the console is shown again, or
  /// `null` once the console follows new output.
  final void Function(double? scrollTop)? onScrollTopChanged;

  @override
  State<ConsolePanel> createState() => _DebugConsolePanelState();

  @css
  static List<StyleRule> get styles => _DebugConsolePanelState.styles;
}

class _DebugConsolePanelState extends State<ConsolePanel> {
  final GlobalNodeKey<web.HTMLElement> _listKey = GlobalNodeKey();

  /// Whether new output scrolls the console to the bottom.
  late bool _followOutput = component.scrollTop == null;

  /// The scroll position set by this state, used to tell it apart from scrolls
  /// made by the user.
  double? _setScrollTop;

  @override
  void initState() {
    super.initState();
    if (component.openRequest != null) {
      context.binding.addPostFrameCallback(_applyOpenRequest);
    } else if (!_followOutput) {
      context.binding.addPostFrameCallback(_restoreScrollTop);
    } else if (component.logs.isNotEmpty) {
      context.binding.addPostFrameCallback(_scrollToBottom);
    }
  }

  @override
  void didUpdateComponent(covariant ConsolePanel oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (component.logs.isEmpty && !_followOutput) {
      _updateFollowOutput(null);
    }
    if (!identical(component.openRequest, oldComponent.openRequest) && component.openRequest != null) {
      context.binding.addPostFrameCallback(_applyOpenRequest);
    } else if (component.logs.length != oldComponent.logs.length && _followOutput) {
      context.binding.addPostFrameCallback(_scrollToBottom);
    }
  }

  void _applyOpenRequest() {
    final request = component.openRequest;
    if (!mounted || request == null) {
      return;
    }
    component.onOpenRequestApplied?.call();
    final index = request.revealIndex;
    if (index == null || !_reveal(index)) {
      _updateFollowOutput(null);
      _scrollToBottom();
    }
  }

  /// Scrolls the line at [index] to the top and stops following output,
  /// unless the console is already at the bottom. Returns `false` when the
  /// line is not displayed.
  bool _reveal(int index) {
    final element = _listKey.currentNode;
    if (element == null || index < 0 || index >= component.logs.length) {
      return false;
    }
    final row = element.children.item(index);
    if (row == null) {
      return false;
    }
    element.scrollTop += row.getBoundingClientRect().top - element.getBoundingClientRect().top;
    _setScrollTop = element.scrollTop;
    _updateFollowOutput(element);
    return true;
  }

  void _restoreScrollTop() {
    final element = _listKey.currentNode;
    final scrollTop = component.scrollTop;
    if (!mounted || element == null || scrollTop == null) {
      return;
    }
    element.scrollTop = scrollTop;
    _setScrollTop = element.scrollTop;
    _updateFollowOutput(element);
  }

  /// Follows new output when [element] is `null` or scrolled to the bottom.
  /// Otherwise, keeps its scroll position for when the console is shown again.
  void _updateFollowOutput(web.HTMLElement? element) {
    _followOutput = element == null || _isScrolledToBottom(element);
    component.onScrollTopChanged?.call(_followOutput ? null : element!.scrollTop);
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

  /// Keeps the user's scroll position, and resumes following output once the
  /// user scrolls back to the bottom.
  void _onScroll() {
    final element = _listKey.currentNode;
    if (_followOutput || element == null || element.scrollTop == _setScrollTop) {
      return;
    }
    _setScrollTop = null;
    _updateFollowOutput(element);
  }

  bool _isScrolledToBottom(web.HTMLElement element) =>
      element.scrollTop + element.clientHeight >= element.scrollHeight - 1;

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

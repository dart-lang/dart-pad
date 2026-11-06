// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../../../sdks.g.dart';
import '../icons.dart';
import '../links.dart';
import '../sdk_info.dart';
import '../task_status.dart';
import 'dropdown_menu.dart';
import 'icon_button.dart';
import 'task_status_indicator.dart';

/// The application footer with links, runtime information, and shortcuts.
final class Footer extends StatefulComponent {
  /// Creates the application footer.
  const Footer({
    required this.taskStatus,
    this.statusMessage,
    this.isSmallScreen = false,
    this.currentSdk,
    this.onSelectSdk,
    required this.onOpenShortcuts,
    super.key,
  });

  /// Recent application task activity.
  final TaskStatusController taskStatus;

  /// An optional editor error or warning shown alongside task activity.
  final String? statusMessage;

  /// Whether the footer is rendered in a small-screen layout.
  final bool isSmallScreen;

  /// The currently active SDK.
  final SdkInfo? currentSdk;

  /// Callback when a different SDK is selected.
  final ValueChanged<SdkInfo>? onSelectSdk;

  /// Callback when the keyboard shortcuts dialog should be opened.
  final VoidCallback onOpenShortcuts;

  @override
  State<Footer> createState() => _FooterState();

  @css
  static List<StyleRule> get styles => _FooterState.styles;
}

// Reduced keeps the SDK details but omits links; compact also shortens labels.
enum _FooterLayout { full, reduced, compact }

class _FooterState extends State<Footer> {
  late bool _isCompact;
  late final StreamSubscription<web.Event> _resizeSubscription;

  @override
  void initState() {
    super.initState();
    _isCompact = web.window.innerWidth < 500;
    _resizeSubscription = web.EventStreamProviders.resizeEvent.forTarget(web.window).listen((_) {
      final isCompact = web.window.innerWidth < 500;
      if (isCompact != _isCompact) {
        setState(() => _isCompact = isCompact);
      }
    });
  }

  @override
  void dispose() {
    _resizeSubscription.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    // The compact breakpoint is independent of the workspace's small-screen layout.
    final layout = switch ((_isCompact, component.isSmallScreen)) {
      (true, _) => _FooterLayout.compact,
      (false, true) => _FooterLayout.reduced,
      (false, false) => _FooterLayout.full,
    };
    return _buildFooter(layout);
  }

  Component _buildFooter(_FooterLayout layout) {
    final compact = layout == _FooterLayout.compact;
    return footer(classes: 'app-footer', [
      div(classes: 'app-footer-buttons', [
        IconButton(
          icon: 'keyboard',
          label: 'Keyboard shortcuts',
          tooltip: 'Keyboard shortcuts',
          onClick: (_) => component.onOpenShortcuts(),
        ),
        if (layout == _FooterLayout.full) ...[
          _buildPrivacyNoticeLink(),
          _buildFeedbackLink(),
        ],
      ]),
      if (component.statusMessage case final message?)
        div(classes: 'app-footer-message', [.text(message)])
      else
        const div(classes: 'app-footer-spacer', []),
      TaskStatusIndicator(controller: component.taskStatus),
      _buildRuntimeVersions(compact: compact),
      if (component.currentSdk?.channel case final channel? when channel.isNotEmpty)
        _buildChannelIndicator(channel, compact: compact),
    ]);
  }

  Component _buildRuntimeVersions({required bool compact}) {
    final currentSdk = component.currentSdk;
    final onSelectSdk = component.onSelectSdk;
    final label = currentSdk?.displayName ?? 'Dart …';

    return DropdownMenu(
      openUp: true,
      disabled: onSelectSdk == null,
      trigger: button(
        classes: 'app-footer-sdk-trigger',
        disabled: onSelectSdk == null,
        attributes: {'aria-label': 'Select DartPad SDK ($label)', 'title': 'Select DartPad SDK'},
        [
          const svg(
            classes: 'app-footer-info-icon',
            viewBox: '0 0 24 24',
            width: Unit.pixels(14),
            height: Unit.pixels(14),
            attributes: {'aria-hidden': 'true', 'focusable': 'false', 'fill': 'currentColor'},
            [
              path(
                d: 'M11 7h2v2h-2zm0 4h2v6h-2zm1-9a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm0 18a8 8 0 1 1 0-16 8 8 0 0 1 0 16z',
                [],
              ),
            ],
          ),
          span(classes: 'app-footer-sdk-label', [.text(compact ? currentSdk?.name ?? 'Dart' : label)]),
        ],
      ),
      items: [
        for (final sdk in availableSdks)
          DropdownMenuItem(
            label: sdk.displayName,
            trailingIcon: sdk.id == currentSdk?.id ? 'check' : null,
            onPressed: () => onSelectSdk?.call(sdk),
          ),
      ],
    );
  }

  Component _buildChannelIndicator(String channel, {required bool compact}) {
    final label = '${channel[0].toUpperCase()}${channel.substring(1)} channel';
    return span(
      classes: 'app-footer-channel',
      attributes: {'role': 'img', 'aria-label': label},
      [
        const Icon('tune', size: 14, attributes: {'aria-hidden': 'true'}),
        if (!compact) span(classes: 'app-footer-channel-label', [.text(label)]),
      ],
    );
  }

  Component _buildPrivacyNoticeLink() {
    return const a(
      href: privacyNoticeUrl,
      target: Target.blank,
      classes: 'app-footer-link',
      attributes: {'rel': 'noopener noreferrer'},
      [
        .text('Privacy notice'),
        Icon('open_in_new', size: 14),
      ],
    );
  }

  Component _buildFeedbackLink() {
    return const a(
      href: feedbackUrl,
      target: Target.blank,
      classes: 'app-footer-link',
      attributes: {'rel': 'noopener noreferrer'},
      [
        .text('Feedback'),
        Icon('open_in_new', size: 14),
      ],
    );
  }

  static List<StyleRule> get styles => [
    ...TaskStatusIndicator.styles,
    css('.app-footer').styles(
      display: .flex,
      minHeight: 34.px,
      padding: .symmetric(horizontal: 10.px),
      border: .only(
        top: .solid(color: colorBorder, width: 1.px),
      ),
      alignItems: .center,
      gap: Gap.all(10.px),
      flex: const .shrink(0),
      color: colorOnSurface,
      fontSize: 11.px,
      backgroundColor: colorSurface,
    ),
    css('.app-footer-buttons').styles(
      display: .flex,
      minWidth: .zero,
      alignItems: .center,
      gap: Gap.all(10.px),
    ),
    css('.app-footer .material-symbols-outlined').styles(
      display: .block,
      lineHeight: 1.em,
    ),
    css('.app-footer-link').styles(
      display: .inlineFlex,
      padding: .symmetric(horizontal: 8.px),
      alignItems: .center,
      gap: Gap.all(4.px),
      color: colorOnSurface,
      textDecoration: .none,
      whiteSpace: .noWrap,
    ),
    css('.app-footer-link:hover').styles(color: colorOnSurface),
    css('.app-footer-sdk-trigger, .app-footer-channel').styles(
      display: .inlineFlex,
      position: const .relative(),
      height: 28.px,
      padding: .symmetric(horizontal: 6.px),
      border: .none,
      radius: .circular(4.px),
      outline: const Outline(style: .none),
      transition: Transition('background-color', duration: 150.ms, curve: .ease),
      alignItems: .center,
      gap: Gap.all(4.px),
      flex: const .shrink(0),
      color: colorOnSurface,
      fontFamily: const .list([FontFamilies.sansSerif]),
      fontSize: 11.px,
      textOverflow: .ellipsis,
      whiteSpace: .noWrap,
      backgroundColor: Colors.transparent,
    ),
    css('.app-footer-sdk-trigger').styles(cursor: .pointer),
    css('.app-footer-sdk-trigger:not(:disabled):hover, .app-footer-sdk-trigger:not(:disabled):focus').styles(
      backgroundColor: colorSurface.highlight(colorOnSurface, 0.1),
    ),
    css('.app-footer-sdk-trigger:disabled').styles(
      opacity: 0.7,
      cursor: .notAllowed,
    ),
    css('.app-footer-spacer').styles(flex: const .grow(1)),
    css('.app-footer .task-status-trigger').styles(
      width: 100.percent,
      minWidth: .zero,
      boxSizing: .borderBox,
    ),
    css('.app-footer-message').styles(
      minWidth: .zero,
      margin: const Margin.only(left: Unit.auto),
      overflow: .hidden,
      textAlign: .right,
      fontSize: 11.px,
      textOverflow: .ellipsis,
      whiteSpace: .noWrap,
    ),
  ];
}

// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';
import '../../../sdks.g.dart';
import '../analyzer_status.dart';
import '../icons.dart';
import '../sdk_info.dart';
import '../task_status.dart';
import 'dropdown_menu.dart';
import 'icon_button.dart';
import 'shortcuts_dialog.dart';
import 'task_status_indicator.dart';

/// The application footer with links, runtime information, and shortcuts.
final class Footer extends StatefulComponent {
  /// Creates the application footer.
  const Footer({
    required this.taskStatus,
    required this.analyzerStatus,
    this.statusMessage,
    this.isSmallScreen = false,
    this.currentSdk,
    this.onSelectSdk,
    super.key,
  });

  /// Recent application task activity.
  final TaskStatusController taskStatus;

  /// Readiness and background activity of the session analyzer.
  final AnalyzerStatusController analyzerStatus;

  /// An optional editor error or warning shown alongside task activity.
  final String? statusMessage;

  /// Whether the footer is rendered in a small-screen layout.
  final bool isSmallScreen;

  /// The currently active SDK.
  final SdkInfo? currentSdk;

  /// Callback when a different SDK is selected.
  final ValueChanged<SdkInfo>? onSelectSdk;

  @override
  State<Footer> createState() => _FooterState();

  @css
  static List<StyleRule> get styles => _FooterState.styles;
}

class _FooterState extends State<Footer> {
  bool _showShortcuts = false;

  void _openShortcuts() {
    setState(() {
      _showShortcuts = true;
    });
  }

  void _closeShortcuts() {
    if (!_showShortcuts) {
      return;
    }
    setState(() {
      _showShortcuts = false;
    });
  }

  @override
  Component build(BuildContext context) {
    return Component.fragment([
      footer(classes: 'app-footer', [
        div(classes: 'app-footer-buttons', [
          IconButton(
            icon: 'keyboard',
            label: 'Keyboard shortcuts',
            tooltip: 'Keyboard shortcuts',
            onClick: (_) => _openShortcuts(),
          ),
          if (!component.isSmallScreen) ...[
            _buildPrivacyNoticeLink(),
            _buildFeedbackLink(),
          ],
        ]),
        if (component.statusMessage case final message?)
          div(classes: 'app-footer-message', [.text(message)])
        else
          const div(classes: 'app-footer-spacer', []),
        TaskStatusIndicator(controller: component.taskStatus),
        AnalyzerStatusIndicator(controller: component.analyzerStatus),
        _buildRuntimeVersions(),
      ]),
      if (_showShortcuts)
        ShortcutsDialog(
          key: const ValueKey('footer-shortcuts-dialog'),
          onClose: _closeShortcuts,
        ),
    ]);
  }

  Component _buildRuntimeVersions() {
    final currentSdk = component.currentSdk;
    final onSelectSdk = component.onSelectSdk;
    final isDisabled = onSelectSdk == null;

    if (availableSdks.length > 1) {
      return DropdownMenu(
        openUp: true,
        disabled: isDisabled,
        trigger: button(
          classes: 'app-footer-sdk-trigger',
          disabled: isDisabled,
          attributes: {
            'aria-label': 'Select DartPad SDK',
            'title': 'Select DartPad SDK',
          },
          [
            span([.text(currentSdk?.displayName ?? 'Dart … • Flutter …')]),
            const Icon('arrow_drop_down', size: 16),
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

    final displayText = currentSdk?.displayName ?? 'Dart … • Flutter …';
    return div(
      classes: 'app-footer-runtime-versions',
      attributes: {'aria-label': 'Runtime versions'},
      [
        .text(displayText),
      ],
    );
  }

  Component _buildPrivacyNoticeLink() {
    return const a(
      href: 'https://dart.dev/tools/dartpad/privacy',
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
      href: 'https://github.com/dart-lang/dart-pad/issues/new?template=4-dartpad-preview-issue.yml',
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
    ...AnalyzerStatusIndicator.styles,
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
    css('.app-footer-runtime-versions').styles(
      minWidth: .zero,
      overflow: .hidden,
      textOverflow: .ellipsis,
      whiteSpace: .noWrap,
    ),
    css('.app-footer-sdk-trigger').styles(
      display: .inlineFlex,
      position: const .relative(),
      height: 28.px,
      padding: .symmetric(horizontal: 6.px),
      border: .none,
      radius: .circular(4.px),
      outline: const Outline(style: .none),
      cursor: .pointer,
      transition: Transition('background-color', duration: 150.ms, curve: .ease),
      alignItems: .center,
      gap: Gap.all(2.px),
      color: colorOnSurface,
      fontFamily: const .list([FontFamilies.sansSerif]),
      fontSize: 11.px,
      textOverflow: .ellipsis,
      whiteSpace: .noWrap,
      backgroundColor: Colors.transparent,
    ),
    css('.app-footer-sdk-trigger:not(:disabled):hover, .app-footer-sdk-trigger:not(:disabled):focus').styles(
      backgroundColor: colorSurface.highlight(colorOnSurface, 0.1),
    ),
    css('.app-footer-sdk-trigger:disabled').styles(
      opacity: 0.7,
      cursor: .notAllowed,
    ),
    css('.app-footer-spacer').styles(flex: const .grow(1)),
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

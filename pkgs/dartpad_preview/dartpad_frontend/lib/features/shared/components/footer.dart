// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../../../sdks.g.dart';
import '../icons.dart';
import '../sdk_info.dart';
import 'dropdown_menu.dart';
import 'icon_button.dart';

/// The application footer with links, runtime information, and shortcuts.
final class Footer extends StatefulComponent {
  /// Creates the application footer.
  const Footer({
    required this.statusLabel,
    this.isMobile = false,
    this.currentSdk,
    this.onSelectSdk,
    super.key,
  });

  /// Human-readable label for the current application status.
  final String statusLabel;

  /// Whether the footer is rendered in mobile layout mode.
  final bool isMobile;

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
    Timer.run(() {
      if (!_showShortcuts) {
        return;
      }
      final dialog = web.document.querySelector('.app-footer-shortcuts-dialog');
      if (dialog != null && dialog.isA<web.HTMLDialogElement>()) {
        final htmlDialog = dialog as web.HTMLDialogElement;
        if (htmlDialog.open) {
          return;
        }
        htmlDialog.showModal();
        final closeButton = htmlDialog.querySelector('[aria-label="Close shortcuts dialog"]');
        if (closeButton != null && closeButton.isA<web.HTMLElement>()) {
          (closeButton as web.HTMLElement).focus();
        }
      }
    });
  }

  void _closeShortcuts() {
    if (!_showShortcuts) {
      return;
    }
    final dialog = web.document.querySelector('.app-footer-shortcuts-dialog');
    if (dialog != null && dialog.isA<web.HTMLDialogElement>()) {
      final htmlDialog = dialog as web.HTMLDialogElement;
      if (htmlDialog.open) {
        htmlDialog.close();
      }
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
          if (!component.isMobile) ...[
            _buildPrivacyNoticeLink(),
            _buildFeedbackLink(),
          ],
        ]),
        div(classes: 'app-footer-status', [
          .text(component.statusLabel),
        ]),
        _buildRuntimeVersions(),
      ]),
      if (_showShortcuts) _buildShortcutsDialog(),
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
      href: 'https://github.com/dart-lang/dart-pad/issues',
      target: Target.blank,
      classes: 'app-footer-link',
      attributes: {'rel': 'noopener noreferrer'},
      [
        .text('Feedback'),
        Icon('open_in_new', size: 14),
      ],
    );
  }

  Component _buildShortcutsDialog() {
    return dialog(
      classes: 'app-footer-shortcuts-dialog',
      events: {
        'cancel': (event) {
          event.preventDefault();
          _closeShortcuts();
        },
        'click': (event) {
          if (event.target == event.currentTarget) {
            _closeShortcuts();
          }
        },
      },
      attributes: const {
        'aria-labelledby': 'app-footer-shortcuts-title',
      },
      [
        div(classes: 'app-footer-dialog-header', [
          const h2(id: 'app-footer-shortcuts-title', [
            .text('Keyboard shortcuts'),
          ]),
          IconButton(
            icon: 'close',
            label: 'Close shortcuts dialog',
            onClick: (_) => _closeShortcuts(),
          ),
        ]),
        div(classes: 'app-footer-shortcuts-list', [
          _shortcutRow('Save files', 'Ctrl/Cmd + S'),
          _shortcutRow('Format Dart files', 'Shift + Alt + F'),
          _shortcutRow('Quick fix', 'Ctrl/Cmd + .'),
          _shortcutRow('Toggle line comment', 'Ctrl/Cmd + /'),
          _shortcutRow('Indent', 'Tab'),
        ]),
      ],
    );
  }

  Component _shortcutRow(String command, String shortcut) {
    return div(classes: 'app-footer-shortcut-row', [
      span(classes: 'app-footer-shortcut-command', [.text(command)]),
      span(classes: 'app-footer-shortcut-key', [.text(shortcut)]),
    ]);
  }

  static List<StyleRule> get styles => [
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
      cursor: .pointer,
      transition: Transition('background-color', duration: 150.ms, curve: .ease),
      alignItems: .center,
      gap: Gap.all(2.px),
      color: colorOnSurface,
      fontSize: 11.px,
      fontFamily: const .list([FontFamilies.sansSerif]),
      backgroundColor: Colors.transparent,
      outline: const Outline(style: .none),
      textOverflow: .ellipsis,
      whiteSpace: .noWrap,
    ),
    css('.app-footer-sdk-trigger:not(:disabled):hover, .app-footer-sdk-trigger:not(:disabled):focus').styles(
      backgroundColor: colorSurface.highlight(colorOnSurface, 0.1),
    ),
    css('.app-footer-sdk-trigger:disabled').styles(
      cursor: .notAllowed,
      opacity: 0.7,
    ),
    css('.app-footer-status').styles(
      margin: Margin.only(left: Unit.auto, right: 8.px),
      width: 120.px,
      minWidth: 120.px,
      overflow: .hidden,
      fontSize: 11.px,
      textOverflow: .ellipsis,
      whiteSpace: .noWrap,
      textAlign: .right,
    ),
    css('.app-footer-shortcuts-dialog::backdrop').styles(
      backgroundColor: const Color('rgba(0, 0, 0, 0.55)'),
    ),
    css('.app-footer-shortcuts-dialog').styles(
      minWidth: 320.px,
      maxWidth: 90.percent,
      padding: .zero,
      border: .all(color: colorBorder, width: 1.px),
      radius: .circular(6.px),
      color: colorOnSurface,
      backgroundColor: colorSurface,
    ),
    css('.app-footer-dialog-header').styles(
      display: .flex,
      padding: .symmetric(vertical: 10.px, horizontal: 14.px),
      border: .only(
        bottom: .solid(color: colorBorder, width: 1.px),
      ),
      justifyContent: .spaceBetween,
      alignItems: .center,
      gap: Gap.all(10.px),
    ),
    css('.app-footer-dialog-header h2').styles(
      margin: .zero,
      fontSize: 15.px,
      fontWeight: .w500,
    ),
    css('.app-footer-shortcuts-list').styles(
      display: .flex,
      padding: .symmetric(vertical: 8.px, horizontal: 14.px),
      flexDirection: .column,
      gap: Gap.all(2.px),
    ),
    css('.app-footer-shortcut-row').styles(
      display: .flex,
      padding: .symmetric(vertical: 6.px),
      justifyContent: .spaceBetween,
      alignItems: .center,
      gap: Gap.all(20.px),
    ),
    css('.app-footer-shortcut-command').styles(
      color: colorOnSurface,
      fontSize: 12.px,
    ),
    css('.app-footer-shortcut-key').styles(
      padding: .symmetric(vertical: 2.px, horizontal: 6.px),
      border: .all(color: colorBorder, width: 1.px),
      radius: .circular(4.px),
      color: colorOnContainer,
      fontFamily: const .list([FontFamily('Consolas'), FontFamilies.monospace]),
      fontSize: 11.px,
      whiteSpace: .noWrap,
      backgroundColor: colorContainer,
    ),
  ];
}

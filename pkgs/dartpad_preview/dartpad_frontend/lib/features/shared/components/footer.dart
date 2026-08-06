// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';
import 'package:jaspr_content/components/theme_toggle.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../icons.dart';
import '../runtime_versions.dart';

/// The application footer with links, runtime information, and shortcuts.
final class Footer extends StatefulComponent {
  /// Creates the application footer.
  const Footer({
    required this.statusLabel,
    super.key,
  });

  /// Human-readable label for the current application status.
  final String statusLabel;

  @override
  State<Footer> createState() => _FooterState();

  @css
  static List<StyleRule> get styles => _FooterState.styles;
}

class _FooterState extends State<Footer> {
  bool _showShortcuts = false;
  RuntimeVersions? _runtimeVersions;

  String get dartRuntimeVersion => _runtimeVersions?.dart ?? '…';
  String get flutterRuntimeVersion => _runtimeVersions?.flutter ?? '…';

  @override
  void initState() {
    super.initState();
    unawaited(_loadRuntimeVersions());
  }

  Future<void> _loadRuntimeVersions() async {
    final versions = await RuntimeVersions.load();
    if (versions != null && mounted) {
      setState(() {
        _runtimeVersions = versions;
      });
    }
  }

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
          _buildShortcutsButton(),
          _buildPrivacyNoticeLink(),
          _buildFeedbackLink(),
        ]),
        ThemeToggle(),
        div(
          classes: 'app-footer-runtime-versions',
          attributes: {'aria-label': 'Runtime versions'},
          [
            .text('Dart $dartRuntimeVersion • Flutter $flutterRuntimeVersion'),
          ],
        ),
        div(classes: 'app-footer-status', [
          .text(component.statusLabel),
        ]),
      ]),
      if (_showShortcuts) _buildShortcutsDialog(),
    ]);
  }

  Component _buildShortcutsButton() {
    return button(
      classes: 'app-footer-icon-button',
      attributes: const {
        'title': 'Keyboard shortcuts',
        'aria-label': 'Keyboard shortcuts',
      },
      onClick: _openShortcuts,
      [const Icon('keyboard', size: 18)],
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
          button(
            classes: 'app-footer-icon-button',
            attributes: const {
              'title': 'Close',
              'aria-label': 'Close shortcuts dialog',
            },
            onClick: _closeShortcuts,
            [const Icon('close', size: 18)],
          ),
        ]),
        div(classes: 'app-footer-shortcuts-list', [
          _shortcutRow('Save files', 'Ctrl/Cmd + S'),
          _shortcutRow('Format Dart files', 'Shift + Alt + F'),
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
      overflow: .hidden,
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
      gap: Gap.all(20.px),
    ),
    css('.app-footer .material-symbols-outlined').styles(
      display: .block,
      lineHeight: 1.em,
    ),
    css('.app-footer-link').styles(
      display: .inlineFlex,
      alignItems: .center,
      gap: Gap.all(4.px),
      color: colorOnSurface,
      textDecoration: .none,
      whiteSpace: .noWrap,
    ),
    css('.app-footer-link:hover').styles(color: colorOnSurface),
    css('.app-footer-runtime-versions').styles(
      minWidth: .zero,
      margin: const Margin.only(left: Unit.auto),
      overflow: .hidden,
      textOverflow: .ellipsis,
      whiteSpace: .noWrap,
    ),
    css('.app-footer-status').styles(
      width: 120.px,
      minWidth: 120.px,
      margin: Margin.only(left: 10.px),
      overflow: .hidden,
      fontSize: 11.px,
      textOverflow: .ellipsis,
      whiteSpace: .noWrap,
    ),
    css('.app-footer-icon-button').styles(
      display: .inlineFlex,
      width: 24.px,
      height: 24.px,
      padding: .zero,
      border: .none,
      radius: .circular(4.px),
      cursor: .pointer,
      justifyContent: .center,
      alignItems: .center,
      color: colorOnSurface,
      backgroundColor: Colors.transparent,
    ),
    css('.app-footer-icon-button:hover').styles(
      color: colorOnSurface,
      backgroundColor: colorOnSurface.withOpacity(0.08),
    ),
    css('.app-footer-icon-button:focus-visible').styles(
      outline: Outline(
        color: colorPrimary,
        style: OutlineStyle.solid,
        width: OutlineWidth(2.px),
        offset: 2.px,
      ),
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
      color: colorOnSurface,
      fontFamily: const .list([FontFamily('Consolas'), FontFamilies.monospace]),
      fontSize: 11.px,
      whiteSpace: .noWrap,
    ),
  ];
}

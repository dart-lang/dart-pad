// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../icons.dart';

/// A non-dismissible modal overlay that displays a descriptive error message
/// when a critical failure occurs during project loading or workspace
/// initialization.
///
/// The overlay cannot be dismissed. The only action available is the
/// "Reload Page" button which reloads the browser window.
class ErrorDialog extends StatelessComponent {
  const ErrorDialog({required this.errorMessage, super.key});

  /// A user-facing description of what went wrong.
  final String errorMessage;

  @override
  Component build(BuildContext context) {
    return div(
      classes: 'error-dialog-backdrop',
      attributes: const {
        'role': 'alertdialog',
        'aria-modal': 'true',
        'aria-labelledby': 'error-dialog-title',
        'aria-describedby': 'error-dialog-message',
      },
      [
        div(classes: 'error-dialog', [
          div(classes: 'error-dialog-content', [
            const Icon('error', size: 48, classes: 'error-dialog-icon'),
            const h2(
              id: 'error-dialog-title',
              classes: 'error-dialog-title',
              [.text('Oops, something went wrong!')],
            ),
            div(
              id: 'error-dialog-message',
              classes: 'error-dialog-message',
              [.text(errorMessage)],
            ),
            const div(
              classes: 'error-dialog-hint',
              [.text('Please reload the page to try again.')],
            ),
            button(
              classes: 'error-dialog-reload-button',
              attributes: const {
                'title': 'Reload Page',
                'aria-label': 'Reload Page',
              },
              events: {
                'click': (_) => web.window.location.reload(),
              },
              [
                const Icon('refresh', size: 18),
                const .text('Reload Page'),
              ],
            ),
          ]),
        ]),
      ],
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.error-dialog-backdrop').styles(
      display: .flex,
      position: .fixed(top: 0.px, left: 0.px, right: 0.px, bottom: 0.px),
      zIndex: const ZIndex(9999),
      justifyContent: .center,
      alignItems: .center,
      backgroundColor: const Color('rgba(0, 0, 0, 0.55)'),
    ),
    css('.error-dialog').styles(
      minWidth: 360.px,
      maxWidth: 460.px,
      padding: .zero,
      border: .all(color: colorBorder, width: 1.px),
      radius: .circular(10.px),
      color: colorOnSurface,
      backgroundColor: colorContainer,
    ),
    css('.error-dialog-content').styles(
      display: .flex,
      padding: .symmetric(vertical: 32.px, horizontal: 28.px),
      flexDirection: .column,
      alignItems: .center,
      gap: Gap.all(16.px),
    ),
    css('.error-dialog-icon').styles(
      color: colorError,
    ),
    css('.error-dialog-title').styles(
      margin: .zero,
      color: colorOnContainer,
      textAlign: .center,
      fontSize: 18.px,
      fontWeight: .w600,
    ),
    css('.error-dialog-message').styles(
      padding: .symmetric(vertical: 8.px, horizontal: 16.px),
      border: .all(color: colorError.highlight(colorBorder, 0.5), width: 1.px),
      radius: .circular(6.px),
      color: colorOnContainer,
      textAlign: .center,
      fontSize: 13.px,
      lineHeight: 1.5.em,
      backgroundColor: colorErrorSurface,
    ),
    css('.error-dialog-hint').styles(
      color: colorOnSurface,
      textAlign: .center,
      fontSize: 13.px,
    ),
    css('.error-dialog-reload-button', [
      css('&').styles(
        display: .inlineFlex,
        padding: .symmetric(vertical: 10.px, horizontal: 20.px),
        border: .none,
        radius: .circular(6.px),
        outline: const Outline(style: .none),
        cursor: .pointer,
        justifyContent: .center,
        alignItems: .center,
        gap: Gap.all(6.px),
        color: colorOnPrimary,
        fontSize: 14.px,
        fontWeight: FontWeight.w500,
        backgroundColor: colorPrimary,
      ),
      css('&:hover').styles(
        backgroundColor: colorPrimary.highlight(colorOnPrimary, 0.1),
      ),
    ]),
  ];
}

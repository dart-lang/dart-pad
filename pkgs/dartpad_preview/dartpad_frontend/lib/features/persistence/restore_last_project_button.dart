// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../app_styles.dart';
import '../shared/icons.dart';

/// A button that offers restoring the last matching project, with a distinct circular dismiss button.
final class RestoreLastProjectButton extends StatelessComponent {
  const RestoreLastProjectButton({
    required this.onRestore,
    required this.onCancel,
    super.key,
  });

  final VoidCallback onRestore;
  final VoidCallback onCancel;

  @override
  Component build(BuildContext context) => button(
    classes: 'restore-last-project',
    attributes: {
      'type': 'button',
      'title': 'Restore the most recent project opened with this link',
    },
    onClick: onRestore,
    events: {
      'keydown': (event) {
        final key = (event as web.KeyboardEvent).key;
        if (key == 'Escape') {
          event.preventDefault();
          onCancel();
        }
      },
    },
    [
      const span(classes: 'restore-last-project-label', [.text('Restore project')]),
      span(
        classes: 'restore-last-project-dismiss restore-last-project-cancel',
        attributes: {
          'role': 'button',
          'tabindex': '0',
          'title': 'Dismiss',
          'aria-label': 'Dismiss restore offer',
        },
        events: {
          'click': (event) {
            event.stopPropagation();
            onCancel();
          },
          'keydown': (event) {
            final key = (event as web.KeyboardEvent).key;
            if (key == 'Enter' || key == ' ') {
              event.preventDefault();
              event.stopPropagation();
              onCancel();
            }
          },
        },
        [
          const Icon('close', size: 14),
        ],
      ),
    ],
  );

  @css
  static List<StyleRule> get styles => [
    css('.restore-last-project').styles(
      display: .inlineFlex,
      position: const .relative(),
      height: 32.px,
      padding: .only(left: 12.px, right: 6.px),
      boxSizing: .borderBox,
      border: .none,
      radius: .circular(8.px),
      cursor: .pointer,
      userSelect: .none,
      alignItems: .center,
      gap: Gap.all(8.px),
      color: Colors.white,
      fontSize: 13.px,
      fontWeight: FontWeight.w500,
      whiteSpace: .noWrap,
      backgroundColor: colorPrimary,
      raw: {
        'box-shadow': '0 2px 6px rgba(0, 0, 0, 0.15)',
        'transition': 'background-color 0.15s ease, filter 0.15s ease',
      },
    ),
    css('.restore-last-project:hover').styles(
      raw: {'filter': 'brightness(1.08)'},
    ),
    css('.restore-last-project-label').styles(
      display: .inlineBlock,
      lineHeight: 1.em,
    ),
    css('.restore-last-project-dismiss').styles(
      display: .inlineFlex,
      width: 20.px,
      height: 20.px,
      padding: .zero,
      margin: .zero,
      boxSizing: .borderBox,
      border: .all(color: const Color.rgba(255, 255, 255, 0.2), width: 1.px),
      radius: .circular(999.px),
      cursor: .pointer,
      justifyContent: .center,
      alignItems: .center,
      flex: const .shrink(0),
      color: Colors.white,
      raw: {
        'line-height': '1',
        'background-color': 'rgba(15, 23, 42, 0.38)',
        'box-shadow': 'inset 0 1px 2px rgba(0, 0, 0, 0.25)',
        'transition': 'background-color 0.15s ease, border-color 0.15s ease',
      },
    ),
    css('.restore-last-project-dismiss:hover').styles(
      raw: {
        'background-color': 'rgba(15, 23, 42, 0.65)',
        'border-color': 'rgba(255, 255, 255, 0.4)',
      },
    ),
  ];
}

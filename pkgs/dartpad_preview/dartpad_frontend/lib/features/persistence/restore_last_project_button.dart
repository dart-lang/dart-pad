// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../app_styles.dart';

/// A button with an animated countdown timer that offers restoring the last matching project before [expires].
final class RestoreLastProjectButton extends StatefulComponent {
  const RestoreLastProjectButton({required this.expires, required this.duration, required this.onRestore, super.key});

  final DateTime expires;
  final Duration duration;
  final VoidCallback onRestore;

  @override
  State<RestoreLastProjectButton> createState() => _RestoreLastProjectButtonState();

  @css
  static List<StyleRule> get styles => [
    css('.restore-last-project').styles(
      position: const .relative(),
      padding: .symmetric(horizontal: 10.px, vertical: 8.px),
      border: .none,
      radius: .circular(6.px),
      overflow: .hidden,
      cursor: .pointer,
      color: colorOnPrimary,
      fontSize: 13.px,
      whiteSpace: .noWrap,
      backgroundColor: colorPrimary,
    ),
    css('.restore-last-project-timer').styles(
      position: .absolute(left: 0.px, right: 0.px, bottom: 0.px),
      height: 2.px,
      backgroundColor: colorOnPrimary,
      raw: {
        'transform-origin': 'left',
        'animation': 'restore-offer-countdown var(--restore-remaining) linear forwards',
      },
    ),
    css.keyframes('restore-offer-countdown', {
      'from': const Styles(raw: {'transform': 'scaleX(var(--restore-fraction))'}),
      'to': const Styles(raw: {'transform': 'scaleX(0)'}),
    }),
  ];
}

final class _RestoreLastProjectButtonState extends State<RestoreLastProjectButton> {
  late final int _remaining;
  late final double _fraction;

  @override
  void initState() {
    super.initState();
    _remaining = component.expires
        .difference(DateTime.now())
        .inMilliseconds
        .clamp(0, component.duration.inMilliseconds);
    _fraction = component.duration.inMilliseconds == 0 ? 0 : _remaining / component.duration.inMilliseconds;
  }

  @override
  Component build(BuildContext context) => button(
    classes: 'restore-last-project',
    attributes: {
      'title': 'Restore the most recent project opened with this link',
      'style': '--restore-remaining: ${_remaining}ms; --restore-fraction: $_fraction;',
    },
    onClick: component.onRestore,
    [
      const span([.text('Restore last project')]),
      const span(classes: 'restore-last-project-timer', attributes: {'aria-hidden': 'true'}, []),
    ],
  );
}

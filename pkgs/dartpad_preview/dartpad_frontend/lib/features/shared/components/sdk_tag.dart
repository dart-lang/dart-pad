// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';

/// A small badge naming an SDK release channel, e.g. `stable`.
class SdkTag extends StatelessComponent {
  const SdkTag(this.label, {super.key});

  final String label;

  @override
  Component build(BuildContext context) => span(classes: 'sdk-tag', [.text(label)]);

  @css
  static List<StyleRule> get styles => [
    css('.sdk-tag').styles(
      display: .inlineBlock,
      padding: .symmetric(horizontal: 5.px),
      radius: .circular(3.px),
      flex: const .shrink(0),
      fontFamily: monospaceFontFamily,
      fontSize: 9.px,
      fontWeight: .w600,
      lineHeight: 15.px,
      backgroundColor: const .rgba(128, 128, 128, 0.16),
      raw: {
        'letter-spacing': '0.06em',
        'opacity': '0.75',
        'text-transform': 'uppercase',
      },
    ),
  ];
}

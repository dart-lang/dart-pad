// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class About extends StatelessComponent {
  const About({super.key});

  @override
  Component build(BuildContext context) {
    return const section([
      ol([
        li([
          h3([.text('📖 Documentation')]),
          .text('Jaspr\'s '),
          a(href: 'https://docs.jaspr.site', [.text('official documentation')]),
          .text(' provides you with all information you need to get started.'),
        ]),
        li([
          h3([.text('💬 Community')]),
          .text('Got stuck? Ask your question on the official '),
          a(href: 'https://discord.gg/XGXrGEk4c6', [.text('Discord server')]),
          .text(' for the Jaspr community.'),
        ]),
        li([
          h3([.text('📦 Ecosystem')]),
          .text(
            'Get official packages and integrations for your project like jaspr_router, jaspr_tailwind or jaspr_riverpod. Find packages built for Jaspr on pub.dev using the ',
          ),
          a(href: 'https://pub.dev/packages?q=topic%3Ajaspr', [.text('#jaspr')]),
          .text(' topic, or publish your own.'),
        ]),
        li([
          h3([.text('💙 Support Jaspr')]),
          .text('If you like Jaspr, consider starring us on '),
          a(href: 'https://github.com/schultek/jaspr', [.text('Github')]),
          .text(' and tell your friends.'),
        ]),
      ]),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('ol').styles(maxWidth: 500.px),
  ];
}

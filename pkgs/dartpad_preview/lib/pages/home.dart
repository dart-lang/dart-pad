// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/counter.dart';

class Home extends StatelessComponent {
  const Home({super.key});

  @override
  Component build(BuildContext context) {
    return section([
      img(src: 'images/logo.svg', width: 80),
      h1([.text('Welcome')]),
      p([.text('You created a new Jaspr site.')]),
      div(styles: Styles(height: 100.px), []),
      const Counter(),
    ]);
  }
}

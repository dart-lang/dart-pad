// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Renders a standard Material Symbol icon by its name.
class Icon extends StatelessComponent {
  const Icon(this.name, {this.size = 24, super.key});

  final String name;
  final double size;

  @override
  Component build(BuildContext context) {
    return span(
      classes: 'material-symbols-outlined',
      styles: Styles(fontSize: size.px),
      [.text(name)],
    );
  }
}

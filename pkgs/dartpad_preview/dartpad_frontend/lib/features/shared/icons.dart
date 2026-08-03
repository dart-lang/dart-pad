// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Renders a standard Material Symbol icon by its name.
class Icon extends StatelessComponent {
  const Icon(this.name, {this.size = 24, this.classes, this.attributes, super.key});

  final String name;
  final double size;
  final String? classes;
  final Map<String, String>? attributes;

  @override
  Component build(BuildContext context) {
    return span(
      classes: 'material-symbols-outlined${classes != null ? ' $classes' : ''}',
      styles: Styles(fontSize: size.px),
      attributes: attributes,
      [.text(name)],
    );
  }
}

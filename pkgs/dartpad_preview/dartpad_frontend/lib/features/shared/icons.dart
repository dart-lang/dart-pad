// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'sdk_kind.dart';

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

/// A monochrome Dart or Flutter logo that follows the current text color.
///
/// The logo files in `web/images/` are used as a CSS mask over `currentColor`,
/// since an `<img>` could not take on the text color.
class SdkLogo extends StatelessComponent {
  const SdkLogo(this.kind, {this.size = 14, super.key});

  /// The SDK kind whose logo is drawn.
  final SdkKind kind;

  /// The width and height in pixels.
  final double size;

  String get _asset => switch (kind) {
    .dart => 'images/logo_dart_mono.svg',
    .flutter => 'images/logo_flutter_mono.svg',
  };

  @override
  Component build(BuildContext context) {
    return span(
      classes: 'sdk-logo',
      styles: Styles(
        width: size.px,
        height: size.px,
        raw: {'mask-image': "url('$_asset')", '-webkit-mask-image': "url('$_asset')"},
      ),
      attributes: const {'aria-hidden': 'true'},
      const [],
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.sdk-logo').styles(
      display: .inlineBlock,
      flex: const .shrink(0),
      raw: {
        'background-color': 'currentColor',
        '-webkit-mask-position': 'center',
        '-webkit-mask-repeat': 'no-repeat',
        '-webkit-mask-size': 'contain',
        'mask-position': 'center',
        'mask-repeat': 'no-repeat',
        'mask-size': 'contain',
      },
    ),
  ];
}

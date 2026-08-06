// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr_content/theme.dart';

final colorPrimary = const ColorToken('primary', Color('#1B86F5'), dark: Color('#208FFD'));
final colorOnPrimary = const ColorToken('on-primary', Color('#000000'));
final colorSurface = const ColorToken('surface', Color('#F5F5F7'), dark: Color('#1D2834'));
final colorOnSurface = const ColorToken('on-surface', Color('#445F91'), dark: Color('#FFFFFF'));
final colorContainer = const ColorToken('container', Color('#FFFFFF'), dark: Color('#0C141D'));
final colorOnContainer = const ColorToken('on-container', Color('#000000'), dark: Color('#FFFFFF'));

final colorBorder = colorSurface;
final colorOnSurfaceVariant = Color('#FF00FF');
final colorContainerLow = Color('#003300');
final colorContainerHigh = Color('#006600');
final colorInfo = Color('#FFFF00');

extension ColorHighlight on Color {
  Color highlight(Color overlay, double amount) {
    return Color('color-mix(in hsl, $value, ${overlay.value} ${amount * 100}%)');
  }
}

final colorError = const ColorToken('error', Color('#F44336'));
final colorWarning = const ColorToken('warning', Color('#FBC02C'), dark: Color('#FFEB3A'));

/// Global styles that establish the document-level application layout.
@css
List<StyleRule> get appStyles => [
  css('html, body').styles(
    width: 100.percent,
    height: 100.percent,
    padding: .zero,
    margin: .zero,
    overflow: .hidden,
    color: colorOnSurface,
    fontFamily: const .list([
      FontFamily('Inter'),
      FontFamily('Segoe UI'),
      FontFamilies.sansSerif,
    ]),
    backgroundColor: colorSurface,
  ),
  ...[
    colorPrimary,
    colorOnPrimary,
    colorSurface,
    colorOnSurface,
    colorContainer,
    colorOnContainer,
    colorError,
    colorWarning,
    colorBorder,
  ].build(),
];

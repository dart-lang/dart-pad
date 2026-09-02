// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr_content/theme.dart';

final colorPrimary = const ColorToken('primary', Color('#1B86F5'), dark: Color('#208FFD'));
final colorOnPrimary = const ColorToken('on-primary', Color('#FFFFFF'), dark: Color('#0C141D'));
final colorSurface = const ColorToken('surface', Color('#F5F5F7'), dark: Color('#1D2834'));
final colorOnSurface = const ColorToken('on-surface', Color('#445F91'), dark: Color('#FFFFFF'));
final colorContainer = const ColorToken('container', Color('#FFFFFF'), dark: Color('#0C141D'));
final colorOnContainer = const ColorToken('on-container', Color('#000000'), dark: Color('#FFFFFF'));

final colorBorder = colorSurface.highlight(colorOnSurface, 0.05);

extension ColorHighlight on Color {
  Color highlight(Color overlay, double amount) {
    return Color('color-mix(in hsl, $value, ${overlay.value} ${amount * 100}%)');
  }
}

final colorError = const ColorToken('error', Color('#F44336'));
final colorErrorSurface = const ColorToken('error-surface', Color('#FFEBE9'), dark: Color('#351f1f'));
final colorWarning = const ColorToken('warning', Color('#FBC02C'), dark: Color('#FFEB3A'));
final colorInfo = const ColorToken('info', Color('#208FFD'));
final colorSuccess = const ColorToken('success', Color('#4CAF50'));

/// Global styles that establish the document-level application layout.
@css
List<StyleRule> get appStyles => [
  css('html[data-theme="dark"]').styles(
    raw: {'color-scheme': 'dark'},
  ),
  css('html[data-theme="light"]').styles(
    raw: {'color-scheme': 'light'},
  ),
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
    colorErrorSurface,
    colorWarning,
    colorInfo,
    colorSuccess,
  ].build(),
];

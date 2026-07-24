// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';

import 'component_styles.dart';

const colorPrimary = Color.variable('--color-primary');
const colorOnPrimary = Color.variable('--color-on-primary');
const colorSurface = Color.variable('--color-surface');
const colorOnSurface = Color.variable('--color-on-surface');
const colorOnSurfaceVariant = Color.variable('--color-on-surface-variant');
const colorContainer = Color.variable('--color-container');
const colorContainerLow = Color.variable('--color-container-low');
const colorContainerHigh = Color.variable('--color-container-high');
const colorBorder = Color.variable('--color-border');

const colorError = Color.variable('--color-error');
const colorWarning = Color.variable('--color-warning');
const colorSuccess = Color.variable('--color-success');
const colorInfo = Color.variable('--color-info');
const colorPurple = Color.variable('--color-purple');
const colorGray = Color.variable('--color-gray');

/// Global styles that establish the document-level application layout.
@css
List<StyleRule> get appStyles => [
  css('html, body').styles(
    width: 100.percent,
    height: 100.percent,
    padding: .zero,
    margin: .zero,
    overflow: .hidden,
    color: const Color('#d4d4d4'),
    fontFamily: const .list([
      FontFamily('Inter'),
      FontFamily('Segoe UI'),
      FontFamilies.sansSerif,
    ]),
    backgroundColor: const Color('#1e1e1e'),
  ),
  css(':root').styles(
    raw: {
      '--color-primary': '#4285f4', // Google Blue
      '--color-on-primary': '#ffffff',
      '--color-surface': '#121212', // Dark background
      '--color-on-surface': '#f5f5f5', // White foreground
      '--color-on-surface-variant': '#9e9e9e', // Muted text
      '--color-container': '#1e1e1e', // Panels, editor container, etc.
      '--color-container-low': '#161616', // Sidebar, tabs bg
      '--color-container-high': '#2a2a2a', // Buttons, active items, hover
      '--color-border': '#2d2d2d',
      '--color-error': '#ea4335', // Google Red
      '--color-warning': '#fbbc05', // Google Yellow
      '--color-success': '#34a853', // Google Green
      '--color-info': '#4285f4', // Google Blue
    },
  ),
  ...componentStyles,
];

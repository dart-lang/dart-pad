// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

const Duration tooltipDelay = Duration(milliseconds: 350);

const Duration animationDelay = Duration(milliseconds: 180);
const Curve animationCurve = Curves.ease;

const double defaultIconSize = 24.0;
const double defaultSplashRadius = defaultIconSize;

const double smallIconSize = 20.0;

const double defaultSpacing = 16.0;
const double denseSpacing = 8.0;

const double toolbarHeight = 32.0;

const double toolbarItemHeight = 40.0;

Color lightPrimaryColor = const Color(0xff1967D2);
Color lightSurfaceColor = const Color(0xFFF5F5F7);

Color darkPrimaryColor = const Color(0xFF1c2834);
Color darkSurfaceColor = const Color(0xFF1c2834);
Color darkScaffoldColor = const Color(0xFF0C141D);

const Color subtleColor = Colors.grey;

// TODO: Look into using ThemeData in places where we're currently using
// subtleText.
const TextStyle subtleText = TextStyle(color: subtleColor);

const defaultGripSize = denseSpacing;

extension ColorSchemeExtension on ColorScheme {
  bool get darkMode => brightness == Brightness.dark;

  Color get backgroundColor => darkMode ? surface : primary;
}

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
Color lightSurfaceVariantColor = const Color(0xFFECECF1);
Color lightDividerColor = const Color(0xFFDCE2E8);
Color lightLinkButtonColor = lightPrimaryColor;
Color lightErrorColor = Colors.red.shade400;
Color lightWarningColor = Colors.yellow.shade700;
Color lightInfoColor = Colors.blue.shade400;
Color lightIssueColor = Colors.grey.shade400;

Color darkPrimaryColor = const Color(0xFF1c2834);
Color darkSurfaceColor = const Color(0xFF1C2834);
Color darkSurfaceVariantColor = const Color(0xFF2B3B4F);
Color darkDividerColor = const Color(0xFF1C2834);
Color darkScaffoldColor = const Color(0xFF0C141D);
Color darkLinkButtonColor = Colors.white;
Color darkErrorColor = Colors.red.shade500;
Color darkWarningColor = Colors.yellow.shade500;
Color darkInfoColor = Colors.blue.shade500;
Color darkIssueColor = Colors.grey.shade700;

Color runButtonColor = const Color(0xFF168afd);

const Color subtleColor = Colors.grey;

// TODO: Look into using ThemeData in places where we're currently using
// subtleText.
const TextStyle subtleText = TextStyle(color: subtleColor);

const defaultGripSize = denseSpacing;

extension ColorSchemeExtension on ColorScheme {
  bool get darkMode => brightness == Brightness.dark;

  Color get backgroundColor => darkMode ? surface : primary;
}

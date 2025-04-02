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

const Color lightPrimaryColor = Color(0xff1967D2);
const Color lightSurfaceColor = Color(0xFFF5F5F7);
const Color lightSurfaceVariantColor = Color(0xFFECECF1);
const Color lightDividerColor = Color(0xFFDCE2E8);
const Color lightLinkButtonColor = lightPrimaryColor;
final Color lightErrorColor = Colors.red.shade400;
final Color lightWarningColor = Colors.yellow.shade700;
final Color lightInfoColor = Colors.blue.shade400;
final Color lightIssueColor = Colors.grey.shade400;

const Color darkPrimaryColor = Color(0xFF1c2834);
const Color darkSurfaceColor = Color(0xFF1C2834);
const Color darkSurfaceVariantColor = Color(0xFF2B3B4F);
const Color darkDividerColor = Color(0xFF1C2834);
const Color darkScaffoldColor = Color(0xFF0C141D);
const Color darkLinkButtonColor = Colors.white;
final Color darkErrorColor = Colors.red.shade500;
final Color darkWarningColor = Colors.yellow.shade500;
final Color darkInfoColor = Colors.blue.shade500;
final Color darkIssueColor = Colors.grey.shade700;

const Color runButtonColor = Color(0xFF168afd);

const Color subtleColor = Colors.grey;

// TODO: Look into using ThemeData in places where we're currently using
// subtleText.
const TextStyle subtleText = TextStyle(color: subtleColor);

const defaultGripSize = denseSpacing;

extension ColorSchemeExtension on ColorScheme {
  bool get darkMode => brightness == Brightness.dark;

  Color get backgroundColor => darkMode ? surface : primary;
}

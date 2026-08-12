// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_interop';
// ignore: implementation_imports
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:jaspr/dom.dart' as jsp;
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';

/// The custom theme definition and observer for the DartPad Inspector.
class DartPadInspectorTheme {
  DartPadInspectorTheme({required this.onThemeChanged}) {
    _isDark = web.document.documentElement?.getAttribute('data-theme') == 'dark';
    preferences.darkModeEnabled.value = _isDark;

    _observer = web.MutationObserver(
      (JSArray<web.MutationRecord> mutations, web.MutationObserver observer) {
        final isDark = web.document.documentElement?.getAttribute('data-theme') == 'dark';
        if (isDark != _isDark) {
          _isDark = isDark;
          preferences.darkModeEnabled.value = isDark;
          onThemeChanged(isDark);
        }
      }.toJS,
    );

    _observer.observe(
      web.document.documentElement!,
      web.MutationObserverInit(
        attributes: true,
        attributeFilter: ['data-theme'.toJS].toJS,
      ),
    );
  }

  final void Function(bool isDark) onThemeChanged;
  late final web.MutationObserver _observer;
  late bool _isDark;

  bool get isDark => _isDark;

  void dispose() {
    _observer.disconnect();
  }

  static IdeTheme ideTheme({required bool isDark, required IdeTheme baseIdeTheme}) {
    return IdeTheme(
      backgroundColor: isDark ? colorContainer.dark!.toFlutterColor() : colorContainer.light.toFlutterColor(),
      foregroundColor: baseIdeTheme.foregroundColor,
      embedMode: baseIdeTheme.embedMode,
      isDarkMode: isDark,
    );
  }

  static ThemeData theme({required bool isDark, required IdeTheme baseIdeTheme}) {
    final customIdeTheme = ideTheme(isDark: isDark, baseIdeTheme: baseIdeTheme);
    return themeFor(
      isDarkTheme: isDark,
      ideTheme: customIdeTheme,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: isDark ? darkColorScheme : lightColorScheme,
      ),
    );
  }
}

extension ColorExtension on jsp.Color {
  Color toFlutterColor() {
    // Parse the hex color string and create a Color object
    // This assumes the string is in the format "#RRGGBB" or "#RGB"
    final hex = value.startsWith('#') ? value.substring(1) : value;
    final intValue = int.parse(hex, radix: 16);

    Color color;
    if (hex.length == 6) {
      color = Color(
        0xFF000000 | intValue, // Set alpha to FF (opaque)
      );
    } else if (hex.length == 8) {
      color = Color(intValue);
    } else {
      throw FormatException('Invalid hex color format: $this');
    }

    return color;
  }
}

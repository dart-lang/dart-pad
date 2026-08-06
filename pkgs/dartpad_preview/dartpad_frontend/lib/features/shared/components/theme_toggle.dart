// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import 'icon_button.dart';

/// A theme toggle button.
class ThemeToggle extends StatefulComponent {
  const ThemeToggle({super.key});

  @override
  State createState() => ThemeToggleState();
}

class ThemeToggleState extends State<ThemeToggle> {
  bool isDark = false;

  @override
  void initState() {
    super.initState();

    isDark = web.document.documentElement!.getAttribute('data-theme') == 'dark';
  }

  @override
  Component build(BuildContext context) {
    return Component.fragment([
      Document.html(attributes: {'data-theme': isDark ? 'dark' : 'light'}),
      IconButton(
        icon: !isDark ? 'dark_mode' : 'light_mode',
        tooltip: 'Toggle Theme',
        label: 'Theme Toggle',
        onClick: (_) {
          setState(() {
            isDark = !isDark;
          });
          web.window.localStorage.setItem('dartpad:theme', isDark ? 'dark' : 'light');
        },
      ),
    ]);
  }
}

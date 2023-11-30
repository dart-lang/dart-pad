// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

bool get _mac => defaultTargetPlatform == TargetPlatform.macOS;
bool get _nonMac => defaultTargetPlatform != TargetPlatform.macOS;

// key activators

final ShortcutActivator reloadKeyActivator = SingleActivator(
  LogicalKeyboardKey.keyS,
  meta: _mac,
  control: _nonMac,
);
final ShortcutActivator findKeyActivator = SingleActivator(
  LogicalKeyboardKey.keyF,
  meta: _mac,
  control: _nonMac,
);
final ShortcutActivator findNextKeyActivator = SingleActivator(
  LogicalKeyboardKey.keyG,
  meta: _mac,
  control: _nonMac,
);
const ShortcutActivator codeCompletionKeyActivator = SingleActivator(
  LogicalKeyboardKey.space,
  control: true,
);
final ShortcutActivator quickFixKeyActivator = SingleActivator(
  LogicalKeyboardKey.period,
  meta: _mac,
  control: _nonMac,
);

// map of key activator names

final List<(String, ShortcutActivator)> keyBindings = [
  ('Code completion', codeCompletionKeyActivator),
  ('Find', findKeyActivator),
  ('Find next', findNextKeyActivator),
  ('Quick fixes', quickFixKeyActivator),
  ('Reload', reloadKeyActivator),
];

extension SingleActivatorExtension on SingleActivator {
  // Note that this only works in debug mode.
  String get describe => debugDescribeKeys();

  Widget renderToWidget(BuildContext context) {
    var text = trigger.keyLabel;
    if (trigger == LogicalKeyboardKey.space) {
      text = 'Space';
    }

    return Container(
      decoration: BoxDecoration(
          border: Border.fromBorderSide(
            Divider.createBorderSide(context, width: 1.0, color: subtleColor),
          ),
          borderRadius: const BorderRadius.all(Radius.circular(4))),
      padding: const EdgeInsets.symmetric(
        vertical: 2,
        horizontal: 6,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (control)
            const Icon(
              Icons.keyboard_control_key,
              size: 16,
              color: subtleColor,
            ),
          if (meta)
            const Icon(
              Icons.keyboard_command_key,
              size: 16,
              color: subtleColor,
            ),
          Text(text, style: subtleText),
        ],
      ),
    );
  }
}

// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../primitives/theme.dart';
import '../primitives/utils.dart';

// ## Key activators

final ShortcutActivator runKeyActivator1 = SingleActivator(
  LogicalKeyboardKey.keyR,
  meta: isMac,
  control: isNonMac,
);
final ShortcutActivator runKeyActivator2 = SingleActivator(
  LogicalKeyboardKey.enter,
  meta: isMac,
  control: isNonMac,
);

final ShortcutActivator formatKeyActivator1 = SingleActivator(
  LogicalKeyboardKey.keyS,
  meta: isMac,
  control: isNonMac,
);
const ShortcutActivator formatKeyActivator2 = SingleActivator(
  LogicalKeyboardKey.keyF,
  shift: true,
  alt: true,
);

const ShortcutActivator codeCompletionKeyActivator = SingleActivator(
  LogicalKeyboardKey.space,
  control: true,
);

final ShortcutActivator quickFixKeyActivator1 = SingleActivator(
  LogicalKeyboardKey.period,
  meta: isMac,
  control: isNonMac,
);
const ShortcutActivator quickFixKeyActivator2 = SingleActivator(
  LogicalKeyboardKey.enter,
  alt: true,
);

// ## Map of key activator names

final List<(String, List<ShortcutActivator>)> keyBindings = [
  ('Code completion', [codeCompletionKeyActivator]),
  // ('Find', [findKeyActivator]),
  // ('Find next', [findNextKeyActivator]),
  ('Format', [formatKeyActivator1, formatKeyActivator2]),
  ('Quick fixes', [quickFixKeyActivator1, quickFixKeyActivator2]),
  ('Run', [runKeyActivator1, runKeyActivator2]),
];

extension SingleActivatorExtension on SingleActivator {
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
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shift)
            const Icon(Icons.arrow_upward, size: 16, color: subtleColor),
          if (alt)
            Icon(
              isMac ? Icons.keyboard_option_key : Icons.keyboard_alt,
              size: 16,
              color: subtleColor,
            ),
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

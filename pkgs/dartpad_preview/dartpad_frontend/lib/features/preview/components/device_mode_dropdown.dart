// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';
import '../../shared/components/dropdown_menu.dart';
import '../../shared/icons.dart';
import '../models/device_mode.dart';

class DeviceModeDropdown extends StatelessComponent {
  const DeviceModeDropdown({
    required this.mode,
    required this.onModeSelected,
    this.disabled = false,
    super.key,
  });

  final DeviceMode mode;
  final ValueChanged<DeviceMode> onModeSelected;
  final bool disabled;

  @override
  Component build(BuildContext context) {
    return DropdownMenu(
      alignLeft: true,
      disabled: disabled,
      trigger: button(
        classes: 'device-dropdown-trigger${disabled ? ' disabled' : ''}',
        attributes: disabled ? {'disabled': 'true'} : {},
        [
          Icon(mode.icon, size: 18.0),
          span(classes: 'device-dropdown-label', [.text(mode.title)]),
          const Icon('keyboard_arrow_down', size: 16.0),
        ],
      ),
      items: [
        for (final m in DeviceMode.values)
          DropdownMenuItem(
            label: m.title,
            leadingIcon: m.icon,
            isSelected: m == mode,
            onPressed: () => onModeSelected(m),
          ),
      ],
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.device-dropdown-trigger').styles(
      display: .flex,
      height: 28.px,
      padding: .symmetric(horizontal: 8.px),
      border: .none,
      radius: .circular(4.px),
      cursor: .pointer,
      transition: Transition('background-color', duration: 150.ms, curve: .ease),
      justifyContent: .center,
      alignItems: .center,
      gap: Gap.all(6.px),
      color: colorOnSurface,
      whiteSpace: .noWrap,
      backgroundColor: Colors.transparent,
    ),
    css('.device-dropdown-trigger:not(.disabled):hover').styles(
      backgroundColor: colorContainer,
    ),
    css('.device-dropdown-trigger.disabled').styles(
      opacity: 0.5,
      cursor: .notAllowed,
    ),
    css('.device-dropdown-label').styles(
      color: colorOnSurface,
      fontSize: 13.px,
      fontWeight: .w500,
    ),
  ];
}

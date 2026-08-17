// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../../shared/icons.dart';
import '../models/device_mode.dart';

class DeviceModeDropdown extends StatefulComponent {
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
  State<DeviceModeDropdown> createState() => _DeviceModeDropdownState();

  @css
  static List<StyleRule> get styles => _DeviceModeDropdownState.styles;
}

class _DeviceModeDropdownState extends State<DeviceModeDropdown> {
  bool _isOpen = false;
  StreamSubscription<web.MouseEvent>? _clickOutsideSubscription;

  void _toggleDropdown(web.Event event) {
    event.stopPropagation(); // prevent immediate close from clicking the trigger itself
    setState(() {
      _isOpen = !_isOpen;
    });

    if (_isOpen) {
      _listenForClickOutside();
    } else {
      _cancelListenForClickOutside();
    }
  }

  void _listenForClickOutside() {
    _clickOutsideSubscription?.cancel();
    _clickOutsideSubscription = web.EventStreamProviders.clickEvent.forTarget(web.document).listen((e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isOpen = false;
      });
      _cancelListenForClickOutside();
    });
  }

  void _cancelListenForClickOutside() {
    _clickOutsideSubscription?.cancel();
    _clickOutsideSubscription = null;
  }

  @override
  void dispose() {
    _cancelListenForClickOutside();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final currentMode = component.mode;
    final disabled = component.disabled;

    return div(classes: 'device-dropdown-container', [
      button(
        classes: 'device-dropdown-trigger${disabled ? ' disabled' : ''}',
        attributes: disabled ? {'disabled': 'true'} : {},
        events: disabled ? {} : {'click': _toggleDropdown},
        [
          Icon(currentMode.icon, size: 18.0),
          span(classes: 'device-dropdown-label', [.text(currentMode.title)]),
          const Icon('keyboard_arrow_down', size: 16.0),
        ],
      ),
      if (_isOpen)
        div(classes: 'device-dropdown-menu', [
          for (final mode in DeviceMode.values)
            div(
              classes: 'device-dropdown-item${mode == currentMode ? ' active' : ''}',
              events: {
                'click': (e) {
                  component.onModeSelected(mode);
                  setState(() {
                    _isOpen = false;
                  });
                  _cancelListenForClickOutside();
                },
              },
              [
                Icon(mode.icon, size: 18.0),
                span([.text(mode.title)]),
              ],
            ),
        ]),
    ]);
  }

  static List<StyleRule> get styles => [
    css('.device-dropdown-container', [
      css('&').styles(
        display: .inlineFlex,
        position: const .relative(),
      ),
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
      css('.device-dropdown-menu').styles(
        display: .flex,
        position: .absolute(top: 34.px, left: 0.px),
        zIndex: const ZIndex(100),
        minWidth: 180.px,
        padding: .symmetric(vertical: 4.px),
        border: .all(color: colorBorder, width: 1.px),
        radius: .circular(8.px),
        shadow: BoxShadow(
          offsetX: 0.px,
          offsetY: 8.px,
          blur: 24.px,
          color: Colors.black.withOpacity(0.5),
        ),
        backdropFilter: .blur(8.px),
        flexDirection: .column,
        backgroundColor: colorContainer,
      ),
      css('.device-dropdown-item').styles(
        display: .flex,
        padding: .symmetric(vertical: 8.px, horizontal: 12.px),
        cursor: .pointer,
        transition: .combine([
          Transition('background-color', duration: 100.ms, curve: .ease),
          Transition('color', duration: 100.ms, curve: .ease),
        ]),
        alignItems: .center,
        gap: .all(10.px),
        color: colorOnContainer,
        fontSize: 13.px,
        fontWeight: .w400,
      ),
      css('.device-dropdown-item:hover').styles(
        backgroundColor: colorContainer.highlight(colorOnContainer, 0.1),
      ),
      css('.device-dropdown-item.active').styles(
        backgroundColor: colorContainer.highlight(colorOnContainer, 0.2),
        fontWeight: .w500,
      ),
    ]),
  ];
}

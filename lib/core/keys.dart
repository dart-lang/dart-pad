// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library core.keys;

import 'dart:async';
import 'dart:html';

final _isMac = window.navigator.appVersion.toLowerCase().contains('macintosh');

/**
 * Map key events into commands.
 */
class Keys {
  Map<String, Function> _bindings = {};
  StreamSubscription _sub;

  Keys() {
    _sub = document.onKeyDown.listen(_handleKeyEvent);
  }

  void bind(String key, Function action) {
    _bindings[key] = action;
  }

  void dispose() {
    _sub.cancel();
  }

  void _handleKeyEvent(KeyboardEvent event) {
    KeyboardEvent k = event;

    if (k.keyCode < 27 || k.keyCode == 91) return;
    if (!k.altKey && !k.ctrlKey && !k.metaKey) return;
    if (!KeyCode.isCharacterKey(k.keyCode)) return;

    if (_handleKey(printKeyEvent(k))) {
      k.preventDefault();
      k.stopPropagation();
    }
  }

  bool _handleKey(String key) {
    Function action = _bindings[key];

    if (action != null) {
      Timer.run(action);
      return true;
    }

    return false;
  }
}

/**
 * Convert [event] into a string (e.g., `ctrl-s`).
 */
String printKeyEvent(KeyboardEvent event) {
  StringBuffer buf = new StringBuffer();

  // shift ctrl alt
  if (event.shiftKey) buf.write('shift-');
  if (event.ctrlKey) buf.write(_isMac ? 'macctrl-' : 'ctrl-');
  if (event.metaKey) buf.write(_isMac ? 'ctrl-' : 'meta-');
  if (event.altKey) buf.write('alt-');

  if (_codeMap.containsKey(event.keyCode)) {
    buf.write(_codeMap[event.keyCode]);
  } else {
    buf.write(event.keyCode.toString());
  }

  return buf.toString();
}

final Map _codeMap = {
  KeyCode.ZERO: '0',
  KeyCode.ONE: '1',
  KeyCode.TWO: '2',
  KeyCode.THREE: '3',
  KeyCode.FOUR: '4',
  KeyCode.FIVE: '5',
  KeyCode.SIX: '6',
  KeyCode.SEVEN: '7',
  KeyCode.EIGHT: '8',
  KeyCode.NINE: '9',

  KeyCode.A: 'a', //
  KeyCode.B: 'b', //
  KeyCode.C: 'c', //
  KeyCode.D: 'd', //
  KeyCode.E: 'e', //
  KeyCode.F: 'f', //
  KeyCode.G: 'g', //
  KeyCode.H: 'h', //
  KeyCode.I: 'i', //
  KeyCode.J: 'j', //
  KeyCode.K: 'k', //
  KeyCode.L: 'l', //
  KeyCode.M: 'm', //
  KeyCode.N: 'n', //
  KeyCode.O: 'o', //
  KeyCode.P: 'p', //
  KeyCode.Q: 'q', //
  KeyCode.R: 'r', //
  KeyCode.S: 's', //
  KeyCode.T: 't', //
  KeyCode.U: 'u', //
  KeyCode.V: 'v', //
  KeyCode.W: 'w', //
  KeyCode.X: 'x', //
  KeyCode.Y: 'y', //
  KeyCode.Z: 'z', //

  KeyCode.F1: 'f1', //
  KeyCode.F2: 'f2', //
  KeyCode.F3: 'f3', //
  KeyCode.F4: 'f4', //
  KeyCode.F5: 'f5', //
  KeyCode.F6: 'f6', //
  KeyCode.F7: 'f7', //
  KeyCode.F8: 'f8', //
  KeyCode.F9: 'f9', //
  KeyCode.F10: 'f10', //
  KeyCode.F11: 'f11', //
  KeyCode.F12: 'f12', //

  KeyCode.PERIOD: '.', //
  KeyCode.COMMA: ',', //
  KeyCode.SLASH: '/', //
  KeyCode.BACKSLASH: '\\', //

  KeyCode.OPEN_SQUARE_BRACKET: '[', //
  KeyCode.CLOSE_SQUARE_BRACKET: ']', //

  KeyCode.LEFT: 'left', //
  KeyCode.RIGHT: 'right', //
};

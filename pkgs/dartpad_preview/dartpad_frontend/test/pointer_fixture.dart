// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:web/web.dart' as web;

/// Replays a touch tap, including the browser's compatibility mouse event.
void touchTap(web.HTMLButtonElement button) {
  button.dispatchEvent(web.PointerEvent('pointerenter', web.PointerEventInit(pointerType: 'touch')));
  button.dispatchEvent(web.PointerEvent('pointerdown', web.PointerEventInit(pointerType: 'touch', bubbles: true)));
  button.focus();
  button.dispatchEvent(web.PointerEvent('pointerup', web.PointerEventInit(pointerType: 'touch', bubbles: true)));
  button.dispatchEvent(web.PointerEvent('pointerleave', web.PointerEventInit(pointerType: 'touch')));
  button.dispatchEvent(web.MouseEvent('mouseenter'));
  button.dispatchEvent(web.PointerEvent('click', web.PointerEventInit(pointerType: 'touch', detail: 1, bubbles: true)));
}

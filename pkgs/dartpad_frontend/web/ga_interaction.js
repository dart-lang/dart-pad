// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Forward the first real interaction inside the preview to the embedding editor.
(() => {
  const events = ['pointerdown', 'pointerup', 'click', 'keydown'];

  function notifyParentInteraction(event) {
    if (!event.isTrusted) return;
    if (event.type === 'pointerdown' && event.pointerType === 'touch') return;
    for (const type of events) {
      window.removeEventListener(type, notifyParentInteraction, true);
    }
    if (window.parent !== window) {
      parent.postMessage(
        { 'sender': 'dartpad-analytics', 'type': 'interaction' },
        '*'
      );
    }
  }

  for (const type of events) {
    window.addEventListener(type, notifyParentInteraction, true);
  }
})();

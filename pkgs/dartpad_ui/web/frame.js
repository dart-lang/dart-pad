// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

function replaceJavaScript(value) {
  // Remove the old node.
  var oldNode = document.getElementById('compiled-script');
  if (oldNode && oldNode.parentNode) {
    oldNode.parentNode.removeChild(oldNode);
  }

  // Create a new node.
  var scriptNode = document.createElement('script');
  scriptNode.setAttribute('id', 'compiled-script');
  scriptNode.async = false;
  scriptNode.text = value;
  document.head.appendChild(scriptNode);
};

// Handles incoming messages.
function messageHandler(e) {
  var obj = e.data;

  if (obj.command === 'execute') {
    // TODO: Switch to using engineInitializer.initializeEngine(config). See
    // https://docs.flutter.dev/development/platform-integration/web/initialization.
    window.flutterConfiguration = {
      canvasKitBaseUrl: obj.canvasKitBaseUrl
    };

    replaceJavaScript(obj.js);
  }
};

window.addEventListener('load', function () {
  window.addEventListener('message', messageHandler, false);
  parent.postMessage({ 'sender': 'frame', 'type': 'ready' }, '*');
});

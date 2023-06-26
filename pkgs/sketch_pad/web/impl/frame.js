// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

replaceJavaScript = function (value) {
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

// Adds a script tag, with url as "src" and id as "id", unless a script tag with
// that id already exists.
//
// Executes onload after the script has loaded, if the script did not already
// exist, and executes onload immediately otherwise.
addScript = function (id, url, onload) {
  let existingScript = document.getElementById(id);
  if (existingScript && existingScript.parentNode) {
    if (onload !== undefined) {
      onload();
    }
    return;
  }

  let scriptNode = document.createElement('script');
  scriptNode.setAttribute('id', id);
  scriptNode.async = false;
  if (onload !== undefined) {
    scriptNode.onload = onload;
  }
  scriptNode.setAttribute('src', url);
  document.head.appendChild(scriptNode);
}

// Executes userJs, a user script, after first loading RequireJS.
executeWithRequireJs = function (userJs) {
  addScript('require', 'require.js', function () {
    // User script must be added after RequireJS loads.
    replaceJavaScript(userJs);
  });
}

// Handles any incoming messages.
//
// In particular, understands the following commands: 'execute'.
messageHandler = function (e) {
  var obj = e.data;
  var command = obj.command;
  var body = document.body;

  if (command === 'execute') {
    replaceJavaScript(obj.js);
  }
};

window.addEventListener('load', function () {
  window.addEventListener('message', messageHandler, false);
  parent.postMessage({ 'sender': 'frame', 'type': 'ready' }, '*');
});

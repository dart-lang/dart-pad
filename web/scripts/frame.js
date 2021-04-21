/**
 * Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
 * for details. All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

replaceJavaScript = function (value) {
    // Remove the old node.
    var oldNode = document.getElementById('compiledJsScript');
    if (oldNode && oldNode.parentNode) {
        oldNode.parentNode.removeChild(oldNode);
    }

    // Create a new node.
    var scriptNode = document.createElement('script');
    scriptNode.setAttribute('id', 'compiledJsScript');
    scriptNode.async = false;
    scriptNode.text = value;
    document.head.appendChild(scriptNode);
};

addScript = function (id, url, onload) {
    let existingScript = document.getElementById(id);
    if (existingScript && existingScript.parentNode) {
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

removeScript = function (id) {
    let existingScript = document.getElementById(id);
    if (existingScript && existingScript.parentNode) {
        existingScript.parentNode.removeChild(existingScript);
    }
}

addFirebase = function () {
    addScript('firebase-app', 'https://www.gstatic.com/firebasejs/8.4.1/firebase-app.js');
    addScript('firebase-auth', 'https://www.gstatic.com/firebasejs/8.4.1/firebase-auth.js');
    addScript('firestore', 'https://www.gstatic.com/firebasejs/8.4.1/firebase-firestore.js');
}

removeFirebase = function () {
    removeScript('firebase-app');
    removeScript('firebase-auth');
    removeScript('firestore');
}

messageHandler = function (e) {
    var obj = e.data;
    var command = obj.command;
    var body = document.body;

    if (command === 'setCss') {
        document.getElementById('styleId').innerHTML = obj.css;
    } else if (command === 'setHtml') {
        body.innerHTML = obj.html;
    } else if (command === 'execute') {
        // Replace HTML, CSS, possible Firebase JS, require.js, and app.
        body.innerHTML = obj.html;
        document.getElementById('styleId').innerHTML = obj.css;
        if (obj.addFirebase) {
            addFirebase();
        } else {
            removeFirebase();
        }
        // Require.js must be added _after_ the Firebase JS.
        addScript('require', 'require.js', function () {
            replaceJavaScript(obj.js);
        });
    }
};

window.addEventListener('load', function () {
    window.addEventListener('message', messageHandler, false);
    parent.postMessage({ 'sender': 'frame', 'type': 'ready' }, '*');
});

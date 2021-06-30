/**
 * Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
 * for details. All rights reserved. Use of this source code is governed by a
 * BSD-style license that can be found in the LICENSE file.
 */

replaceJavaScript = function (value) {
    // Remove canvaskit from this page, This can be removed when this PR lands
    // in dart-services:
    // https://github.com/flutter/engine/pull/26059
    removeCanvaskit();

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

/**
 * Adds a script tag, with url as "src" and id as "id", unless a script tag with
 * that id already exists.
 *
 * Executes onload after the script has loaded, if the script did not already
 * exist, and executes onload immediately otherwise.
 */
addScript = function (id, url, onload) {
    let existingScript = document.getElementById(id);
    if (existingScript && existingScript.parentNode) {
        onload();
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

removeCanvaskit = function () {
    var scripts = document.head.querySelectorAll('script');
    for (var i = 0; i < scripts.length; i++) {
        var script = scripts[i];
        if (script.src.includes('canvaskit.js')) {
            script.parentNode.removeChild(script);
            return;
        }
    }
}

executeWithFirebase = function (userJs) {
    let existingFirebase = document.getElementById('firebase-app');
    if (existingFirebase) {
        // Keep existing RequireJS and Firebase.
        replaceJavaScript(userJs);
    } else {
        // RequireJS must be added _after_ the Firebase JS. If a previous
        // execution added RequireJS, then we must first remove it.
        removeScript('require');
        addFirebase();
        // RequireJS must be added _after_ the Firebase JS.
        addScript('require', 'require.js', function () {
            // User script must be added after RequireJS loads.
            replaceJavaScript(userJs);
        });
    }
}

/**
 * Executes userJs, a user script, after first loading RequireJS.
 */
executeWithRequireJs = function (userJs) {
    addScript('require', 'require.js', function () {
        // User script must be added after RequireJS loads.
        replaceJavaScript(userJs);
    });
}

/**
 * Handles any incoming messages.
 *
 * In particular, understands the following commands on e: 'setCss', 'setHtml',
 * and 'execute'.
 */
messageHandler = function (e) {
    var obj = e.data;
    var command = obj.command;
    var body = document.body;

    if (command === 'setCss') {
        document.getElementById('styleId').innerHTML = obj.css;
    } else if (command === 'setHtml') {
        body.innerHTML = obj.html;
    } else if (command === 'execute') {
        // Replace HTML, CSS, possible Firebase JS, RequireJS, and app.
        body.innerHTML = obj.html;
        document.getElementById('styleId').innerHTML = obj.css;
        if (obj.addFirebaseJs) {
            executeWithFirebase(obj.js);
        } else if (obj.addRequireJs) {
            executeWithRequireJs(obj.js);
        } else {
            replaceJavaScript(obj.js);
        }
    }
};

window.addEventListener('load', function () {
    window.addEventListener('message', messageHandler, false);
    parent.postMessage({ 'sender': 'frame', 'type': 'ready' }, '*');
});

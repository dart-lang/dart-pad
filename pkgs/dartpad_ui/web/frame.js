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
}

// Handles incoming messages.
function messageHandler(e) {
  var obj = e.data;
  if (window.origin !== 'null' || e.source !== window.parent) return;
  if (obj.command === 'execute') {
    runFlutterApp(obj.js, obj.canvasKitBaseUrl, false);
  } else if (obj.command === 'executeReload') {
    runFlutterApp(obj.js, obj.canvasKitBaseUrl, true);
  }
}

// Used by the bootstrapped flutter script to report Flutter errors to DartPad
// separately from console output.
function reportFlutterError(e) {
  parent.postMessage({
    'sender': 'frame',
    'type': 'stderr',
    'message': e
  }, '*');
}

function runFlutterApp(compiledScript, canvasKitBaseUrl, reload) {
  var blob = new Blob([compiledScript], { type: 'text/javascript' });
  var url = URL.createObjectURL(blob);
  if (reload) {
    dartDevEmbedder.hotReload([url], ['package:dartpad_sample/main.dart']).then(function () {
      if (dartDevEmbedder.debugger.extensionNames.includes('ext.flutter.reassemble')) {
        dartDevEmbedder.debugger.invokeExtension('ext.flutter.reassemble', '{}');
      }
    });
    return;
  }
  _flutter.loader.loadEntrypoint({
    entrypointUrl: url,
    onEntrypointLoaded: async function (engineInitializer) {
      let appRunner = await engineInitializer.initializeEngine({
        canvasKitBaseUrl: canvasKitBaseUrl,
        assetBase: 'frame/',
      });
      appRunner.runApp();
    }
  });
}

window.addEventListener('load', function () {
  window.addEventListener('message', messageHandler, false);
  parent.postMessage({ 'sender': 'frame', 'type': 'ready' }, '*');
});

window.addEventListener('blur', onBlurHandler);

// Blur listener
const flutterViewSelector = 'flutter-view';
function onBlurHandler(event) {
  console.log('onBlur');
  const activeElement = document.activeElement;
  if (!activeElement) {
    return;
  }
  if (!(activeElement instanceof HTMLElement) || typeof activeElement.closest !== 'function') {
    return;
  }
  const inFlutterView = activeElement.closest(flutterViewSelector) !== null;
  console.log(`JS inFlutterView = ${inFlutterView}`);

  if (inFlutterView) {
    console.log('JS activeElement = ', activeElement);
    activeElement.blur();
  }
}

function addBlurListener() {
  window.addEventListener('blur', onBlurHandler);
  console.log('JS Blur listener added.');
}
function removeBlurListener() {
  window.removeEventListener('blur', onBlurHandler);
  console.log('JS Blur listener removed.');
}
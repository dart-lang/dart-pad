// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../model.dart';

class ExecutionServiceImpl implements ExecutionService {
  final StreamController<String> _stdoutController =
      StreamController<String>.broadcast();
  final StreamController<String> _stderrController =
      StreamController<String>.broadcast();

  web.HTMLIFrameElement _frame;
  late String _frameSrc;
  Completer<void> _readyCompleter = Completer();

  ExecutionServiceImpl(this._frame) {
    _frameSrc = _frame.src;
    _initListener();
  }

  @override
  Future<void> execute(
    String javaScript, {
    String? modulesBaseUrl,
    String? engineVersion,
    required bool reload,
    required bool isNewDDC,
    required bool isFlutter,
  }) async {
    if (!reload) {
      await _reset();
    }

    return _send(reload ? 'executeReload' : 'execute', {
      'js': _decorateJavaScript(javaScript,
          modulesBaseUrl: modulesBaseUrl,
          isNewDDC: isNewDDC,
          reload: reload,
          isFlutter: isFlutter),
      if (engineVersion != null)
        'canvasKitBaseUrl': _canvasKitUrl(engineVersion),
    });
  }

  @override
  Stream<String> get onStdout => _stdoutController.stream;

  @override
  Stream<String> get onStderr => _stderrController.stream;

  @override
  set ignorePointer(bool ignorePointer) {
    _frame.style.pointerEvents = ignorePointer ? 'none' : 'auto';
  }

  @override
  Future<void> reset() => _reset();

  @override
  Future<void> tearDown() => _reset();

  String _decorateJavaScript(String javaScript,
      {String? modulesBaseUrl,
      required bool isNewDDC,
      required bool reload,
      required bool isFlutter}) {
    if (reload) return javaScript;

    final script = StringBuffer();

    if (isNewDDC) {
      // Redirect print messages to the host.
      script.writeln('''
function dartPrint(message) {
  // NOTE: runtime errors seem to be routed here and not to window.onerror
  let isError = (new Error()).stack.includes('FlutterError.reportError');
  parent.postMessage({
    'sender': 'frame',
    'type': isError ? 'stderr' : 'stdout',
    'message': message.toString(),
  }, '*');
}
''');

      // The JavaScript exception handling for DartPad catches both errors
      // directly raised by `main()` (in which case we might have useful Dart
      // exception information we don't want to discard), as well as errors
      // generated by other means, like assertion errors when starting up
      // asynchronous functions.
      script.writeln('''
window.onerror = function(message, url, line, column, error) {
  var errorMessage = error == null ? '' : ', error: ' + error;
  parent.postMessage({
    'sender': 'frame',
    'type': 'stderr',
    'message': message + errorMessage
  }, '*');
};
''');

      // Set the crossorigin: anonymous attribute on require.js scripts.
      // For example, dart_sdk.js or flutter_web.js.
      if (modulesBaseUrl != null) {
        script.writeln('''
require.config({
  "baseUrl": "$modulesBaseUrl",
  "waitSeconds": 60,
  "onNodeCreated": function(node, config, id, url) { node.setAttribute('crossorigin', 'anonymous'); }
});
''');
      }

      // The code depends on ddc_module_loader already being loaded in the page.
      // Wrap in a function that we'll call after the module loader is loaded.
      script.writeln('let __ddcInitCode = function() {$javaScript}');

      script.writeln('''
function contextLoaded() {
  __ddcInitCode();
  dartDevEmbedder.runMain('package:dartpad_sample/bootstrap.dart', {});
}''');
      if (isFlutter) {
        script.writeln(
            'require(["dart_sdk_new", "flutter_web_new", "ddc_module_loader"], contextLoaded);');
      } else {
        script.writeln(
            'require(["dart_sdk_new", "ddc_module_loader"], contextLoaded);');
      }
    } else {
      // Redirect print messages to the host.
      script.writeln('''
function dartPrint(message) {
  // NOTE: runtime errors seem to be routed here and not to window.onerror
  let isError = (new Error()).stack.includes('FlutterError.reportError');
  parent.postMessage({
    'sender': 'frame',
    'type': isError ? 'stderr' : 'stdout',
    'message': message.toString()
  }, '*');
}
''');

      script.writeln('''
// Unload any previous version.
require.undef('dartpad_main');
''');

      // The JavaScript exception handling for DartPad catches both errors
      // directly raised by `main()` (in which case we might have useful Dart
      // exception information we don't want to discard), as well as errors
      // generated by other means, like assertion errors when starting up
      // asynchronous functions.
      script.writeln('''
window.onerror = function(message, url, line, column, error) {
  var errorMessage = error == null ? '' : ', error: ' + error;
  parent.postMessage({
    'sender': 'frame',
    'type': 'stderr',
    'message': message + errorMessage
  }, '*');
};
''');

      // Set the crossorigin: anonymous attribute on require.js scripts.
      // For example, dart_sdk.js or flutter_web.js.
      if (modulesBaseUrl != null) {
        script.writeln('''
require.config({
  "baseUrl": "$modulesBaseUrl",
  "waitSeconds": 60,
  "onNodeCreated": function(node, config, id, url) { node.setAttribute('crossorigin', 'anonymous'); }
});
''');
      }

      script.writeln(javaScript);

      script.writeln('''
require(['dart_sdk'],
  function(sdk) {
    'use strict';
    sdk.developer._extensions.clear();
    sdk.dart.hotRestart();
  }
);

require(["dartpad_main", "dart_sdk"], function(dartpad_main, dart_sdk) {
  // SDK initialization.
  dart_sdk.dart.setStartAsyncSynchronously(true);
  dart_sdk._isolate_helper.startRootIsolate(() => {}, []);

  // Loads the `dartpad_main` module and runs its bootstrapped main method.
  //
  // The loop below iterates over the properties of the exported object,
  // looking for one that ends in "bootstrap". Once found, it executes the
  // bootstrapped main method, which calls the user's main method, which
  // (presumably) calls runApp and starts Flutter's rendering.
  for (var prop in dartpad_main) {
    if (prop.endsWith("bootstrap")) {
      dartpad_main[prop].main();
    }
  }
});
''');
    }

    return script.toString();
  }

  Future<void> _send(String command, Map<String, Object?> params) {
    // TODO: Use dartpad.dev instead of '*'?
    _frame.contentWindowCrossOrigin?.postMessage(
      {
        'command': command,
        ...params,
      }.jsify(),
      '*'.toJS,
    );
    return Future.value();
  }

  /// Destroy and reload the iframe.
  Future<void> _reset() {
    if (_frame.parentElement case final parentElement?) {
      _readyCompleter = Completer();

      final clone = _frame.cloneNode(false) as web.HTMLIFrameElement;
      clone.src = _frameSrc;

      parentElement.appendChild(clone);
      parentElement.removeChild(_frame);
      _frame = clone;
    }

    return _readyCompleter.future.timeout(const Duration(seconds: 1),
        onTimeout: () {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    });
  }

  void _initListener() {
    web.window.onMessage.forEach((event) {
      final data = event.data.dartify() as Map<Object?, Object?>;
      if (data['sender'] != 'frame') {
        return;
      }
      final type = data['type'] as String?;

      if (type == 'stderr') {
        // Ignore any exceptions before the iframe has completed
        // initialization.
        if (_readyCompleter.isCompleted) {
          _stderrController.add(data['message'] as String);
        }
      } else if (type == 'ready' && !_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      } else if (data['message'] != null) {
        _stdoutController.add(data['stack'] as String); // TODO(csells): REMOVE
        _stdoutController.add(data['message'] as String);
      }
    });
  }
}

String _canvasKitUrl(String engineSha) =>
    'https://www.gstatic.com/flutter-canvaskit/$engineSha/';

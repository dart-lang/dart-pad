// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

import '../model.dart';

class ExecutionServiceImpl implements ExecutionService {
  final StreamController<String> _stdoutController =
      StreamController<String>.broadcast();

  html.IFrameElement _frame;
  late String _frameSrc;
  Completer<void> _readyCompleter = Completer();

  ExecutionServiceImpl(this._frame) {
    final src = _frame.src;
    if (src == null) {
      throw StateError('invalid iframe src');
    }
    _frameSrc = src;

    _initListener();
  }

  @override
  Future<void> execute(
    String javaScript, {
    String? modulesBaseUrl,
    String? engineVersion,
  }) async {
    await _reset();

    return _send('execute', {
      'js': _decorateJavaScript(javaScript, modulesBaseUrl: modulesBaseUrl),
      if (engineVersion != null)
        'canvasKitBaseUrl': _canvasKitUrl(engineVersion),
    });
  }

  @override
  Stream<String> get onStdout => _stdoutController.stream;

  html.IFrameElement get frame => _frame;

  @override
  Future<void> reset() => _reset();

  @override
  Future<void> tearDown() => _reset();

  String _decorateJavaScript(String javaScript, {String? modulesBaseUrl}) {
    final script = StringBuffer();

    // Redirect print messages to the host.
    script.writeln('''
function dartPrint(message) {
  parent.postMessage({
    'sender': 'frame',
    'type': 'stdout',
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

    if (modulesBaseUrl != null) {
      script.writeln('''
require.config({
  "baseUrl": "$modulesBaseUrl",
  "waitSeconds": 60
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

    return script.toString();
  }

  Future<void> _send(String command, Map<String, Object?> params) {
    final message = {
      'command': command,
      ...params,
    };
    _frame.contentWindow!.postMessage(message, '*');
    return Future.value();
  }

  /// Destroy and reload the iframe.
  Future<void> _reset() {
    if (_frame.parent != null) {
      _readyCompleter = Completer();

      final clone = _frame.clone(false) as html.IFrameElement;
      clone.src = _frameSrc;

      final children = _frame.parent!.children;
      final index = children.indexOf(_frame);
      children.insert(index, clone);
      _frame.parent!.children.remove(_frame);
      _frame = clone;
    }

    return _readyCompleter.future.timeout(const Duration(seconds: 1),
        onTimeout: () {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    });
  }

  void _initListener() {
    html.window.addEventListener('message', (event) {
      if (event is html.MessageEvent) {
        final data = (event.data as Map).cast<String, dynamic>();
        if (data['sender'] != 'frame') {
          return;
        }
        final type = data['type'] as String?;

        if (type == 'stderr') {
          // Ignore any exceptions before the iframe has completed
          // initialization.
          if (_readyCompleter.isCompleted) {
            _stdoutController.add(data['message'] as String);
          }
        } else if (type == 'ready' && !_readyCompleter.isCompleted) {
          _readyCompleter.complete();
        } else if (data['message'] != null) {
          _stdoutController.add(data['message'] as String);
        }
      }
    }, false);
  }
}

String _canvasKitUrl(String engineSha) =>
    'https://www.gstatic.com/flutter-canvaskit/$engineSha/';

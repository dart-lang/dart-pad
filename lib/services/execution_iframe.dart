// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library execution_iframe;

import 'dart:async';
import 'dart:html';

import 'execution.dart';
export 'execution.dart';

class ExecutionServiceIFrame implements ExecutionService {
  final StreamController _stdoutController = new StreamController.broadcast();
  final StreamController _stderrController = new StreamController.broadcast();

  IFrameElement _frame;
  String _frameSrc;
  Completer _readyCompleter = new Completer();

  ExecutionServiceIFrame(this._frame) {
    _frameSrc = _frame.src;

    window.onMessage.listen((MessageEvent event) {
      String message = '${event.data}';

      if (message.startsWith('stderr: ')) {
        // Ignore any exceptions before the iframe has completed initialization.
        //
        if (_readyCompleter.isCompleted) {
          _stderrController.add(message.substring('stderr: '.length));
        }
      } else if (message == 'status: ready' && !_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      } else {
        _stdoutController.add(message);
      }
    });
  }

  IFrameElement get frame => _frame;

  Future execute(String html, String css, String javaScript) {
    return _reset().whenComplete(() {
      return _send('execute', {
        'html': html,
        'css': css,
        'js': _decorateJavaScript(javaScript)
      });
    });
  }

  void replaceHtml(String html) {
    _send('setHtml', {'html': html});
  }

  void replaceCss(String css) {
    _send('setCss', {'css': css});
  }

  String _decorateJavaScript(String javaScript) {
    final String postMessagePrint =
        "function dartPrint(message) { parent.postMessage(message, '*'); }";

    final String exceptionHandler =
        "window.onerror = function(message, url, lineNumber) { "
        "parent.postMessage('stderr: ' + message.toString(), '*'); };";

    return '${postMessagePrint}\n${exceptionHandler}\n${javaScript}';
  }

  Stream<String> get onStdout => _stdoutController.stream;

  Stream<String> get onStderr => _stderrController.stream;

  Future _send(String command, Map params) {
    Map m = {'command': command};
    m.addAll(params);
    frame.contentWindow.postMessage(m, '*');

    return new Future.value();
  }

  /// Destroy and re-load the iframe.
  Future _reset() {
    _readyCompleter = new Completer();

    IFrameElement clone = _frame.clone(false);
    clone.src = _frameSrc;

    List<Element> children = frame.parent.children;
    int index = children.indexOf(_frame);
    children.insert(index, clone);
    frame.parent.children.remove(_frame);
    _frame = clone;

    return _readyCompleter.future.timeout(
        new Duration(seconds: 1),
        onTimeout: () {
          if (!_readyCompleter.isCompleted) _readyCompleter.complete();
        });
  }
}

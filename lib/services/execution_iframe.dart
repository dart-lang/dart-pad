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

  final IFrameElement frame;

  ExecutionServiceIFrame(this.frame) {
    window.onMessage.listen((MessageEvent event) {
      String message = '${event.data}';

      if (message.startsWith('stderr: ')) {
        _stderrController.add(message.substring('stderr: '.length));
      } else {
        _stdoutController.add(message);
      }
    });
  }

  Future execute(String html, String css, String javaScript) {
    return _send('execute', {
      'html': html,
      'css': css,
      'js': _decorateJavaScript(javaScript)
    });
  }

  void replaceHtml(String html) {
    _send('setHtml', {'html': html});
  }

  void replaceCss(String css) {
    _send('setCss', {'css': css});
  }

  void replaceJavaScript(String js) {
    _send('setJavaScript', {'js': _decorateJavaScript(js)});
  }

  void reset() {
    // TODO: Destroy and re-load iframe.

  }

  String _decorateJavaScript(String javaScript) {
    final String postMessagePrint =
        "function dartPrint(message) { parent.postMessage(message, '*'); }";

    // TODO: Use a better encoding than 'stderr: '.
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
}

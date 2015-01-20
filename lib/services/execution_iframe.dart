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
    final String postMessagePrint =
        "function dartPrint(message) { parent.postMessage(message, '*'); }";

    // TODO: Use a better encoding than 'stderr: '.
    final String exceptionHandler =
        "window.onerror = function(message, url, lineNumber) { "
        "parent.postMessage('stderr: ' + message.toString(), '*'); };";

    replaceCss(css);
    replaceHtml(html);
    replaceJavaScript('${postMessagePrint}\n${exceptionHandler}\n${javaScript}');

    return new Future.value();
  }

  void replaceCss(String css) {
    _send('setCss', css);
  }

  void replaceHtml(String html) {
    _send('setHtml', html);
  }

  void replaceJavaScript(String js) {
    _send('setJavaScript', js);
  }

  void reset() {
    _send('reset');
  }

  Stream<String> get onStdout => _stdoutController.stream;

  Stream<String> get onStderr => _stderrController.stream;

  void _send(String command, [String data]) {
    Map m = {'command': command};
    if (data != null) m['data'] = data;
    frame.contentWindow.postMessage(m, '*');
  }
}

// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library execution_iframe;

import 'dart:async';
//import 'dart:convert' show JSON;
import 'dart:html';
import 'dart:js';

//import 'package:source_map_stack_trace/source_map_stack_trace.dart';
//import 'package:source_maps/source_maps.dart' as source_maps;
import 'package:stack_trace/stack_trace.dart';

import 'execution.dart';
export 'execution.dart';

class ExecutionServiceIFrame implements ExecutionService {
  final StreamController<String> _stdoutController =
      new StreamController.broadcast();
  final StreamController<ExecutionException> _stderrController =
      new StreamController.broadcast();

  IFrameElement _frame;
  String _frameSrc;

  Completer _readyCompleter = new Completer();

  String _sourceMap;

  ExecutionServiceIFrame(this._frame) {
    _frameSrc = _frame.src;

    _initListener();
  }

  IFrameElement get frame => _frame;

  Future execute(String html, String css, String javaScript, [String sourceMap]) {
    return _reset().whenComplete(() {
      this._sourceMap = sourceMap;
      return _send('execute', {
        'html': html,
        'css': css,
        'js': _decorateJavaScript(javaScript)
      });
    });
  }

  Future tearDown() => _reset();

  void replaceHtml(String html) {
    _send('setHtml', {'html': html});
  }

  void replaceCss(String css) {
    _send('setCss', {'css': css});
  }

  bool get hasSourceMap => _sourceMap != null;

  String revereStackTrace(String jsStackTrace) {
    if (_sourceMap == null) return null;

    Trace trace = new Trace.parse(jsStackTrace);
    Iterable<Frame> sanitizedFrames = trace.frames.reversed.skipWhile((Frame frame) {
      if (frame.member == '<fn>') return true;
      if (frame.uri.path.endsWith('frame.html')) return true;
      return false;
    });
    Trace sanitizedTrace = new Trace(new List.from(sanitizedFrames).reversed);
    return sanitizedTrace.toString().replaceAll('%3Canonymous%3E', '<compiled>');

    // Map m = JSON.decode(_sourceMap);
    // m['sources'] = [
    //   'file:/a.dart', 'file:/b.dart', 'file:/c.dart', 'file:/d.dart',
    //   'file:/e.dart', 'file:/f.dart', 'file:/g.dart', 'file:/h.dart',
    //   'file:/i.dart', 'file:/j.dart', 'file:/k.dart', 'file:/l.dart'
    // ];
    // source_maps.Mapping mapping = source_maps.parseJson(m);
    // StackTrace result = mapStackTrace(mapping, trace.vmTrace);
    // return result.toString();
  }

  String _decorateJavaScript(String javaScript) {
    final String postMessagePrint = '''
function dartPrint(message) {
  parent.postMessage(
    {'sender': 'frame', 'type': 'stdout', 'message': message.toString()}, '*');
}
''';

    final String exceptionHandler = '''
window.onerror = function(message, url, lineNumber, columnNumber, err) {
  // lineNumber, colNumber, err
  var data = message;

  if (err && err.stack) {
    parent.postMessage({
      'sender': 'frame',
      'type': 'stderr',
      'message': message.toString(),
      'lineNumber': lineNumber,
      'columnNumber': columnNumber,
      'stack': err.stack.toString()
    }, '*');
  } else {
    parent.postMessage(
      {'sender': 'frame', 'type': 'stderr', 'message': message.toString()}, '*');
  }
  return true;
};
''';

    return '${postMessagePrint}\n${exceptionHandler}\n${javaScript}';
  }

  Stream<String> get onStdout => _stdoutController.stream;

  Stream<ExecutionException> get onStderr => _stderrController.stream;

  Future _send(String command, Map params) {
    Map m = {'command': command};
    m.addAll(params);
    frame.contentWindow.postMessage(m, '*');
    return new Future.value();
  }

  /// Destroy and re-load the iframe.
  Future _reset() {
    _sourceMap = null;

    if (frame.parent != null) {
      _readyCompleter = new Completer();

      IFrameElement clone = _frame.clone(false);
      clone.src = _frameSrc;

      List<Element> children = frame.parent.children;
      int index = children.indexOf(_frame);
      children.insert(index, clone);
      frame.parent.children.remove(_frame);
      _frame = clone;
    }

    return _readyCompleter.future.timeout(
        new Duration(seconds: 1),
        onTimeout: () {
          if (!_readyCompleter.isCompleted) _readyCompleter.complete();
        });
  }

  void _initListener() {
    context['dartMessageListener'] = new JsFunction.withThis((_this, data) {
      String type = data['type'];

      if (type == 'stderr') {
        // Ignore any exceptions before the iframe has completed initialization.
        if (_readyCompleter.isCompleted) {
          ExecutionException ex = new ExecutionException(
              data['message'], data['lineNumber'], data['columnNumber'],
              data['stack']);
          _stderrController.add(ex);
        }
      } else if (type == 'ready' && !_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      } else {
        _stdoutController.add(data['message']);
      }
    });

//    window.onMessage.listen((MessageEvent event) {
//      Map data;
//
//      try {
//        // TODO: This throws in Safari and FireFox with the polymer polyfills active.
//        if (event.data is! Map) return;
//        data = event.data;
//        if (data['sender'] != 'frame') return;
//      } catch (e) {
//        print('${e}');
//
//        return;
//      }
//
//      String type = data['type'];
//
//      if (type == 'stderr') {
//        // Ignore any exceptions before the iframe has completed initialization.
//        if (_readyCompleter.isCompleted) {
//          _stderrController.add(data['message']);
//        }
//      } else if (type == 'ready' && !_readyCompleter.isCompleted) {
//        _readyCompleter.complete();
//      } else {
//        _stdoutController.add(data['message']);
//      }
//    });
  }
}

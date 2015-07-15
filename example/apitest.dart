// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services_server.apitest;

import 'dart:html';
import 'dart:convert' show JSON;
import '_dartpadsupportservices.dart' as support;
import 'package:codemirror/codemirror.dart';

void main() {
  setupAnalyze();
  setupCompile();
  setupComplete();
  setupDocument();
  setupFixes();
  setupVersion();
  setupExport();
  setupRetrieve();
}

void setupAnalyze() {
  String api = querySelector('#analyzeSection h3').text;

  CodeMirror editor = createEditor(querySelector('#analyzeSection .editor'));
  Element output = querySelector('#analyzeSection .output');
  ButtonElement button = querySelector('#analyzeSection button');
  button.onClick.listen((e) {
    invokePOST(api, editor.getDoc().getValue(), output);
  });
}

void setupCompile() {
  String api = querySelector('#compileSection h3').text;

  CodeMirror editor = createEditor(querySelector('#compileSection .editor'));
  Element output = querySelector('#compileSection .output');
  ButtonElement button = querySelector('#compileSection button');
  button.onClick.listen((e) {
    invokePOST(api, editor.getDoc().getValue(), output);
  });
}

void setupComplete() {
  String api = querySelector('#completeSection h3').text;

  CodeMirror editor = createEditor(querySelector('#completeSection .editor'));
  Element output = querySelector('#completeSection .output');
  Element offsetElement = querySelector('#completeSection .offset');
  ButtonElement button = querySelector('#completeSection button');
  button.onClick.listen((e) {
    invokePOST(api, editor.getDoc().getValue(), output, offset: _getOffset(editor));
  });
  offsetElement.text = 'offset ${_getOffset(editor)}';

  editor.onCursorActivity.listen((_) {
    offsetElement.text = 'offset ${_getOffset(editor)}';
  });
}

void setupDocument() {
  String api = querySelector('#documentSection h3').text;

  CodeMirror editor = createEditor(querySelector('#documentSection .editor'));
  Element output = querySelector('#documentSection .output');
  Element offsetElement = querySelector('#documentSection .offset');
  ButtonElement button = querySelector('#documentSection button');
  button.onClick.listen((e) {
    invokePOST(api, editor.getDoc().getValue(), output, offset: _getOffset(editor));
  });
  offsetElement.text = 'offset ${_getOffset(editor)}';

  editor.onCursorActivity.listen((_) {
    offsetElement.text = 'offset ${_getOffset(editor)}';
  });
}

void setupFixes() {
  String api = querySelector('#fixesSection h3').text;

  CodeMirror editor = createEditor(querySelector('#fixesSection .editor'));
  Element output = querySelector('#fixesSection .output');
  Element offsetElement = querySelector('#fixesSection .offset');
  ButtonElement button = querySelector('#fixesSection button');
  button.onClick.listen((e) {
    invokePOST(api, editor.getDoc().getValue(), output, offset: _getOffset(editor));
  });
  offsetElement.text = 'offset ${_getOffset(editor)}';

  editor.onCursorActivity.listen((_) {
    offsetElement.text = 'offset ${_getOffset(editor)}';
  });
}

void setupVersion() {
  String api = querySelector('#versionSection h3').text;

  Element output = querySelector('#versionSection .output');
  ButtonElement button = querySelector('#versionSection button');
  button.onClick.listen((e) {
    invokeGET(api, output);
  });
}

void setupExport() {
  String api = querySelector('#exportSection h3').text;
  CodeMirror editor = createEditor(querySelector('#exportSection .editor'));
  Element output = querySelector('#exportSection .output');
  ButtonElement button = querySelector('#exportSection button');
  button.onClick.listen((e) {
    support.PadSaveObject send = new support.PadSaveObject();
    send.dart = editor.getDoc().getValue();
    invokeSupportPOST(api, send, output);
  });
}

void setupRetrieve() {
  String api = querySelector('#retrieveSection h3').text;
  CodeMirror editor = createEditor(querySelector('#retrieveSection .editor'), defaultText: "");
  Element output = querySelector('#retrieveSection .output');
  ButtonElement button = querySelector('#retrieveSection button');
  button.onClick.listen((e) {
    support.PadSaveObject send = new support.PadSaveObject();
    send.dart = editor.getDoc().getValue();
    invokeSupportPOST(api, send, output);
  });
}

CodeMirror createEditor(Element element, {String defaultText}) {
  final Map options = {
    'tabSize': 2,
    'indentUnit': 2,
    'autoCloseBrackets': true,
    'matchBrackets': true,
    'theme': 'zenburn',
    'mode': 'dart',
    'value': defaultText == null ? _text: defaultText
  };

  CodeMirror editor = new CodeMirror.fromElement(element, options: options);
  editor.refresh();
  return editor;
}

void invokePOST(String api, String source, Element output, {int offset}) {
  Stopwatch timer = new Stopwatch()..start();
  String url = '${_uriBase}${api}';
  output.text = '';

  Map headers = {'Content-Type': 'application/json; charset=UTF-8'};

  Map m = {'source': source};
  if (offset != null) m['offset'] = offset;
  String data = JSON.encode(m); //new Uri(queryParameters: m).query;

  HttpRequest.request(url, method: 'POST', sendData: data,
                      requestHeaders: headers).then((HttpRequest r) {
    String response =
        '${r.status} ${r.statusText} - ${timer.elapsedMilliseconds}ms\n'
        '${_printHeaders(r.responseHeaders)}\n\n'
        '${r.responseText}';
    output.text = response;
  }).catchError((e, st) {
    if (e is Event && e.target is HttpRequest) {
      HttpRequest r = e.target;
      String response =
          '${r.status} ${r.statusText} - ${timer.elapsedMilliseconds}ms\n'
          '${_printHeaders(r.responseHeaders)}\n\n'
          '${r.responseText}';
      output.text = response;
    } else {
      output.text = '${e}\n${st}';
    }
  });
}

void invokeSupportPOST(String api, support.PadSaveObject pso, Element output, {int offset}) {
  Stopwatch timer = new Stopwatch()..start();
  String url = '${_uriBase}${api}';
  output.text = '';

  Map headers = {'Content-Type': 'application/json; charset=UTF-8'};
  
  //Does pso actually have to be a map?
  String data = JSON.encode(pso); //new Uri(queryParameters: m).query;

  HttpRequest.request(url, method: 'POST', sendData: data,
                      requestHeaders: headers).then((HttpRequest r) {
    String response =
        '${r.status} ${r.statusText} - ${timer.elapsedMilliseconds}ms\n'
        '${_printHeaders(r.responseHeaders)}\n\n'
        '${r.responseText}';
    output.text = response;
  }).catchError((e, st) {
    if (e is Event && e.target is HttpRequest) {
      HttpRequest r = e.target;
      String response =
          '${r.status} ${r.statusText} - ${timer.elapsedMilliseconds}ms\n'
          '${_printHeaders(r.responseHeaders)}\n\n'
          '${r.responseText}';
      output.text = response;
    } else {
      output.text = '${e}\n${st}';
    }
  });
}

void invokeDelete(String api, String key, Element output, {int offset}) {
  Stopwatch timer = new Stopwatch()..start();
  String url = '${_uriBase}${api}';
  output.text = '';

  Map headers = {'Content-Type': 'application/json; charset=UTF-8'};

  String data = JSON.encode(key); //new Uri(queryParameters: m).query;

  HttpRequest.request(url, method: 'DELETE', sendData: data,
                      requestHeaders: headers).then((HttpRequest r) {
    String response =
        '${r.status} ${r.statusText} - ${timer.elapsedMilliseconds}ms\n'
        '${_printHeaders(r.responseHeaders)}\n\n'
        '${r.responseText}';
    output.text = response;
  }).catchError((e, st) {
    if (e is Event && e.target is HttpRequest) {
      HttpRequest r = e.target;
      String response =
          '${r.status} ${r.statusText} - ${timer.elapsedMilliseconds}ms\n'
          '${_printHeaders(r.responseHeaders)}\n\n'
          '${r.responseText}';
      output.text = response;
    } else {
      output.text = '${e}\n${st}';
    }
  });
}

void invokeGET(String api, Element output) {
  Stopwatch timer = new Stopwatch()..start();
  String url = '${_uriBase}${api}';
  output.text = '';

  HttpRequest.request(url, method: 'GET').then((HttpRequest r) {
    String response =
        '${r.status} ${r.statusText} - ${timer.elapsedMilliseconds}ms\n'
        '${_printHeaders(r.responseHeaders)}\n\n'
        '${r.responseText}';
    output.text = response;
  }).catchError((e, st) {
    if (e is Event && e.target is HttpRequest) {
      HttpRequest r = e.target;
      String response =
          '${r.status} ${r.statusText} - ${timer.elapsedMilliseconds}ms\n'
          '${_printHeaders(r.responseHeaders)}\n\n'
          '${r.responseText}';
      output.text = response;
    } else {
      output.text = '${e}\n${st}';
    }
  });
}

String _printHeaders(Map m) {
  return m.keys.map((k) => '${k}: ${m[k]}').join('\n');
}

String get _uriBase => (querySelector('input[type=text]') as InputElement).value;

int _getOffset(CodeMirror editor) {
  Position pos = editor.getDoc().getCursor();
  return editor.getDoc().indexFromPos(pos);
}

final String _text = r'''
void main() {
  for (int i = 0; i < 4; i++) {
    print('hello ${i}');
  }
}
''';

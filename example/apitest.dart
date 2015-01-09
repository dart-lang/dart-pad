// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_server.apitest;

import 'dart:html';
import 'dart:convert' show JSON;

import 'package:codemirror/codemirror.dart';

void main() {
  setupAnalyze();
  setupCompile();
  setupComplete();
  setupDocument();
}

void setupAnalyze() {
  String api = querySelector('#analyzeSection h3').text;

  CodeMirror editor = createEditor(querySelector('#analyzeSection .editor'));
  Element output = querySelector('#analyzeSection .output');
  ButtonElement button = querySelector('#analyzeSection button');
  button.onClick.listen((e) {
    invoke(api, editor.getDoc().getValue(), output);
  });
}

void setupCompile() {
  String api = querySelector('#compileSection h3').text;

  CodeMirror editor = createEditor(querySelector('#compileSection .editor'));
  Element output = querySelector('#compileSection .output');
  ButtonElement button = querySelector('#compileSection button');
  button.onClick.listen((e) {
    invoke(api, editor.getDoc().getValue(), output);
  });
}

void setupComplete() {
  String api = querySelector('#completeSection h3').text;

  CodeMirror editor = createEditor(querySelector('#completeSection .editor'));
  Element output = querySelector('#completeSection .output');
  Element offsetElement = querySelector('#completeSection .offset');
  ButtonElement button = querySelector('#completeSection button');
  button.onClick.listen((e) {
    invoke(api, editor.getDoc().getValue(), output, offset: _getOffset(editor));
  });
  offsetElement.text = 'offset ${_getOffset(editor)}';

  editor.onCursorActivity.listen((_) {
    Position pos = editor.getCursor();
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
    invoke(api, editor.getDoc().getValue(), output, offset: _getOffset(editor));
  });
  offsetElement.text = 'offset ${_getOffset(editor)}';

  editor.onCursorActivity.listen((_) {
    Position pos = editor.getCursor();
    offsetElement.text = 'offset ${_getOffset(editor)}';
  });
}

CodeMirror createEditor(Element element) {
  final Map options = {
    'tabSize': 2,
    'indentUnit': 2,
    'autoCloseBrackets': true,
    'matchBrackets': true,
    'theme': 'zenburn',
    'mode': 'dart',
    'value': _text
  };

  CodeMirror editor = new CodeMirror.fromElement(element, options: options);
  editor.refresh();
  return editor;
}

void invoke(String api, String source, Element output, {int offset}) {
  Stopwatch timer = new Stopwatch()..start();
  String url = '${_uriBase}${api}';
  output.text = '';

  //Map headers = {'Content-Type': 'application/json; charset=UTF-8'};

  Map m = {'source': source};
  if (offset != null) m['offset'] = offset;
  String data = JSON.encode(m); //new Uri(queryParameters: m).query;

  HttpRequest.request(url, method: 'POST', sendData: data).then((HttpRequest r) {
    String response =
        '${r.status} ${r.statusText} - ${timer.elapsedMilliseconds}ms\n'
        '${r.responseHeaders}\n\n'
        '${r.responseText}';
    output.text = response;
  }).catchError((e, st) {
    if (e is Event && e.target is HttpRequest) {
      HttpRequest r = e.target;
      String response =
          '${r.status} ${r.statusText} - ${timer.elapsedMilliseconds}ms\n'
          '${r.responseHeaders}\n\n'
          '${r.responseText}';
      output.text = response;
    } else {
      output.text = '${e}\n${st}';
    }
  });
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

// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services_server.apitest;

import 'dart:convert';
import 'dart:html';
import 'package:codemirror/codemirror.dart';
import 'package:http/browser_client.dart';
import 'package:http/http.dart';
import 'services_utils.dart' as utils;

BrowserClient _client = utils.SanitizingBrowserClient();

void main() {
  setupAnalyze();
  setupAssists();
  setupCompile();
  setupCompileDDC();
  setupComplete();
  setupDocument();
  setupFixes();
  setupVersion();
}

Future<Response> post(String url, {String? body}) async {
  return _client.post(
    Uri.parse(url),
    body: body,
    encoding: utf8,
    headers: {'content-type': 'application/json'},
  );
}

Future<Response> get(String url) async {
  return _client.get(
    Uri.parse(url),
    headers: {'content-type': 'application/json'},
  );
}

void setupAnalyze() {
  final editor = createEditor(querySelector('#analyzeSection-v2 .editor')!);
  final output = querySelector('#analyzeSection-v2 .output')!;
  final button = querySelector('#analyzeSection-v2 button') as ButtonElement;
  button.onClick.listen((e) {
    final source = {'source': editor.doc.getValue()};
    final sw = Stopwatch()..start();
    post(
      '$_uriBase/dartservices/v2/analyze',
      body: json.encode(source),
    ).then((response) => output.text = '${_formatTiming(sw)}${response.body}');
  });
}

void setupAssists() {
  final editor = createEditor(querySelector('#assistsSection-v2 .editor')!);
  final output = querySelector('#assistsSection-v2 .output')!;
  final offsetElement = querySelector('#assistsSection-v2 .offset')!;
  final button = querySelector('#assistsSection-v2 button') as ButtonElement;
  button.onClick.listen((e) {
    final source = _getSourceRequest(editor);
    final sw = Stopwatch()..start();
    post(
      '$_uriBase/dartservices/v2/assists',
      body: json.encode(source),
    ).then((response) => output.text = '${_formatTiming(sw)}${response.body}');
  });
  offsetElement.text = 'offset ${_getOffset(editor)}';
  editor.onCursorActivity.listen((_) {
    offsetElement.text = 'offset ${_getOffset(editor)}';
  });
}

void setupCompile() {
  final editor = createEditor(querySelector('#compileSection-v2 .editor')!);
  final output = querySelector('#compileSection-v2 .output')!;
  final button = querySelector('#compileSection-v2 button') as ButtonElement;
  button.onClick.listen((e) {
    final source = editor.doc.getValue();
    final compile = {'source': source};
    final sw = Stopwatch()..start();
    post(
      '$_uriBase/dartservices/v2/compile',
      body: json.encode(compile),
    ).then((response) => output.text = '${_formatTiming(sw)}${response.body}');
  });
}

void setupCompileDDC() {
  final editor = createEditor(querySelector('#compileDDCSection-v2 .editor')!);
  final output = querySelector('#compileDDCSection-v2 .output')!;
  final button = querySelector('#compileDDCSection-v2 button') as ButtonElement;
  button.onClick.listen((e) {
    final source = editor.doc.getValue();
    final compile = {'source': source};
    final sw = Stopwatch()..start();
    post(
      '$_uriBase/dartservices/v2/compileDDC',
      body: json.encode(compile),
    ).then((response) => output.text = '${_formatTiming(sw)}${response.body}');
  });
}

void setupComplete() {
  final editor = createEditor(querySelector('#completeSection-v2 .editor')!);
  final output = querySelector('#completeSection-v2 .output')!;
  final offsetElement = querySelector('#completeSection-v2 .offset')!;
  final button = querySelector('#completeSection-v2 button') as ButtonElement;
  button.onClick.listen((e) {
    final source = _getSourceRequest(editor);
    final sw = Stopwatch()..start();
    post(
      '$_uriBase/dartservices/v2/complete',
      body: json.encode(source),
    ).then((response) => output.text = '${_formatTiming(sw)}${response.body}');
  });
  offsetElement.text = 'offset ${_getOffset(editor)}';
  editor.onCursorActivity.listen((_) {
    offsetElement.text = 'offset ${_getOffset(editor)}';
  });
}

void setupDocument() {
  final editor = createEditor(querySelector('#documentSection-v2 .editor')!);
  final output = querySelector('#documentSection-v2 .output')!;
  final offsetElement = querySelector('#documentSection-v2 .offset')!;
  final button = querySelector('#documentSection-v2 button') as ButtonElement;
  button.onClick.listen((e) {
    final source = _getSourceRequest(editor);
    final sw = Stopwatch()..start();
    post(
      '$_uriBase/dartservices/v2/document',
      body: json.encode(source),
    ).then((response) => output.text = '${_formatTiming(sw)}${response.body}');
  });
  offsetElement.text = 'offset ${_getOffset(editor)}';
  editor.onCursorActivity.listen((_) {
    offsetElement.text = 'offset ${_getOffset(editor)}';
  });
}

void setupFixes() {
  final editor = createEditor(querySelector('#fixesSection-v2 .editor')!);
  final output = querySelector('#fixesSection-v2 .output')!;
  final offsetElement = querySelector('#fixesSection-v2 .offset')!;
  final button = querySelector('#fixesSection-v2 button') as ButtonElement;
  button.onClick.listen((e) {
    final source = _getSourceRequest(editor);
    final sw = Stopwatch()..start();
    post(
      '$_uriBase/dartservices/v2/fixes',
      body: json.encode(source),
    ).then((response) => output.text = '${_formatTiming(sw)}${response.body}');
  });
  offsetElement.text = 'offset ${_getOffset(editor)}';

  editor.onCursorActivity.listen((_) {
    offsetElement.text = 'offset ${_getOffset(editor)}';
  });
}

void setupVersion() {
  final output = querySelector('#versionSection-v2 .output')!;
  final button = querySelector('#versionSection-v2 button') as ButtonElement;
  button.onClick.listen((e) {
    final sw = Stopwatch()..start();
    get('$_uriBase/dartservices/v2/version').then(
        (response) => output.text = '${_formatTiming(sw)}${response.body}');
  });
}

CodeMirror createEditor(Element element) {
  final options = {
    'tabSize': 2,
    'indentUnit': 2,
    'autoCloseBrackets': true,
    'matchBrackets': true,
    'theme': 'zenburn',
    'mode': 'dart',
    'value': _text
  };

  final editor = CodeMirror.fromElement(element, options: options);
  editor.refresh();
  return editor;
}

String _formatTiming(Stopwatch sw) => '${sw.elapsedMilliseconds}ms\n';

String? get _uriBase =>
    (querySelector('input[type=text]') as InputElement).value;

int? _getOffset(CodeMirror editor) {
  final pos = editor.doc.getCursor();
  return editor.doc.indexFromPos(pos);
}

Map<String, dynamic> _getSourceRequest(CodeMirror editor) => {
      'source': editor.doc.getValue(),
      'offset': _getOffset(editor),
    };

final String _text = r'''
void main() {
  for (int i = 0; i < 4; i++) {
    print('hello ${i}');
  }
}
''';

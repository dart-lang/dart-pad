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

const versions = ['v2'];

BrowserClient _client;

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

Future<Response> post(String url, {String body}) async {
  _client ??= utils.SanitizingBrowserClient();
  return _client.post(
    url,
    body: body,
    encoding: utf8,
    headers: {'content-type': 'application/json'},
  );
}

Future<Response> get(String url) async {
  _client ??= utils.SanitizingBrowserClient();
  return _client.get(
    url,
    headers: {'content-type': 'application/json'},
  );
}

void setupAnalyze() {
  versions.forEach((version) {
    final editor =
        createEditor(querySelector('#analyzeSection-$version .editor'));
    final output = querySelector('#analyzeSection-$version .output');
    final button =
        querySelector('#analyzeSection-$version button') as ButtonElement;
    button.onClick.listen((e) {
      final source = {'source': editor.getDoc().getValue()};
      final sw = Stopwatch()..start();
      post(
        '$_uriBase/dartservices/$version/analyze',
        body: json.encode(source),
      ).then(
          (response) => output.text = '${_formatTiming(sw)}${response.body}');
    });
  });
}

void setupAssists() {
  versions.forEach((version) {
    final editor =
        createEditor(querySelector('#assistsSection-$version .editor'));
    final output = querySelector('#assistsSection-$version .output');
    final offsetElement = querySelector('#assistsSection-$version .offset');
    final button =
        querySelector('#assistsSection-$version button') as ButtonElement;
    button.onClick.listen((e) {
      final source = _getSourceRequest(editor);
      final sw = Stopwatch()..start();
      post(
        '$_uriBase/dartservices/$version/assists',
        body: json.encode(source),
      ).then(
          (response) => output.text = '${_formatTiming(sw)}${response.body}');
    });
    offsetElement.text = 'offset ${_getOffset(editor)}';
    editor.onCursorActivity.listen((_) {
      offsetElement.text = 'offset ${_getOffset(editor)}';
    });
  });
}

void setupCompile() {
  versions.forEach((version) {
    final editor =
        createEditor(querySelector('#compileSection-$version .editor'));
    final output = querySelector('#compileSection-$version .output');
    final button =
        querySelector('#compileSection-$version button') as ButtonElement;
    button.onClick.listen((e) {
      final source = editor.getDoc().getValue();
      final compile = {'source': source};
      final sw = Stopwatch()..start();
      post(
        '${_uriBase}/dartservices/$version/compile',
        body: json.encode(compile),
      ).then(
          (response) => output.text = '${_formatTiming(sw)}${response.body}');
    });
  });
}

void setupCompileDDC() {
  versions.forEach((version) {
    final editor =
        createEditor(querySelector('#compileDDCSection-$version .editor'));
    final output = querySelector('#compileDDCSection-$version .output');
    final button =
        querySelector('#compileDDCSection-$version button') as ButtonElement;
    button.onClick.listen((e) {
      final source = editor.getDoc().getValue();
      final compile = {'source': source};
      final sw = Stopwatch()..start();
      post(
        '${_uriBase}/dartservices/$version/compileDDC',
        body: json.encode(compile),
      ).then(
          (response) => output.text = '${_formatTiming(sw)}${response.body}');
    });
  });
}

void setupComplete() {
  versions.forEach((version) {
    final editor =
        createEditor(querySelector('#completeSection-$version .editor'));
    final output = querySelector('#completeSection-$version .output');
    final offsetElement = querySelector('#completeSection-$version .offset');
    final button =
        querySelector('#completeSection-$version button') as ButtonElement;
    button.onClick.listen((e) {
      final source = _getSourceRequest(editor);
      final sw = Stopwatch()..start();
      post(
        '$_uriBase/dartservices/$version/complete',
        body: json.encode(source),
      ).then(
          (response) => output.text = '${_formatTiming(sw)}${response.body}');
    });
    offsetElement.text = 'offset ${_getOffset(editor)}';
    editor.onCursorActivity.listen((_) {
      offsetElement.text = 'offset ${_getOffset(editor)}';
    });
  });
}

void setupDocument() {
  versions.forEach((version) {
    final editor =
        createEditor(querySelector('#documentSection-$version .editor'));
    final output = querySelector('#documentSection-$version .output');
    final offsetElement = querySelector('#documentSection-$version .offset');
    final button =
        querySelector('#documentSection-$version button') as ButtonElement;
    button.onClick.listen((e) {
      final source = _getSourceRequest(editor);
      final sw = Stopwatch()..start();
      post(
        '$_uriBase/dartservices/$version/document',
        body: json.encode(source),
      ).then(
          (response) => output.text = '${_formatTiming(sw)}${response.body}');
    });
    offsetElement.text = 'offset ${_getOffset(editor)}';
    editor.onCursorActivity.listen((_) {
      offsetElement.text = 'offset ${_getOffset(editor)}';
    });
  });
}

void setupFixes() {
  versions.forEach((version) {
    final editor =
        createEditor(querySelector('#fixesSection-$version .editor'));
    final output = querySelector('#fixesSection-$version .output');
    final offsetElement = querySelector('#fixesSection-$version .offset');
    final button =
        querySelector('#fixesSection-$version button') as ButtonElement;
    button.onClick.listen((e) {
      final source = _getSourceRequest(editor);
      final sw = Stopwatch()..start();
      post(
        '$_uriBase/dartservices/$version/fixes',
        body: json.encode(source),
      ).then(
          (response) => output.text = '${_formatTiming(sw)}${response.body}');
    });
    offsetElement.text = 'offset ${_getOffset(editor)}';

    editor.onCursorActivity.listen((_) {
      offsetElement.text = 'offset ${_getOffset(editor)}';
    });
  });
}

void setupVersion() {
  versions.forEach((version) {
    final output = querySelector('#versionSection-$version .output');
    final button =
        querySelector('#versionSection-$version button') as ButtonElement;
    button.onClick.listen((e) {
      final sw = Stopwatch()..start();
      get('$_uriBase/dartservices/$version/version').then(
          (response) => output.text = '${_formatTiming(sw)}${response.body}');
    });
  });
}

CodeMirror createEditor(Element element, {String defaultText}) {
  final options = {
    'tabSize': 2,
    'indentUnit': 2,
    'autoCloseBrackets': true,
    'matchBrackets': true,
    'theme': 'zenburn',
    'mode': 'dart',
    'value': _text ?? defaultText
  };

  final editor = CodeMirror.fromElement(element, options: options);
  editor.refresh();
  return editor;
}

String _formatTiming(Stopwatch sw) => '${sw.elapsedMilliseconds}ms\n';

String get _uriBase =>
    (querySelector('input[type=text]') as InputElement).value;

int _getOffset(CodeMirror editor) {
  final pos = editor.getDoc().getCursor();
  return editor.getDoc().indexFromPos(pos);
}

Map<String, dynamic> _getSourceRequest(CodeMirror editor) => {
      'source': editor.getDoc().getValue(),
      'offset': _getOffset(editor),
    };

final String _text = r'''
void main() {
  for (int i = 0; i < 4; i++) {
    print('hello ${i}');
  }
}
''';

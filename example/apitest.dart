// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services_server.apitest;

import 'dart:html';

import 'package:codemirror/codemirror.dart';

import '../doc/generated/_dartpadsupportservices.dart' as support;
import '../doc/generated/dartservices.dart' as services;
import 'services_utils.dart' as utils;

utils.SanitizingBrowserClient client;
services.DartservicesApi servicesApi;
support.P_dartpadsupportservicesApi _dartpadSupportApi;

void main() {
  setupAnalyze();
  setupCompile();
  setupComplete();
  setupDocument();
  setupFixes();
  setupVersion();
  setupDartpadServices();
}

void setupDartpadServices() {
  setupExport();
  setupRetrieve();
  setupIdRetrieval();
  setupGistStore();
  setupGistRetrieval();
}

void _setupClients() {
  client = utils.SanitizingBrowserClient();
  servicesApi = services.DartservicesApi(client, rootUrl: _uriBase);
  _dartpadSupportApi =
      support.P_dartpadsupportservicesApi(client, rootUrl: _uriBase);
}

void setupIdRetrieval() {
  final output = querySelector('#idSection .output');
  final button = querySelector('#idSection button') as ButtonElement;
  button.onClick.listen((e) {
    final sw = Stopwatch()..start();
    _dartpadSupportApi.getUnusedMappingId().then((results) {
      output.text = '${_formatTiming(sw)}${results.toJson()}';
    });
  });
}

void setupGistStore() {
  final editor = createEditor(querySelector('#storeSection .editor'),
      defaultText: 'Internal ID');
  final output = querySelector('#storeSection .output');
  final button = querySelector('#storeSection button') as ButtonElement;
  button.onClick.listen((e) {
    final editorText = editor.getDoc().getValue();
    final saveObject = support.GistToInternalIdMapping();
    saveObject.internalId = editorText;
    saveObject.gistId = '72d83fe97bfc8e735607'; //Solar
    final sw = Stopwatch()..start();
    _dartpadSupportApi.storeGist(saveObject).then((results) {
      output.text = '${_formatTiming(sw)}${results.toJson()}';
    });
  });
}

void setupGistRetrieval() {
  final editor = createEditor(querySelector('#gistSection .editor'),
      defaultText: 'Internal ID');
  final output = querySelector('#gistSection .output');
  final button = querySelector('#gistSection button') as ButtonElement;
  button.onClick.listen((e) {
    final editorText = editor.getDoc().getValue();
    final sw = Stopwatch()..start();
    _dartpadSupportApi.retrieveGist(id: editorText).then((results) {
      output.text = '${_formatTiming(sw)}${results.toJson()}';
    });
  });
}

void setupAnalyze() {
  final editor = createEditor(querySelector('#analyzeSection .editor'));
  final output = querySelector('#analyzeSection .output');
  final button = querySelector('#analyzeSection button') as ButtonElement;
  button.onClick.listen((e) {
    _setupClients();
    final srcRequest = services.SourceRequest()
      ..source = editor.getDoc().getValue();
    final sw = Stopwatch()..start();
    servicesApi.analyze(srcRequest).then((results) {
      output.text = '${_formatTiming(sw)}${results.toJson()}';
    });
  });
}

void setupCompile() {
  final editor = createEditor(querySelector('#compileSection .editor'));
  final output = querySelector('#compileSection .output');
  final button = querySelector('#compileSection button') as ButtonElement;
  button.onClick.listen((e) {
    final source = editor.getDoc().getValue();

    _setupClients();
    final compileRequest = services.CompileRequest();
    compileRequest.source = source;

    final sw = Stopwatch()..start();
    servicesApi.compile(compileRequest).then((results) {
      output.text = '${_formatTiming(sw)}${results.toJson()}';
    });
  });
}

void setupComplete() {
  final editor = createEditor(querySelector('#completeSection .editor'));
  final output = querySelector('#completeSection .output');
  final offsetElement = querySelector('#completeSection .offset');
  final button = querySelector('#completeSection button') as ButtonElement;
  button.onClick.listen((e) {
    final sourceRequest = _getSourceRequest(editor);
    final sw = Stopwatch()..start();
    servicesApi.complete(sourceRequest).then((results) {
      output.text = '${_formatTiming(sw)}${results.toJson()}';
    });
  });
  offsetElement.text = 'offset ${_getOffset(editor)}';
  editor.onCursorActivity.listen((_) {
    offsetElement.text = 'offset ${_getOffset(editor)}';
  });
}

void setupDocument() {
  final editor = createEditor(querySelector('#documentSection .editor'));
  final output = querySelector('#documentSection .output');
  final offsetElement = querySelector('#documentSection .offset');
  final button = querySelector('#documentSection button') as ButtonElement;
  button.onClick.listen((e) {
    final sourceRequest = _getSourceRequest(editor);
    final sw = Stopwatch()..start();
    servicesApi.document(sourceRequest).then((results) {
      output.text = '${_formatTiming(sw)}${results.toJson()}';
    });
  });
  offsetElement.text = 'offset ${_getOffset(editor)}';
  editor.onCursorActivity.listen((_) {
    offsetElement.text = 'offset ${_getOffset(editor)}';
  });
}

void setupFixes() {
  final editor = createEditor(querySelector('#fixesSection .editor'));
  final output = querySelector('#fixesSection .output');
  final offsetElement = querySelector('#fixesSection .offset');
  final button = querySelector('#fixesSection button') as ButtonElement;
  button.onClick.listen((e) {
    final sourceRequest = _getSourceRequest(editor);
    final sw = Stopwatch()..start();
    servicesApi.fixes(sourceRequest).then((results) {
      output.text = '${_formatTiming(sw)}${results.toJson()}';
    });
  });
  offsetElement.text = 'offset ${_getOffset(editor)}';

  editor.onCursorActivity.listen((_) {
    offsetElement.text = 'offset ${_getOffset(editor)}';
  });
}

void setupVersion() {
  final output = querySelector('#versionSection .output');
  final button = querySelector('#versionSection button') as ButtonElement;
  button.onClick.listen((e) {
    final sw = Stopwatch()..start();
    servicesApi.version().then((results) {
      output.text = '${_formatTiming(sw)}${results.toJson()}';
    });
  });
}

void setupExport() {
  final editor = createEditor(querySelector('#exportSection .editor'));
  final output = querySelector('#exportSection .output');
  final button = querySelector('#exportSection button') as ButtonElement;
  button.onClick.listen((e) {
    final saveObject = support.PadSaveObject();
    saveObject.dart = editor.getDoc().getValue();
    final sw = Stopwatch()..start();
    _dartpadSupportApi.export(saveObject).then((results) {
      output.text = '${_formatTiming(sw)}${results.toJson()}';
    });
  });
}

void setupRetrieve() {
  final output = querySelector('#retrieveSection .output');
  final editor =
      createEditor(querySelector('#retrieveSection .editor'), defaultText: '');
  final button = querySelector('#retrieveSection button') as ButtonElement;
  button.onClick.listen((e) {
    final uuid = editor.getDoc().getValue();
    final sw = Stopwatch()..start();
    final uuidContainer = support.UuidContainer()..uuid = uuid;

    _dartpadSupportApi.pullExportContent(uuidContainer).then((results) {
      output.text = '${_formatTiming(sw)}${results.toJson()}';
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

services.SourceRequest _getSourceRequest(CodeMirror editor) {
  final srcRequest = services.SourceRequest()
    ..source = editor.getDoc().getValue()
    ..offset = _getOffset(editor);
  return srcRequest;
}

final String _text = r'''
void main() {
  for (int i = 0; i < 4; i++) {
    print('hello ${i}');
  }
}
''';

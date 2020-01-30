// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:html';

const _helloWorldSample = '''
void main() {
  print('Hello, World!');
}
    ''';
const _functionsSample = '''
void main() {
  print(f());
}

String f() {
  return 'function';
}
    ''';

void main() {
  var dartPadHost = querySelector('#dartpad-host');
  var select = querySelector('#dartpad-select') as SelectElement;

  DartPadPicker(dartPadHost, select, snippets, dartPadUrl: '');
}

const snippets = <Snippet>[
  Snippet('Hello, World!', _helloWorldSample, 'hello_world1'),
  Snippet('Functions', _functionsSample, 'function1'),
];

class Snippet {
  final String name;
  final String sourceCode;
  final String googleAnalyticsId;

  const Snippet(this.name, this.sourceCode, this.googleAnalyticsId);
}

class DartPadPicker {
  final String dartPadUrl;
  final Element iFrameHost;
  final SelectElement selectElement;
  final List<Snippet> snippets;
  IFrameElement _iFrameElement;
  int _selected = 0;

  DartPadPicker(this.iFrameHost, this.selectElement, this.snippets,
      {this.dartPadUrl = 'https://dartpad.dev'}) {
    _initSelectElement();
    _initDartPad();
  }

  Snippet get _selectedSnippet => snippets[_selected];

  Map<String, dynamic> get _sourceCodeMessage => {
        'sourceCode': {
          'main.dart': _selectedSnippet.sourceCode,
          'ga_id': _selectedSnippet.googleAnalyticsId,
        },
        'type': 'sourceCode'
      };

  void _initSelectElement() {
    for (var i = 0; i < snippets.length; i++) {
      var snippet = snippets[i];
      var option = OptionElement(value: '$i')..text = snippet.name;
      selectElement.children.add(option);
    }
    selectElement.onChange.listen((Event _) {
      _selected = selectElement.selectedIndex;
      _sendSourceCode();
    });
  }

  void _initDartPad() {
    _iFrameElement = IFrameElement()
      ..src = iFrameSrc(theme: 'dark', mode: 'dart');
    iFrameHost.children.add(_iFrameElement);
    window.addEventListener('message', (Event _e) {
      final e = _e as MessageEvent;
      // Don't handle events from other iframe elements
      if (e.data is Map &&
          (e.data as Map).containsKey('type') &&
          e.data['type'] is String &&
          e.data['type'] == 'ready') {
        _sendSourceCode();
      }
    });
  }

  void _sendSourceCode() {
    _iFrameElement.contentWindow.postMessage(_sourceCodeMessage, '*');
  }

  String iFrameSrc({String theme, String mode}) {
    return '${dartPadUrl}/embed-$mode.html?theme=$theme';
  }
}

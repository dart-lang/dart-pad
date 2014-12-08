
import 'dart:html';

import 'package:codemirror/codemirror.dart';

// TODO: visualize what I'm editing - the gist or id

// TODO: have a save button - active if the content is dirty, or if I've never
// saved

// TODO: have a fork button - active if I'm looking at somebody else's gist

// TODO: have a run button

// TODO: have a selected tab visualizer arrow

// TODO: design the services and components

// TODO: create a fully functional mock


void init() {
  print('hello from the playground');

  Playground playground = new Playground();
}

// editpanel

class Playground {

  DivElement get _editpanel => querySelector('#editpanel');

  DivElement get _outputpanel => querySelector('#outputpanel');

  IFrameElement get _frame => querySelector('#frame');

  Playground() {
    // TODO: setup tab listeners

    // setup editing area
    Map options = {
      //'lineNumbers': true,
      //'gutters': ['CodeMirror-lint-markers'],
      //'lint': true,
      'mode': 'javascript',
      'theme': 'ambiance' // ambiance, vibrant-ink, monokai
    };

    CodeMirror editor = new CodeMirror.fromElement(_editpanel, options: options);
    editor.getDoc().setValue(r'''void main() {
  for (int i = 0; i < 10; i++) {
    print('hello ${i}');
  }
}
''');
    _editpanel.children.first.attributes['flex'] = '';
    editor.refresh();

    // TODO: setup output area

    // set up iframe
    window.onMessage.listen((MessageEvent event) {
      print('from iframe: ${event.data}');
    });
  }

  void sendMessageToFrame(var message) =>
      _frame.contentWindow.postMessage(message, '*');
}

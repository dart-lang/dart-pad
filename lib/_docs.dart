// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library docs_sample;

import 'dart:async';
import 'dart:html';

import 'core/event_bus.dart';

import 'core/dependencies.dart';
import 'core/modules.dart';
import 'dart_pad.dart';
import 'modules/dart_pad_module.dart';
import 'modules/dartservices_module.dart';
import 'services/dartservices.dart';
import 'services/execution_iframe.dart';

EventBus _bus = new EventBus();
ModuleManager modules = new ModuleManager();

// TODO: add an 'explore' button

Future _initModules() {
  modules.register(new DartPadModule());
  modules.register(new DartServicesModule());
  return modules.start();
}

void init() {
  _initModules().then((_) {
    List<Element> elements = querySelectorAll('[executable]');

    /*List<DocSnippet> snippets =*/ elements.map((e) => new DocSnippet(e)).toList();

    print('Found ${elements.length} matching executable doc comments.');
  });
}

//<div class="docexecutable">
//  <div class="runbuttoncontainer">
//    <div class="btn-group runbutton">
//      <button type="button" class="btn btn-primary btn-xs">&nbsp;Run&nbsp;</button>
//    </div>
//  </div>
//
//  <pre code executable class="hasoutput">List superheroes = ['Batman', 'Superman', 'Harry Potter'];
//print(superheroes);</pre>
//  <div class="output">one two
//three four
//five</div>
//</div>

// insert a run button
// have it show on hover
// on a mouse click in the text area
//   realize as codemirror
//   make the button stick
// on run button click click,
//   display the output area, move the button
//   compile and execute the sample
// on focus lost, hide the putput area?

class DocSnippet {
  final Element preElement;

  Element _container;
  ButtonElement _runButton;
  Element _output;

  DocSnippet(this.preElement) {
    // <div class="docexecutable">
    _container = new DivElement();
    _container.classes.add('docexecutable');
    int index = preElement.parent.children.indexOf(preElement);
    preElement.parent.children.insert(index, _container);

    //<div class="runbuttoncontainer">
    DivElement buttoncontainer = new DivElement();
    buttoncontainer.classes.add('runbuttoncontainer');
    _container.children.add(buttoncontainer);

    // <div class="btn-group runbutton">
    //   <button type="button" class="btn btn-primary btn-xs">&nbsp;Run&nbsp;</button>
    // </div>
    DivElement buttonGroup = new DivElement();
    buttonGroup.classes.add('btn-group');
    buttonGroup.classes.add('runbutton');
    buttoncontainer.children.add(buttonGroup);

    _runButton = new ButtonElement();
    _runButton.text = 'Run';
    _runButton.attributes['type'] = 'button';
    _runButton.classes.add('btn');
    _runButton.classes.add('btn-primary');
    _runButton.classes.add('btn-xs');
    _runButton.onClick.listen((_) => _handleButtonClick());
    buttonGroup.children.add(_runButton);

    // <pre code executable class="hasoutput">
    _container.children.add(preElement);

    // <div class="output">
    _output = new DivElement();
    _output.classes.add('output');
    _container.children.add(_output);

    _bus.onEvent('dart-run').listen((BusEvent e) {
      var target = e.args['snippet'];

      if (target != this) {
        _hideOutput();
      }
    });
  }

  void _handleButtonClick() {
    if (!_runButton.disabled) {
      _run();
    }
  }

  void _run() {
    _fireRunningEvent();

    _enableButton(false);

    _clearOutput();

    deps[ExecutionService] = new ExecutionServiceIFrame(querySelector("iframe"));
    executionService.onStdout.listen((m) => _appendOutput(m));
    executionService.onStderr.listen((ex) => _displayErrors(ex));

    var input = new CompileRequest()..source = "void main(){${preElement.text}}";
    dartServices.compile(input).then(
            (CompileResponse response) {
              executionService.execute(
                  "", "", response.result);
              _enableButton(true);
              _showOutput();
            });
  }

  void _enableButton(bool value) {
    _runButton.disabled = !value;
    _runButton.text = value ? 'Run' : 'Running…';
    _runButton.classes.toggle('running', !value);
  }

  bool _outputShowing() => _output.style.display == 'block';

  void _showOutput() {
    if (_outputShowing()) return;

    _output.style.display = 'block';
    preElement.classes.toggle('hasoutput', true);
    Timer.run(() {
      _output.attributes['showing'] = 'true';
    });
  }

  void _hideOutput() {
    if (!_outputShowing()) return;

    var sub;

    sub = _output.onTransitionEnd.listen((_) {
      sub.cancel();

      _output.style.display = 'none';
      preElement.classes.toggle('hasoutput', false);
    });

    _output.attributes.remove('showing');
  }

  void _clearOutput() {
    _output.text = '';
    _output.classes.toggle('errors', false);
  }

  void _appendOutput(String str) {
    _output.text += str + '\n';
  }

  void _displayErrors(ExecutionException ex) {
    _output.text = ex.message;
    _output.classes.toggle('errors', true);
  }

  void _fireRunningEvent() {
    _bus.addEvent(new BusEvent('dart-run', {'snippet': this}));
  }
}

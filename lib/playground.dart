// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library playground;

import 'dart:async';
import 'dart:html' hide Document;
import 'dart:math' as math;
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:markd/markdown.dart' as markdown;
import 'package:route_hierarchical/client.dart';

import 'completion.dart';
import 'context.dart';
import 'core/dependencies.dart';
import 'core/modules.dart';
import 'dart_pad.dart';
import 'dartservices_client/v1.dart';
import 'editing/editor.dart';
import 'elements/elements.dart';
import 'modules/codemirror_module.dart';
import 'modules/dart_pad_module.dart';
import 'modules/dartservices_module.dart';
import 'services/common.dart';
import 'services/execution_iframe.dart';
import 'src/ga.dart';
import 'src/gists.dart';
import 'src/sample.dart' as sample;
import 'src/util.dart';

Playground get playground => _playground;

Playground _playground;
Analytics ga = new Analytics();

Logger _logger = new Logger('dart_pad');

void init() {
  _playground = new Playground();
}

class Playground {
  DivElement get _editpanel => querySelector('#editpanel');
  DivElement get _outputpanel => querySelector('#output');
  IFrameElement get _frame => querySelector('#frame');
  DivElement get _docPanel => querySelector('#documentation');
  bool get _isCompletionActive => editor.completionActive;
  bool get _isDocPanelOpen => querySelector("#doctab").attributes.containsKey('selected');
  bool get _parPopupActive => querySelector(".parameter-hints") != null;

  DButton runbutton;
  DOverlay overlay;
  DBusyLight dartBusyLight;
  DBusyLight cssBusyLight;
  DBusyLight htmlBusyLight;
  Editor editor;
  PlaygroundContext _context;
  Future _analysisRequest;
  Router _router;

  ModuleManager modules = new ModuleManager();

  Playground() {
    _registerTab(querySelector('#darttab'), 'dart');
    _registerTab(querySelector('#htmltab'), 'html');
    _registerTab(querySelector('#csstab'), 'css');

    overlay = new DOverlay(querySelector('#frame_overlay'));
    runbutton = new DButton(querySelector('#runbutton'));
    runbutton.onClick.listen((e) {
      _handleRun();

      // On a mobile device, focusing the editing area causes the keyboard to
      // pop up when the user hits the run button.
      if (!isMobile()) _context.focus();
    });

    // TODO: Currently the lights are all shared; we should have one for each
    // type.
    dartBusyLight = new DBusyLight(querySelector('#dartbusy'));
    cssBusyLight = new DBusyLight(querySelector('#dartbusy'));
    htmlBusyLight = new DBusyLight(querySelector('#dartbusy'));

    SelectElement select = querySelector('#samples');
    select.onChange.listen((_) => _handleSelectChanged(select));

    _initModules().then((_) {
      _initPlayground();
    });
  }

  void showHome(RouteEnterEvent event) {
    //_logger.info('routed to showHome, ${window.location}, ${event.parameters}');

    // TODO(devoncarew): Hack, until we resolve the issue with routing.
    String path = window.location.pathname;
    if (path.length > 2 && path.lastIndexOf('/') == 0) {
      String id = path.substring(1);
      if (isLegalGistId(id)) {
        _showGist(id);
        return;
      }
    }

    _setGistDescription(null);
    _setGistId(null, null);

    context.dartSource = sample.dartCode;
    context.htmlSource = sample.htmlCode;
    context.cssSource = sample.cssCode;

    Timer.run(_handleRun);
  }

  void showGist(RouteEnterEvent event) {
    //_logger.info('routed to showGist, ${window.location}, ${event.parameters}');

    String gistId = event.parameters['gist'];

    if (!isLegalGistId(gistId)) {
      showHome(event);
      return;
    }

    _showGist(gistId);
  }

  void _showGist(String gistId) {
    Gist.loadGist(gistId).then((Gist gist) {
      _setGistDescription(gist.description);
      _setGistId(gist.id, gist.htmlUrl);

      GistFile dart = chooseGistFile(gist, ['main.dart'], (f) => f.endsWith('.dart'));
      GistFile html = chooseGistFile(gist, ['index.html', 'body.html']);
      GistFile css = chooseGistFile(gist, ['styles.css', 'style.css']);

      context.dartSource = dart == null ? '' : dart.contents;
      context.htmlSource = html == null ? '' : extractHtmlBody(html.contents);
      context.cssSource = css == null ? '' : css.contents;

      // Analyze and run it.
      Timer.run(() {
        _handleRun();
        _performAnalysis();
      });
    }).catchError((e) {
      // TODO: Display any errors - use a toast.
      print('Error loading gist ${gistId}.');
      print(e);
    });
  }

  Future _initModules() {
    modules.register(new DartPadModule());
    //modules.register(new MockDartServicesModule());
    modules.register(new DartServicesModule());
    //modules.register(new AceModule());
    modules.register(new CodeMirrorModule());

    return modules.start();
  }

  void _initPlayground() {
    final List cursorKeys = [KeyCode.LEFT, KeyCode.RIGHT, KeyCode.UP, KeyCode.DOWN];

    // TODO: Set up some automatic value bindings.
    DSplitter editorSplitter = new DSplitter(querySelector('#editor_split'));
    editorSplitter.onPositionChanged.listen((pos) {
      state['editor_split'] = pos;
      editor.resize();
    });
    if (state['editor_split'] != null) {
     editorSplitter.position = state['editor_split'];
    }

    DSplitter outputSplitter = new DSplitter(querySelector('#output_split'));
    outputSplitter.onPositionChanged.listen((pos) {
      state['output_split'] = pos;
    });
    if (state['output_split'] != null) {
      outputSplitter.position = state['output_split'];
    }

    // Set up the iframe.
    deps[ExecutionService] = new ExecutionServiceIFrame(_frame);
    executionService.onStdout.listen(_showOuput);
    executionService.onStderr.listen((m) => _showOuput(m, error: true));

    // Set up the editing area.
    editor = editorFactory.createFromElement(_editpanel);
    _editpanel.children.first.attributes['flex'] = '';
    editor.resize();

    keys.bind('ctrl-s', _handleSave);
    keys.bind('ctrl-enter', _handleRun);
    keys.bind('f1', () {
      _toggleDocTab();
      _handleHelp();
    });

    document.onKeyDown.listen((e) {
      if (e.keyCode == KeyCode.ENTER) {
        // TODO: this should probably only be fired when the completion popup was active
        // TODO: but there doesn't seem a way to find this out
        // TODO: maybe adding _loopParameterInfo to hintApplier in editor_codemirror.dart ?
        _lookupParameterInfo();
      }
    });

    document.onKeyUp.listen((e) {

      //documentation
      if (_isCompletionActive || cursorKeys.contains(e.keyCode)) {
        _handleHelp();
      }

      //autocompletion
      if (options.getValueBool('autopopup_code_completion')) {
        RegExp exp = new RegExp(r"[a-zA-Z]");
        if (!_isCompletionActive && exp.hasMatch(
            new String.fromCharCode(e.keyCode)) || e.keyCode == KeyCode.PERIOD) {
          editor.execCommand("autocomplete");
        }
      }

      //parameter popup
      if (e.keyCode == KeyCode.ESC) {
        document.body.children.remove(querySelector(".parameter-hints"));
        return;
      }
      _lookupParameterInfo(e);
    });
    
    document.onClick.listen((e) {
      _handleHelp();
      _lookupParameterInfo();
    });
    
    querySelector("#doctab").onClick.listen((e) => _toggleDocTab());
    querySelector("#consoletab").onClick.listen((e) => _toggleConsoleTab());

    _context = new PlaygroundContext(editor);
    deps[Context] = _context;

    editorFactory.registerCompleter(
        'dart', new DartCompleter(dartServices, _context._dartDoc));

    _context.onHtmlDirty.listen((_) => htmlBusyLight.on());
    _context.onHtmlReconcile.listen((_) {
      executionService.replaceHtml(_context.htmlSource);
      htmlBusyLight.reset();
    });

    _context.onCssDirty.listen((_) => cssBusyLight.on());
    _context.onCssReconcile.listen((_) {
      executionService.replaceCss(_context.cssSource);
      cssBusyLight.reset();
    });

    _context.onDartDirty.listen((_) => dartBusyLight.on());
    _context.onDartReconcile.listen((_) => _performAnalysis());

    // Set up development options.
    options.registerOption('autopopup_code_completion', 'false');
    options.registerOption('parameter_popup', 'false');

    _finishedInit();
  }

  _finishedInit() {
    // Clear the splash.
    DSplash splash = new DSplash(querySelector('div.splash'));
    splash.hide();

    _router = new Router();
    _router.root.addRoute(name: 'home', defaultRoute: true, enter: showHome);
    _router.root.addRoute(name: 'gist', path: '/:gist', enter: showGist);
    _router.listen();
  }

  void _registerTab(Element element, String name) {
    DElement component = new DElement(element);

    component.onClick.listen((_) {
      if (component.hasAttr('selected')) return;

      component.setAttr('selected');

      _getTabElements(component.element.parent.parent).forEach((c) {
        if (c != component.element && c.attributes.containsKey('selected')) {
          c.attributes.remove('selected');
        }
      });

      ga.sendEvent('edit', name);
      _context.switchTo(name);
    });
  }

  List<Element> _getTabElements(Element element) =>
      element.querySelectorAll('a');

  void _toggleDocTab() {
    // TODO:(devoncarew): We need a tab component (in lib/elements.dart).
    _outputpanel.style.display = "none";
    querySelector("#consoletab").attributes.remove('selected');

    _docPanel.style.display = "block";
    querySelector("#doctab").setAttribute('selected','');
  }

  void _toggleConsoleTab() {
    _docPanel.style.display = "none";
    querySelector("#doctab").attributes.remove('selected');

    _outputpanel.style.display = "block";
    querySelector("#consoletab").setAttribute('selected','');
  }

  void _handleRun() {
    _toggleConsoleTab();
    ga.sendEvent('main', 'run');
    runbutton.disabled = true;
    overlay.visible = true;

    _clearOutput();

    var input = new SourceRequest()..source = context.dartSource;
    dartServices.compile(input).timeout(longServiceCallTimeout).then(
        (CompileResponse response) {
      return executionService.execute(
          _context.htmlSource, _context.cssSource, response.result);
    }).catchError((e) {
      // TODO: Also display using a toast.
      _showOuput('Error compiling to JavaScript:\n${e}', error: true);
    }).whenComplete(() {
      runbutton.disabled = false;
      overlay.visible = false;
    });
  }

  void _performAnalysis() {
    var input = new SourceRequest()..source = _context.dartSource;
    Lines lines = new Lines(input.source);

    Future request = dartServices.analyze(input).timeout(serviceCallTimeout);;
    _analysisRequest = request;

    request.then((AnalysisResults result) {
      // Discard if we requested another analysis.
      if (_analysisRequest != request) return;

      // Discard if the document has been mutated since we requested analysis.
      if (input.source != _context.dartSource) return;

      dartBusyLight.reset();

      _displayIssues(result.issues);

      _context.dartDocument.setAnnotations(result.issues.map(
          (AnalysisIssue issue) {
        int startLine = lines.getLineForOffset(issue.charStart);
        int endLine = lines.getLineForOffset(issue.charStart + issue.charLength);

        Position start = new Position(startLine,
            issue.charStart - lines.offsetForLine(startLine));
        Position end = new Position(endLine,
            issue.charStart + issue.charLength - lines.offsetForLine(startLine));

        return new Annotation(issue.kind, issue.message, issue.line,
            start: start, end: end);
      }).toList());

      _updateRunButton(
          hasErrors: result.issues.any((issue) => issue.kind == 'error'),
          hasWarnings: result.issues.any((issue) => issue.kind == 'warning'));
    }).catchError((e) {
      _context.dartDocument.setAnnotations([]);
      dartBusyLight.reset();
      _updateRunButton();
      _logger.severe(e);
    });
  }

  void _handleSave() {
    ga.sendEvent('main', 'save');
    // TODO:
    print('handleSave');
  }

  void _handleHelp() {
    if (context.focusedEditor == 'dart' && _isDocPanelOpen && editor.document.selection.isEmpty) {
      ga.sendEvent('main', 'help');

      SourceRequest input;
      Position pos = editor.document.cursor;
      int offset = editor.document.indexFromPos(pos);

      if (_isCompletionActive) {
        // If the completion popup is open we create a new source as if the
        // completion popup was chosen, and ask for the documentation of that
        // source.
        String completionText = querySelector(".CodeMirror-hint-active").text;
        var source = context.dartSource;
        int lastSpace = source.substring(0, offset).lastIndexOf(" ") + 1;
        int lastDot = source.substring(0, offset).lastIndexOf(".") + 1;
        offset = math.max(lastSpace, lastDot);
        source = _context.dartSource.substring(0, offset) +
            completionText +
            context.dartSource.substring(editor.document.indexFromPos(pos));
        input = new SourceRequest()
          ..source = source
          ..offset = offset;
      } else {
        input = new SourceRequest()
          ..source = _context.dartSource
          ..offset = offset;
      }

      // TODO: Show busy.
      dartServices.document(input).timeout(serviceCallTimeout).then(
          (DocumentResponse result) {
        if (result.info['description'] == null &&
            result.info['dartdoc'] == null) {
          _docPanel.setInnerHtml("<p>No documentation found.</p>");
        } else {
          final NodeValidatorBuilder _htmlValidator = new NodeValidatorBuilder.common()
            ..allowElement('a', attributes: ['href']);
          _docPanel.setInnerHtml(markdown.markdownToHtml(
'''
# `${result.info['description']}`\n\n
${result.info['dartdoc'] != null ? result.info['dartdoc'] + "\n\n" : ""}
${result.info['kind'].contains("variable") ? "${result.info['kind']}\n\n" : ""}
${result.info['kind'].contains("variable") ? "**Propagated type:** ${result.info["propagatedType"]}\n\n" : ""}
${result.info['libraryName'] != null ? "**Library:** ${result.info['libraryName']}" : ""}\n\n
''', inlineSyntaxes: [ new InlineBracketsColon(), new InlineBrackets()]), validator: _htmlValidator);
        }
      });
    }
  }

  ///Returns null if the offset is not contained in parenthesis.
  ///Otherwise it will return information about the parameters.
  ///For example, if the source is `substring(1, <caret>)`, it will return
  ///`{openingParenIndex: 9, parameterIndex: 1}`.
  Map<String,int> _parameterInfo(String source, int offset) {
    int parameterIndex = 0;
    int openingParenIndex;
    int nesting = 0;

    while (openingParenIndex == null && offset > 0) {
      offset += -1;
      if (nesting == 0) {
        switch (source[offset]) {
          case "(":
            openingParenIndex = offset;
            break;
          case ",":
            parameterIndex += 1;
            break;
          case ";":
            return null;
          case ")":
            nesting += 1;
            break;
        }
      } else {
        switch(source[offset]) {
          case "(":
            nesting += -1;
            break;
          case ")":
            nesting += 1;
            break;
        }
      }
    }
    return openingParenIndex == null ? null : {
      "openingParenIndex" : openingParenIndex,
      "parameterIndex" : parameterIndex
    };
  }

  void _lookupParameterInfo([KeyboardEvent e]) {

    if(!options.getValueBool("parameter_popup")) {
      return;
    }

    if (context.focusedEditor != 'dart' || !editor.hasFocus) {
      document.body.children.remove(querySelector(".parameter-hints"));
      return;
    }

    if (e != null && !_parPopupActive) {
      //so if we have a keyboardevent (not a click)
      const List navKeys = const[KeyCode.COMMA, KeyCode.NINE, KeyCode.ZERO, KeyCode.LEFT, KeyCode.RIGHT, KeyCode.UP, KeyCode.DOWN];
      if (!navKeys.contains(e.keyCode)) {
        return;
      }
    }

    int offset = editor.document.indexFromPos(editor.document.cursor);
    String source = _context.dartSource;
    Map<String, int> parInfo = _parameterInfo(source, offset);

    if (parInfo == null) {
      document.body.children.remove(querySelector(".parameter-hints"));
      return;
    }

    int openingParenIndex = parInfo["openingParenIndex"], parameterIndex = parInfo["parameterIndex"];
    offset = openingParenIndex - 1;

    //we then request documentation info of what is before that parenthesis
    SourceRequest input = new SourceRequest()
      ..source = source
      ..offset = offset;

    dartServices.document(input).timeout(serviceCallTimeout)
    .then((DocumentResponse result) {
      if (!result.info.containsKey("parameters")) {
        document.body.children.remove(querySelector(".parameter-hints"));
        return;
      }
      List parameterInfo = result.info["parameters"] as List;
      String outputString = "";
      if (parameterInfo.length == 0) {
        outputString += "<code>&lt;no parameters&gt;</code>";
      } else if (parameterInfo.length < parameterIndex + 1) {
        outputString += "<code>too many parameters listed</code>";
      } else {
        outputString += "<code>";
        var sanitizer = const HtmlEscape();

        for (int i = 0; i < parameterInfo.length; i++) {
          if (i == parameterIndex) {
            outputString += '<em>${parameterInfo[i]}</em>';
          } else {
            outputString += '${sanitizer.convert(parameterInfo[i])}';
          }
          if (i != parameterInfo.length - 1) {
            outputString += ", ";
          }
        }
        outputString += "</code>";
      }

      //check again if cursor is in parameter position
      offset = editor.document.indexFromPos(editor.document.cursor);
      source = _context.dartSource;
      parInfo = _parameterInfo(source, offset);
      if (parInfo == null) {
        document.body.children.remove(querySelector(".parameter-hints"));
        return;
      }
      _showParameterPopup(outputString);
    });
  }

  void _showParameterPopup(String string) {
    DivElement editorDiv = querySelector("#editpanel .CodeMirror");
    var lineHeight = editorDiv.getComputedStyle().getPropertyValue('line-height');
    lineHeight = int.parse(lineHeight.substring(0, lineHeight.indexOf("px")));
    //var charWidth = editorDiv.getComputedStyle().getPropertyValue('letter-spacing');
    int charWidth = 8;

    Point cursorCoords = editor.cursorCoords;

    if (_parPopupActive) {
      var parameterHint = querySelector(".parameter-hint");
      parameterHint.innerHtml = string;

      //update popup position
      int newLeft = math.max(cursorCoords.x - (parameterHint.text.length * charWidth ~/ 2),0);

      var parameterPopup = querySelector(".parameter-hints")
        ..style.top = "${cursorCoords.y - lineHeight - 5}px";
      var oldLeft = parameterPopup.style.left;
      oldLeft = int.parse(oldLeft.substring(0,oldLeft.indexOf("px")));
      if ((newLeft - oldLeft).abs() > 50) {
        parameterPopup.style.left = "${newLeft}px";
      }
    } else {
      var parameterHint = new SpanElement()
        ..innerHtml = string
        ..classes.add("parameter-hint");
      int left = math.max(cursorCoords.x - (parameterHint.text.length * charWidth ~/ 2), 0);
      var parameterPopup = new DivElement()
        ..classes.add("parameter-hints")
        ..style.left = "${left}px"
        ..style.top = "${cursorCoords.y - lineHeight - 5}px";
      parameterPopup.append(parameterHint);
      document.body.append(parameterPopup);
    }
  }

  void _clearOutput() {
    _outputpanel.text = '';
  }

  void _showOuput(String message, {bool error: false}) {
    message = message + '\n';
    SpanElement span = new SpanElement();
    span.classes.add(error ? 'errorOutput' : 'normal');
    span.text = message;
    _outputpanel.children.add(span);
    span.scrollIntoView(ScrollAlignment.BOTTOM);
  }

  void _handleSelectChanged(SelectElement select) {
    String value = select.value;

    if (isLegalGistId(value)) {
      _router.go('gist', {'gist': value});
    }

    select.value = '0';
  }

  void _setGistDescription(String description) {
    Element e = querySelector('header .header-gist-name');
    e.text = description == null ? '' : description;
  }

  void _setGistId(String title, String url) {
    Element e = querySelector('header .header-gist-id');

    if (title == null || url == null) {
      e.text = '';
    } else {
      e.children.clear();

      AnchorElement a = new AnchorElement(href: url);
      a.text = title;
      a.target = 'gist';
      e.children.add(a);
    }
  }

  void _displayIssues(List<AnalysisIssue> issues) {
    Element issuesElement = querySelector('#issues');

    // Detect when hiding; don't remove the content until hidden.
    bool isHiding = issuesElement.children.isNotEmpty && issues.isEmpty;

    if (isHiding) {
      issuesElement.classes.toggle('showing', issues.isNotEmpty);

      StreamSubscription sub;
      sub = issuesElement.onTransitionEnd.listen((_) {
        issuesElement.children.clear();
        sub.cancel();
      });
    } else {
      issuesElement.children.clear();

      issues.sort((a, b) => a.charStart - b.charStart);

      // Create an item for each issue.
      for (AnalysisIssue issue in issues) {
        DivElement e = new DivElement();
        e.classes.add('issue');
        issuesElement.children.add(e);
        e.onClick.listen((_) {
          _jumpTo(issue.line, issue.charStart, issue.charLength, focus: true);
        });

        SpanElement typeSpan = new SpanElement();
        typeSpan.classes.addAll([issue.kind, 'issuelabel']);
        typeSpan.text = issue.kind;
        e.children.add(typeSpan);

        SpanElement messageSpan = new SpanElement();
        messageSpan.classes.add('message');
        messageSpan.text = issue.message;
        e.children.add(messageSpan);
      }

      issuesElement.classes.toggle('showing', issues.isNotEmpty);
    }
  }

  void _updateRunButton({bool hasErrors: false, bool hasWarnings: false}) {
    const alertSVGIcon =
        "M5,3H19A2,2 0 0,1 21,5V19A2,2 0 0,1 19,21H5A2,2 0 0,1 3,19V5A2,2 0 0,"
        "1 5,3M13,13V7H11V13H13M13,17V15H11V17H13Z";

    var path = runbutton.element.querySelector("path");
    path.attributes["d"] =
        (hasErrors || hasWarnings) ? alertSVGIcon : "M8 5v14l11-7z";

    path.parent.classes.toggle("error", hasErrors);
    path.parent.classes.toggle("warning", hasWarnings && !hasErrors);
  }

  void _jumpTo(int line, int charStart, int charLength, {bool focus: false}) {
    Document doc = editor.document;

    doc.select(
        doc.posFromIndex(charStart),
        doc.posFromIndex(charStart + charLength));

    if (focus) editor.focus();
  }
}

// TODO: create pages (dart / html / css)

class PlaygroundContext extends Context {
  final Editor editor;

  Document _dartDoc;
  Document _htmlDoc;
  Document _cssDoc;

  StreamController _cssDirtyController = new StreamController.broadcast();
  StreamController _dartDirtyController = new StreamController.broadcast();
  StreamController _htmlDirtyController = new StreamController.broadcast();

  StreamController _cssReconcileController = new StreamController.broadcast();
  StreamController _dartReconcileController = new StreamController.broadcast();
  StreamController _htmlReconcileController = new StreamController.broadcast();

  PlaygroundContext(this.editor) {
    editor.mode = 'dart';
    _dartDoc = editor.document;
    _htmlDoc = editor.createDocument(content: '', mode: 'html');
    _cssDoc = editor.createDocument(content: '', mode: 'css');

    _dartDoc.onChange.listen((_) => _dartDirtyController.add(null));
    _htmlDoc.onChange.listen((_) => _htmlDirtyController.add(null));
    _cssDoc.onChange.listen((_) => _cssDirtyController.add(null));

    _createReconciler(_cssDoc, _cssReconcileController, 250);
    _createReconciler(_dartDoc, _dartReconcileController, 1250);
    _createReconciler(_htmlDoc, _htmlReconcileController, 250);
  }

  Document get dartDocument => _dartDoc;

  String get dartSource => _dartDoc.value;
  set dartSource(String value) {
    _dartDoc.value = value;
  }

  String get htmlSource => _htmlDoc.value;
  set htmlSource(String value) {
    _htmlDoc.value = value;
  }

  String get cssSource => _cssDoc.value;
  set cssSource(String value) {
    _cssDoc.value = value;
  }

  String get activeMode => editor.mode;

  void switchTo(String name) {
    if (name == 'dart') {
      editor.swapDocument(_dartDoc);
    } else if (name == 'html') {
      editor.swapDocument(_htmlDoc);
    } else if (name == 'css') {
      editor.swapDocument(_cssDoc);
    }

    editor.focus();
  }

  String get focusedEditor {
    if (editor.document == _htmlDoc) return 'html';
    if (editor.document == _cssDoc) return 'css';
    return 'dart';
  }

  Stream get onCssDirty => _cssDirtyController.stream;
  Stream get onDartDirty => _dartDirtyController.stream;
  Stream get onHtmlDirty => _htmlDirtyController.stream;

  Stream get onCssReconcile => _cssReconcileController.stream;
  Stream get onDartReconcile => _dartReconcileController.stream;
  Stream get onHtmlReconcile => _htmlReconcileController.stream;

  void markCssClean() => _cssDoc.markClean();
  void markDartClean() => _dartDoc.markClean();
  void markHtmlClean() => _htmlDoc.markClean();

  /**
   * Restore the focus to the last focused editor.
   */
  void focus() => editor.focus();

  void _createReconciler(Document doc, StreamController controller, int delay) {
    Timer timer;
    doc.onChange.listen((_) {
      if (timer != null) timer.cancel();
      timer = new Timer(new Duration(milliseconds: delay), () {
        controller.add(null);
      });
    });
  }
}

class InlineBracketsColon extends markdown.InlineSyntax {

  InlineBracketsColon() : super(r'\[:\s?((?:.|\n)*?)\s?:\]');

  String htmlEscape(String text) => HTML_ESCAPE.convert(text);

  @override
  bool onMatch(markdown.InlineParser parser, Match match) {
    var element = new markdown.Element.text('code', htmlEscape(match[1]));
    parser.addNode(element);
    return true;
  }
}

// TODO: [someCodeReference] should be converted to for example
// https://api.dartlang.org/apidocs/channels/stable/dartdoc-viewer/dart:core.someReference
// for now it gets converted <code>someCodeReference</code>
class InlineBrackets extends markdown.InlineSyntax {

  // This matches URL text in the documentation, with a negative filter
  // to detect if it is followed by a URL to prevent e.g.
  // [text] (http://www.example.com) getting turned into
  // <code>text</code> (http://www.example.com)
  InlineBrackets() : super(r'\[\s?((?:.|\n)*?)\s?\](?!\s?\()');

  String htmlEscape(String text) => HTML_ESCAPE.convert(text);

  @override
  bool onMatch(markdown.InlineParser parser, Match match) {
    var element = new markdown.Element.text(
        'code', "<em>${htmlEscape(match[1])}</em>");
    parser.addNode(element);
    return true;
  }
}

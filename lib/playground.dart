// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library playground;

import 'dart:async';
import 'dart:html' hide Document;

import 'package:logging/logging.dart';
import 'package:rate_limit/rate_limit.dart';
import 'package:route_hierarchical/client.dart';

import 'completion.dart';
import 'context.dart';
import 'core/dependencies.dart';
import 'core/keys.dart';
import 'core/modules.dart';
import 'dart_pad.dart';
import 'dialogs.dart';
import 'documentation.dart';
import 'editing/editor.dart';
import 'elements/bind.dart';
import 'elements/elements.dart';
import 'modules/codemirror_module.dart';
import 'modules/dart_pad_module.dart';
import 'modules/dartservices_module.dart';
import 'parameter_popup.dart';
import 'services/common.dart';
import 'services/dartservices.dart';
import 'services/execution_iframe.dart';
import 'sharing/gists.dart';
import 'sharing/mutable_gist.dart';
import 'src/ga.dart';
import 'src/summarize.dart';
import 'src/util.dart';

Playground get playground => _playground;

Playground _playground;

Logger _logger = new Logger('dartpad');

void init() {
  _playground = new Playground();
}

class Playground implements GistContainer, GistController {
  DivElement get _editpanel => querySelector('#editpanel');
  DivElement get _outputpanel => querySelector('#output');
  IFrameElement get _frame => querySelector('#frame');
  bool get _isCompletionActive => editor.completionActive;
  DivElement get _docPanel => querySelector('#documentation');

  DButton runButton;
  DOverlay overlay;
  DBusyLight busyLight;
  DBusyLight consoleBusyLight;
  Editor editor;
  PlaygroundContext _context;
  Future _analysisRequest;
  MutableGist editableGist = new MutableGist(new Gist());
  GistStorage _gistStorage = new GistStorage();
  DContentEditable titleEditable;

  TabController sourceTabController;
  TabController outputTabController;
  SharingDialog sharingDialog;
  KeysDialog settings;

  // We store the last returned shared gist; it's used to update the url.
  Gist _overrideNextRouteGist;
  ParameterPopup paramPopup;
  DocHandler docHandler;

  ModuleManager modules = new ModuleManager();

  Playground() {
    sourceTabController = new TabController();
    for (String name in ['dart', 'html', 'css']) {
      sourceTabController.registerTab(new TabElement(querySelector('#${name}tab'),
          name: name, onSelect: () {
        Element issuesElement = querySelector('#issues');
        issuesElement.style.display = name == 'dart' ? 'block' : 'none';
        ga.sendEvent('edit', name);
        _context.switchTo(name);
      }));
    }

    overlay = new DOverlay(querySelector('#frame_overlay'));

    sharingDialog = new SharingDialog(this, this);

    DButton newButton = new DButton(querySelector('#newbutton'));
    OkCancelDialog newDialog = new OkCancelDialog(
      'Create New Pad', 'Discard changes to the current pad?',
        this.createNewGist, okText: 'Discard');
    newButton.onClick.listen((_) {
      newDialog.show();
    });

    DButton resetButton = new DButton(querySelector('#resetbutton'));
    OkCancelDialog resetDialog = new OkCancelDialog('Reset Pad',
      'Discard changes to the current pad?', _resetGists, okText: 'Discard',
        cancelText: 'Cancel');
    resetButton.onClick.listen((_) {
      resetDialog.show();
    });

    editableGist.onDirtyChanged.listen((val) {
      resetButton.disabled = !val;
    });

    DButton shareButton = new DButton(querySelector('#sharebutton'));
    shareButton.onClick.listen((e) => _createSummary()
        .then((String sum) => sharingDialog.showWithSummary(sum)));
    runButton = new DButton(querySelector('#runbutton'));
    runButton.onClick.listen((e) {
      _handleRun();

      // On a mobile device, focusing the editing area causes the keyboard to
      // pop up when the user hits the run button.
      if (!isMobile()) _context.focus();
    });

    // Listen for the keyboard button.
    querySelector('#keyboard-button').onClick.listen((_) => settings.show());

    busyLight = new DBusyLight(querySelector('#dartbusy'));
    consoleBusyLight = new DBusyLight(querySelector('#consolebusy'));

    // Update the title on changes.
    titleEditable =
        new DContentEditable(querySelector('header .header-gist-name'));
    bind(titleEditable.onChanged, editableGist.property('description'));
    bind(editableGist.property('description'), titleEditable.textProperty);
    editableGist.onDirtyChanged.listen((val) {
      titleEditable.element.classes.toggle('dirty', val);
    });

    // If there was a change, and the gist is dirty, write the gist's contents
    // to storage.
    Throttler throttle = new Throttler(const Duration(milliseconds: 100));
    mutableGist.onChanged.transform(throttle).listen((_) {
      if (mutableGist.dirty) {
        _gistStorage.setStoredGist(mutableGist.createGist());
      }
    });

    SelectElement select = querySelector('#samples');
    select.onChange.listen((_) => _handleSelectChanged(select));

    // Show the about box on title clicks.
    querySelector('div.header-title').onClick.listen((e) {
      e.preventDefault();

      dartServices
          .version()
          .timeout(new Duration(seconds: 2))
          .then((VersionResponse ver) {
        new AboutDialog(ver.sdkVersion)..show();
      }).catchError((e) {
        new AboutDialog()..show();
      });
    });

    _initModules().then((_) {
      _initPlayground();
    });
  }

  void _resetGists() {
    _gistStorage.clearStoredGist();
    editableGist.reset();
    // Delay to give time for the model change event to propogate through
    // to the editor component (which is where `_performAnalysis()` pulls
    // the Dart source from).
    Timer.run(() => _performAnalysis());
  }
  void showHome(RouteEnterEvent event) {
    // Don't auto-run if we're re-loading some unsaved edits; the gist might
    // have halting issues (#384).
    bool loadedFromSaved = false;
    Uri url = Uri.parse(window.location.toString());
    if (url.hasQuery && url.queryParameters['dart'] != null) {
      Gist blankGist = createSampleGist();
      blankGist.getFile('main.dart').content = url.queryParameters['dart'];
      blankGist.getFile('index.html').content = url.queryParameters['html'];
      blankGist.getFile('styles.css').content = url.queryParameters['css'];
      editableGist.setBackingGist(blankGist);
    } else if (_gistStorage.hasStoredGist && _gistStorage.storedId == null) {
      loadedFromSaved = true;

      Gist blankGist = new Gist();
      editableGist.setBackingGist(blankGist);

      Gist storedGist = _gistStorage.getStoredGist();
      editableGist.description = storedGist.description;
      for (GistFile file in storedGist.files) {
        editableGist.getGistFile(file.name).content = file.content;
      }
    } else {
      editableGist.setBackingGist(createSampleGist());
    }

    _clearOutput();
    // We delay this because of the latency in populating the editors from the
    // gist data.
    Timer.run(_autoSwitchSourceTab);

    // Analyze and run it.
    Timer.run(() {
      _performAnalysis().then((bool result) {
        // Only auto-run if the static analysis comes back clean.
        if (result && !loadedFromSaved) _handleRun();
      }).catchError((e) => null);
    });
  }

  void showGist(RouteEnterEvent event) {
    String gistId = event.parameters['gist'];

    if (!isLegalGistId(gistId)) {
      showHome(event);
      return;
    }

    _showGist(gistId);
  }

  // GistContainer interface
  MutableGist get mutableGist => editableGist;

  void overrideNextRoute(Gist gist) {
    _overrideNextRouteGist = gist;
  }

  Future createNewGist() {
    _gistStorage.clearStoredGist();

    if (ga != null) ga.sendEvent('main', 'new');

    DToast.showMessage('New pad created');
    router.go('gist', {'gist': ''}, forceReload: true);

    return new Future.value();
  }

  Future shareAnon({String summary: ""}) {
    return gistLoader
        .createAnon(mutableGist.createGist(summary: summary))
        .then((Gist newGist) {
      editableGist.setBackingGist(newGist);
      overrideNextRoute(newGist);
      router.go('gist', {'gist': newGist.id});
      var toast = new DToast('Created ${newGist.id}')
        ..show()
        ..hide();
      toast.element
        ..style.cursor = "pointer"
        ..onClick.listen((e) => window.open(
            "https://gist.github.com/anonymous/${newGist.id}", '_blank'));
    }).catchError((e) {
      String message = 'Error saving gist: ${e}';
      DToast.showMessage(message);
      ga.sendException('GistLoader.createAnon: failed to create gist');
    });
  }

  void _showGist(String gistId) {
    // Don't auto-run if we're re-loading some unsaved edits; the gist might
    // have halting issues (#384).
    bool loadedFromSaved = false;

    // When sharing, we have to pipe the returned (created) gist through the
    // routing library to update the url properly.
    if (_overrideNextRouteGist != null && _overrideNextRouteGist.id == gistId) {
      editableGist.setBackingGist(_overrideNextRouteGist);
      _overrideNextRouteGist = null;
      return;
    }

    _overrideNextRouteGist = null;

    gistLoader.loadGist(gistId).then((Gist gist) {
      editableGist.setBackingGist(gist);

      if (_gistStorage.hasStoredGist && _gistStorage.storedId == gistId) {
        loadedFromSaved = true;

        Gist storedGist = _gistStorage.getStoredGist();
        editableGist.description = storedGist.description;
        for (GistFile file in storedGist.files) {
          editableGist.getGistFile(file.name).content = file.content;
        }
      }

      _clearOutput();
      // We delay this because of the latency in populating the editors from the
      // gist data.
      Timer.run(_autoSwitchSourceTab);

      // Analyze and run it.
      Timer.run(() {
        _performAnalysis().then((bool result) {
          // Only auto-run if the static analysis comes back clean.
          if (result && !loadedFromSaved) _handleRun();
        }).catchError((e) => null);
      });
    }).catchError((e) {
      String message = 'Error loading gist ${gistId}.';
      DToast.showMessage(message);
      _logger.severe('${message}: ${e}');
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
    var disablePointerEvents = () {
      _frame.style.pointerEvents = "none";
    };
    var enablePointerEvents = () {
      _frame.style.pointerEvents = "inherit";
    };

    // TODO: Set up some automatic value bindings.
    DSplitter editorSplitter = new DSplitter(querySelector('#editor_split'),
        onDragStart: disablePointerEvents, onDragEnd: enablePointerEvents);
    editorSplitter.onPositionChanged.listen((pos) {
      state['editor_split'] = pos;
      editor.resize();
    });
    if (state['editor_split'] != null) {
      editorSplitter.position = state['editor_split'];
    }

    DSplitter outputSplitter = new DSplitter(querySelector('#output_split'),
        onDragStart: disablePointerEvents, onDragEnd: enablePointerEvents);
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

    // Set up Google Analytics.
    deps[Analytics] = new Analytics();

    // Set up the gist loader.
    deps[GistLoader] = new GistLoader.defaultFilters();

    // Set up the editing area.
    editor = editorFactory.createFromElement(_editpanel);
    _editpanel.children.first.attributes['flex'] = '';
    editor.resize();

    keys.bind(['ctrl-s'], _handleSave, "Save", hidden: true);
    keys.bind(['ctrl-enter'], _handleRun, "Run");
    keys.bind(['f1'], () {
      ga.sendEvent('main', 'help');
      docHandler.generateDoc(_docPanel);
    }, "Documentation");

    keys.bind(['alt-enter', 'ctrl-1'], () {
      editor.showCompletions(onlyShowFixes: true);
    }, "Quick fix");

    keys.bind(['ctrl-space', 'macctrl-space'], () {
      editor.showCompletions();
    }, "Completion");

    keys.bind(['shift-ctrl-/', 'shift-macctrl-/'], () {
      if (settings.isShowing) {
        settings.hide();
      } else {
        settings.show();
      }
    }, "Shortcuts");

    settings = new KeysDialog(keys.inverseBindings);

    document.onKeyUp.listen((e) {
      if (editor.completionActive ||
          DocHandler.cursorKeys.contains(e.keyCode)) {
        docHandler.generateDoc(_docPanel);
      }
      _handleAutoCompletion(e);
    });

    outputTabController = new TabController()
      ..registerTab(new TabElement(querySelector('#resulttab'),
          name: "result", onSelect: () {
        ga.sendEvent('view', "result");
        querySelector('#frame').style.visibility = "visible";
        querySelector('#output').style.visibility = "hidden";
      }))
      ..registerTab(new TabElement(querySelector('#consoletab'),
          name: "console", onSelect: () {
        ga.sendEvent('view', "console");
        querySelector('#output').style.visibility = "visible";
        querySelector('#frame').style.visibility = "hidden";
      }));

    _context = new PlaygroundContext(editor);
    deps[Context] = _context;

    editorFactory.registerCompleter(
        'dart', new DartCompleter(dartServices, _context._dartDoc));

    _context.onHtmlDirty.listen((_) => busyLight.on());
    _context.onHtmlReconcile.listen((_) {
      executionService.replaceHtml(_context.htmlSource);
      busyLight.reset();
    });

    _context.onCssDirty.listen((_) => busyLight.on());
    _context.onCssReconcile.listen((_) {
      executionService.replaceCss(_context.cssSource);
      busyLight.reset();
    });

    _context.onDartDirty.listen((_) => busyLight.on());
    _context.onDartReconcile.listen((_) => _performAnalysis());

    // Listen for changes that would effect the documentation panel.
    editor.onMouseDown.listen((e) {
      // Delay to give codemirror time to process the mouse event.
      Timer.run(() {
        if (!_context.cursorPositionIsWhitespace()) {
          docHandler.generateDoc(_docPanel);
        }
      });
    });
    context.onModeChange.listen((_) => docHandler.generateDoc(_docPanel));

    // Bind the editable files to the gist.
    Property htmlFile = new GistFileProperty(editableGist.getGistFile('index.html'));
    Property htmlDoc = new EditorDocumentProperty(_context.htmlDocument, 'html');
    bind(htmlDoc, htmlFile);
    bind(htmlFile, htmlDoc);

    Property cssFile = new GistFileProperty(editableGist.getGistFile('styles.css'));
    Property cssDoc = new EditorDocumentProperty(_context.cssDocument, 'css');
    bind(cssDoc, cssFile);
    bind(cssFile, cssDoc);

    Property dartFile = new GistFileProperty(editableGist.getGistFile('main.dart'));
    Property dartDoc = new EditorDocumentProperty(_context.dartDocument, 'dart');
    bind(dartDoc, dartFile);
    bind(dartFile, dartDoc);

    // Set up the router.
    deps[Router] = new Router();
    router.root.addRoute(name: 'home', defaultRoute: true, enter: showHome);
    router.root.addRoute(name: 'gist', path: '/:gist', enter: showGist);
    router.listen();

    // Set up development options.
    options.registerOption('autopopup_code_completion', 'false');
    options.registerOption('parameter_popup', 'false');

    if (options.getValueBool("parameter_popup")) {
      paramPopup = new ParameterPopup(context, editor);
    }

    docHandler = new DocHandler(editor, _context);

    _finishedInit();
  }

  _finishedInit() {
    // Clear the splash.
    DSplash splash = new DSplash(querySelector('div.splash'));
    splash.hide();
  }

  _handleAutoCompletion(KeyboardEvent e) {
    if (context.focusedEditor == 'dart' && editor.hasFocus) {
      if (e.keyCode == KeyCode.PERIOD) {
        editor.showCompletions(autoInvoked: true);
      }
    }

    if (!options.getValueBool('autopopup_code_completion') ||
        _isCompletionActive ||
        !editor.hasFocus) {
      return;
    }

    if (context.focusedEditor == 'dart') {
      RegExp exp = new RegExp(r"[A-Z]");
      if (exp.hasMatch(new String.fromCharCode(e.keyCode))) {
        editor.showCompletions(autoInvoked: true);
      }
    } else if (context.focusedEditor == "html") {
      // TODO: Autocompletion for attributes.
      if (printKeyEvent(e) == "shift-,") {
        editor.showCompletions(autoInvoked: true);
      }
    } else if (context.focusedEditor == "css") {
      RegExp exp = new RegExp(r"[A-Z]");
      if (exp.hasMatch(new String.fromCharCode(e.keyCode))) {
        editor.showCompletions(autoInvoked: true);
      }
    }
  }

  void _handleRun() {
    ga.sendEvent('main', 'run');
    runButton.disabled = true;
    overlay.visible = true;

    _clearOutput();

    Stopwatch compilationTimer = new Stopwatch()..start();

    var input = new CompileRequest()..source = context.dartSource;
    dartServices
        .compile(input)
        .timeout(longServiceCallTimeout)
        .then((CompileResponse response) {
      ga.sendTiming('action-perf', "compilation-e2e",
          compilationTimer.elapsedMilliseconds);

      _autoSwitchOutputTab();

      return executionService.execute(
          _context.htmlSource, _context.cssSource, response.result);
    }).catchError((e) {
      ga.sendException("${e.runtimeType}");
      if (e is DetailedApiRequestError) e = e.message;
      DToast.showMessage('Error compiling to JavaScript');
      _showOuput('Error compiling to JavaScript:\n${e}', error: true);
    }).whenComplete(() {
      runButton.disabled = false;
      overlay.visible = false;
    });
  }

  /// Switch to the Dart / Html / Css tab depending on the sample type.
  void _autoSwitchSourceTab() {
    String htmlSrc = _context.htmlSource.trim();
    String dartSrc = _context.dartSource.trim();

    if (htmlSrc.isEmpty && dartSrc.isNotEmpty) {
      sourceTabController.selectTab('dart');
    }
  }

  /// Switch to the console or html results tab depending on whether the sample
  /// has html content or not.
  void _autoSwitchOutputTab() {
    String htmlSrc = _context.htmlSource.trim();
    String dartSrc = _context.dartSource.trim();

    if (htmlSrc.isNotEmpty) {
      outputTabController.selectTab('result');
    } else if (dartSrc.contains("'dart:html'") || dartSrc.contains('"dart:html"')) {
      outputTabController.selectTab('result');
    } else {
      outputTabController.selectTab('console');
    }
  }

  Future<String> _createSummary() {
    SourceRequest input = new SourceRequest()..source = _context.dartSource;
    return dartServices
        .analyze(input)
        .timeout(shortServiceCallTimeout)
        .then((AnalysisResults result) {
      Summarizer summer = new Summarizer(
          dart: _context.dartSource,
          html: _context.htmlSource,
          css: _context.cssSource,
          analysis: result);
      return summer.returnAsSimpleSummary();
    }).catchError((e) {
      _logger.severe(e);
    });
  }

  /// Perform static analysis of the source code. Return whether the code
  /// analyzed cleanly (had no errors or warnings).
  Future<bool> _performAnalysis() {
    SourceRequest input = new SourceRequest()..source = _context.dartSource;
    Lines lines = new Lines(input.source);

    Future request = dartServices.analyze(input).timeout(serviceCallTimeout);
    _analysisRequest = request;

    return request.then((AnalysisResults result) {
      // Discard if we requested another analysis.
      if (_analysisRequest != request) return false;

      // Discard if the document has been mutated since we requested analysis.
      if (input.source != _context.dartSource) return false;

      busyLight.reset();

      _displayIssues(result.issues);

      _context.dartDocument.setAnnotations(result.issues
          .map((AnalysisIssue issue) {
        int startLine = lines.getLineForOffset(issue.charStart);
        int endLine =
            lines.getLineForOffset(issue.charStart + issue.charLength);

        Position start = new Position(
            startLine, issue.charStart - lines.offsetForLine(startLine));
        Position end = new Position(endLine, issue.charStart +
            issue.charLength -
            lines.offsetForLine(startLine));

        return new Annotation(issue.kind, issue.message, issue.line,
            start: start, end: end);
      }).toList());

      bool hasErrors = result.issues.any((issue) => issue.kind == 'error');
      bool hasWarnings = result.issues.any((issue) => issue.kind == 'warning');

      _updateRunButton(hasErrors: hasErrors, hasWarnings: hasWarnings);

      return hasErrors == false && hasWarnings == false;
    }).catchError((e) {
      _context.dartDocument.setAnnotations([]);
      busyLight.reset();
      _updateRunButton();
      _logger.severe(e);
    });
  }

  void _handleSave() => ga.sendEvent('main', 'save');

  void _clearOutput() {
    _outputpanel.text = '';
  }

  List<SpanElement> _bufferedOutput = [];
  Duration _outputDuration = new Duration(milliseconds: 32);

  void _showOuput(String message, {bool error: false}) {
    consoleBusyLight.flash();

    SpanElement span = new SpanElement()..text = message + '\n';
    span.classes.add(error ? 'errorOutput' : 'normal');

    // Buffer the console output so that heavy writing to stdout does not starve
    // the DOM thread.
    _bufferedOutput.add(span);

    if (_bufferedOutput.length == 1) {
      new Timer(_outputDuration, () {
        _outputpanel.children.addAll(_bufferedOutput);
        _outputpanel.children.last.scrollIntoView(ScrollAlignment.BOTTOM);
        _bufferedOutput.clear();
      });
    }
  }

  void _handleSelectChanged(SelectElement select) {
    String value = select.value;

    if (isLegalGistId(value)) {
      router.go('gist', {'gist': value});
    }

    select.value = '0';
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
        e.attributes['layout'] = '';
        e.attributes['horizontal'] = '';
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
        messageSpan.attributes['flex'] = '';
        messageSpan.text = issue.message;
        e.children.add(messageSpan);
        if (issue.hasFixes) {
          e.classes.add("hasFix");
          e.onClick.listen((e) {
            // This is a bit of a hack to make sure quick fixes popup
            // is only shown if the wrench is clicked,
            // and not if the text or label is clicked.
            if ((e.target as Element).className == "issue hasFix") {
              // codemiror only shows completions if there is no selected text
              _jumpTo(issue.line, issue.charStart, 0, focus: true);
              editor.showCompletions(onlyShowFixes: true);
            }
          });
        }
      }

      issuesElement.classes.toggle('showing', issues.isNotEmpty);
    }
  }

  void _updateRunButton({bool hasErrors: false, bool hasWarnings: false}) {
    const alertSVGIcon =
        "M5,3H19A2,2 0 0,1 21,5V19A2,2 0 0,1 19,21H5A2,2 0 0,1 3,19V5A2,2 0 0,"
        "1 5,3M13,13V7H11V13H13M13,17V15H11V17H13Z";

    var path = runButton.element.querySelector("path");
    path.attributes["d"] =
        (hasErrors || hasWarnings) ? alertSVGIcon : "M8 5v14l11-7z";

    path.parent.classes.toggle("error", hasErrors);
    path.parent.classes.toggle("warning", hasWarnings && !hasErrors);
  }

  void _jumpTo(int line, int charStart, int charLength, {bool focus: false}) {
    Document doc = editor.document;

    doc.select(
        doc.posFromIndex(charStart), doc.posFromIndex(charStart + charLength));

    if (focus) editor.focus();
  }
}

class PlaygroundContext extends Context {
  final Editor editor;

  StreamController<String> _modeController = new StreamController.broadcast();

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
  Document get htmlDocument => _htmlDoc;
  Document get cssDocument => _cssDoc;

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

  Stream<String> get onModeChange => _modeController.stream;

  void switchTo(String name) {
    String oldMode = activeMode;

    if (name == 'dart') {
      editor.swapDocument(_dartDoc);
    } else if (name == 'html') {
      editor.swapDocument(_htmlDoc);
    } else if (name == 'css') {
      editor.swapDocument(_cssDoc);
    }

    if (oldMode != name) _modeController.add(name);

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

  /// Return true if the current cursor position is in a whitespace char.
  bool cursorPositionIsWhitespace() {
    Document document = editor.document;
    String str = document.value;
    int index = document.indexFromPos(document.cursor);
    if (index < 0 || index >= str.length) return false;
    String char = str[index];
    return char != char.trim();
  }
}

class GistFileProperty implements Property {
  final MutableGistFile file;

  GistFileProperty(this.file);

  get() => file.content;

  void set(value) {
    if (file.content != value) {
      file.content = value;
    }
  }

  Stream get onChanged => file.onChanged.map((value) {
    return value;
  });
}

class EditorDocumentProperty implements Property {
  final Document document;
  final String debugName;

  EditorDocumentProperty(this.document, [this.debugName]);

  get() => document.value;

  void set(str) {
    document.value = str == null ? '' : str;
  }

  Stream get onChanged => document.onChange.map((_) => get());
}

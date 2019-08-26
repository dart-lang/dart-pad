// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library new_playground;

import 'dart:async';
import 'dart:collection';
import 'dart:html';

import 'package:logging/logging.dart';
import 'package:mdc_web/mdc_web.dart';
import 'package:route_hierarchical/client.dart';
import 'package:split/split.dart';

import 'context.dart';
import 'core/dependencies.dart';
import 'core/modules.dart';
import 'dart_pad.dart';
import 'editing/editor.dart';
import 'elements/bind.dart';
import 'elements/elements.dart';
import 'experimental/dialog.dart';
import 'modules/codemirror_module.dart';
import 'modules/dart_pad_module.dart';
import 'modules/dartservices_module.dart';
import 'playground_context.dart';
import 'services/_dartpadsupportservices.dart';
import 'services/common.dart';
import 'services/dartservices.dart';
import 'services/execution_iframe.dart';
import 'sharing/editor_doc_property.dart';
import 'sharing/gist_file_property.dart';
import 'sharing/gists.dart';
import 'sharing/mutable_gist.dart';
import 'src/ga.dart';
import 'src/util.dart';

Playground get playground => _playground;

Playground _playground;

final Logger _logger = Logger('dartpad');

void init() {
  _playground = Playground();
}

class Playground implements GistContainer, GistController {
  final MutableGist editableGist = MutableGist(Gist());
  final GistStorage _gistStorage = GistStorage();
  MDCButton newButton;
  MDCButton resetButton;
  MDCButton formatButton;
  MDCButton shareButton;
  MDCButton samplesButton;
  MDCButton runButton;
  MDCMenu samplesMenu;
  Dialog dialog;
  DContentEditable titleEditable;

  Splitter splitter;

  DBusyLight busyLight;
  DBusyLight consoleBusyLight;

  Editor editor;
  PlaygroundContext _context;
  Future _analysisRequest;
  Layout _layout;

  // The last returned shared gist used to update the url.
  Gist _overrideNextRouteGist;

  // The internal ID of the current Gist.
  String _mappingId;

  Playground() {
    _initDialog();
    _initBusyLights();
    _initGistNameHeader();
    _initGistStorage();
    _initButtons();
    _initSamplesMenu();
    _initSplitters();
    _initLayout();
    _initModules().then((_) {
      _initPlayground();
    });
  }

  DivElement get _editorHost => querySelector('#editor-host');
  DivElement get _outputHost => querySelector('#output-host');
  IFrameElement get _frame => querySelector('#frame');
  InputElement get dartCheckbox => querySelector('#dart-checkbox');
  InputElement get webCheckbox => querySelector('#web-checkbox');
  InputElement get flutterCheckbox => querySelector('#flutter-checkbox');
  Map<InputElement, Layout> get _layouts => {
        flutterCheckbox: Layout.flutter,
        dartCheckbox: Layout.dart,
        webCheckbox: Layout.web,
      };

  void _initDialog() {
    dialog = Dialog();
  }

  void _initBusyLights() {
    busyLight = DBusyLight(querySelector('#dartbusy'));
    consoleBusyLight = DBusyLight(querySelector('#consolebusy'));
  }

  void _initGistNameHeader() {
    // Update the title on changes.
    titleEditable = DContentEditable(querySelector('header .header-gist-name'));
    bind(titleEditable.onChanged, editableGist.property('description'));
    bind(editableGist.property('description'), titleEditable.textProperty);
    editableGist.onDirtyChanged.listen((val) {
      titleEditable.element.classes.toggle('dirty', val);
    });
  }

  void _initGistStorage() {
    // If there was a change, and the gist is dirty, write the gist's contents
    // to storage.
    debounceStream(mutableGist.onChanged, Duration(milliseconds: 100))
        .listen((_) {
      if (mutableGist.dirty) {
        _gistStorage.setStoredGist(mutableGist.createGist());
      }
    });
  }

  void _initButtons() {
    newButton = MDCButton(querySelector('#new-button'))
      ..onClick.listen((_) => _showCreateGistDialog());
    resetButton = MDCButton(querySelector('#reset-button'))
      ..onClick.listen((_) => _showResetDialog());
    formatButton = MDCButton(querySelector('#format-button'))
      ..onClick.listen((_) => _format());
    shareButton = MDCButton(querySelector('#share-button'))
      ..onClick.listen((_) => _showSharingPage());
    samplesButton = MDCButton(querySelector('#samples-dropdown-button'))
      ..onClick.listen((e) {
        samplesMenu.open = !samplesMenu.open;
      });
    runButton = MDCButton(querySelector('#run-button'))
      ..onClick.listen((_) {
        _handleRun();
      });
  }

  void _initSamplesMenu() {
    var element = querySelector('#samples-menu');

    // Use SplayTreeMap to keep the order of the keys
    var samples = SplayTreeMap()
      ..addEntries([
        MapEntry('215ba63265350c02dfbd586dfd30b8c3', 'Hello World'),
        MapEntry('e93b969fed77325db0b848a85f1cf78e', 'Int to Double'),
        MapEntry('b60dc2fc7ea49acecb1fd2b57bf9be57', 'Mixins'),
        MapEntry('7d78af42d7b0aedfd92f00899f93561b', 'Fibonacci'),
        MapEntry('a559420eed617dab7a196b5ea0b64fba', 'Sunflower'),
        MapEntry('cb9b199b1085873de191e32a1dd5ca4f', 'WebSockets'),
      ]);

    var listElement = UListElement()
      ..classes.add('mdc-list')
      ..attributes.addAll({
        'aria-hidden': 'true',
        'aria-orientation': 'vertical',
        'tabindex': '-1'
      });

    element.children.add(listElement);

    // Helper function to create LIElement with correct attributes and classes
    // for material-components-web
    LIElement _menuElement(String gistId, String name) {
      return LIElement()
        ..classes.add('mdc-list-item')
        ..attributes.addAll({'role': 'menuitem'})
        ..children.add(
          SpanElement()
            ..classes.add('mdc-list-item__text')
            ..text = name,
        );
    }

    for (var gistId in samples.keys) {
      listElement.children.add(_menuElement(gistId, samples[gistId]));
    }

    samplesMenu = MDCMenu(element)
      ..setAnchorCorner(AnchorCorner.bottomLeft)
      ..setAnchorElement(querySelector('#samples-dropdown-button'))
      ..hoistMenuToBody();

    samplesMenu.listen('MDCMenu:selected', (e) {
      print('samplesMenu selected');
      var index = (e as CustomEvent).detail['index'];
      var gistId = samples.keys.elementAt(index);
      router.go('gist', {'gist': gistId});
    });
  }

  void _initSplitters() {
    var editorPanel = querySelector('#editor-panel');
    var outputPanel = querySelector('#output-panel');

    splitter = flexSplit(
      [editorPanel, outputPanel],
      horizontal: true,
      gutterSize: 6,
      sizes: [50, 50],
      minSize: [100, 100],
    );
  }

  void _initLayout() {
    _changeLayout(Layout.dart);
    for (var checkbox in _layouts.keys) {
      checkbox.onClick.listen((event) {
        event.preventDefault();
        Timer(Duration(milliseconds: 100), () {
          _changeLayout(_layouts[checkbox]);
        });
      });
    }
  }

  Future _initModules() async {
    ModuleManager modules = ModuleManager();

    modules.register(DartPadModule());
    modules.register(DartServicesModule());
    modules.register(DartSupportServicesModule());
    modules.register(CodeMirrorModule());

    await modules.start();
  }

  void _initPlayground() {
    // Set up the iframe.
    deps[ExecutionService] = ExecutionServiceIFrame(_frame);
    executionService.onStdout.listen(_showOutput);
    executionService.onStderr.listen((m) => _showOutput(m, error: true));

    // Set up Google Analytics.
    deps[Analytics] = Analytics();

    // Set up the gist loader.
    deps[GistLoader] = GistLoader.defaultFilters();

    // Set up CodeMirror
    editor = editorFactory.createFromElement(_editorHost)
      ..theme = 'darkpad'
      ..mode = 'dart';

    _context = PlaygroundContext(editor);
    deps[Context] = _context;

    _context.onDartDirty.listen((_) => busyLight.on());
    _context.onDartReconcile.listen((_) => _performAnalysis());

    Property htmlFile =
        GistFileProperty(editableGist.getGistFile('index.html'));
    Property htmlDoc = EditorDocumentProperty(_context.htmlDocument, 'html');
    bind(htmlDoc, htmlFile);
    bind(htmlFile, htmlDoc);

    Property cssFile = GistFileProperty(editableGist.getGistFile('styles.css'));
    Property cssDoc = EditorDocumentProperty(_context.cssDocument, 'css');
    bind(cssDoc, cssFile);
    bind(cssFile, cssDoc);

    Property dartFile = GistFileProperty(editableGist.getGistFile('main.dart'));
    Property dartDoc = EditorDocumentProperty(_context.dartDocument, 'dart');
    bind(dartDoc, dartFile);
    bind(dartFile, dartDoc);

    // Set up the router.
    deps[Router] = Router();
    router.root.addRoute(name: 'home', defaultRoute: true, enter: showHome);
    router.root.addRoute(name: 'gist', path: '/:gist', enter: showGist);
    router.listen();

    dartServices.version().then((VersionResponse version) {
      // "Based on Dart SDK 2.4.0"
      String versionText = 'Based on Dart SDK ${version.sdkVersionFull}';
      querySelector('#dartpad-version').text = versionText;
    }).catchError((e) => null);

    _finishedInit();
  }

  void _finishedInit() {
    // Clear the splash.
    DSplash splash = DSplash(querySelector('div.splash'));
    splash.hide();
  }

  Future showHome(RouteEnterEvent event) async {
    // Don't auto-run if we're re-loading some unsaved edits; the gist might
    // have halting issues (#384).
    bool loadedFromSaved = false;
    Uri url = Uri.parse(window.location.toString());

    if (url.hasQuery &&
        url.queryParameters['id'] != null &&
        isLegalGistId(url.queryParameters['id'])) {
      _showGist(url.queryParameters['id']);
    } else if (url.hasQuery && url.queryParameters['export'] != null) {
      UuidContainer requestId = UuidContainer()
        ..uuid = url.queryParameters['export'];
      Future<PadSaveObject> exportPad =
          dartSupportServices.pullExportContent(requestId);
      await exportPad.then((pad) {
        Gist blankGist = createSampleGist();
        blankGist.getFile('main.dart').content = pad.dart;
        blankGist.getFile('index.html').content = pad.html;
        blankGist.getFile('styles.css').content = pad.css;
        editableGist.setBackingGist(blankGist);
      });
    } else if (url.hasQuery && url.queryParameters['source'] != null) {
      UuidContainer gistId = await dartSupportServices.retrieveGist(
          id: url.queryParameters['source']);
      Gist backing;

      try {
        backing = await gistLoader.loadGist(gistId.uuid);
      } catch (ex) {
        print(ex);
        backing = Gist();
      }

      editableGist.setBackingGist(backing);
      await router.go('gist', {'gist': backing.id});
    } else if (_gistStorage.hasStoredGist && _gistStorage.storedId == null) {
      loadedFromSaved = true;

      Gist blankGist = Gist();
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

    // Analyze and run it.
    Timer.run(() {
      _performAnalysis().then((bool result) {
        // Only auto-run if the static analysis comes back clean.
        if (result && !loadedFromSaved) _handleRun();
        if (url.hasQuery && url.queryParameters['line'] != null) {
          _jumpToLine(int.parse(url.queryParameters['line']));
        }
      }).catchError((e) => null);
    });
  }

  void showGist(RouteEnterEvent event) {
    String gistId = event.parameters['gist'];

    _clearOutput();

    if (!isLegalGistId(gistId)) {
      showHome(event);
      return;
    }

    _showGist(gistId);
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

      if ((_layout == Layout.web) != gist.hasWebContent()) {
        if (gist.hasWebContent()) {
          _changeLayout(Layout.web);
        } else {
          // TODO (johnpryan): detect if app is a dart or flutter app
          _changeLayout(Layout.dart);
        }
      }

      // Analyze and run it.
      Timer.run(() {
        _performAnalysis().then((bool result) {
          // Only auto-run if the static analysis comes back clean.
          if (result && !loadedFromSaved) _handleRun();
        }).catchError((e) => null);
      });
    }).catchError((e) {
      String message = 'Error loading gist $gistId.';
      _showSnackbar(message);
      _logger.severe('$message: $e');
    });
  }

  void _handleRun() async {
    ga.sendEvent('main', 'run');
    runButton.disabled = true;

    Stopwatch compilationTimer = Stopwatch()..start();

    final CompileRequest compileRequest = CompileRequest()
      ..source = context.dartSource;

    try {
      if (_layout == Layout.flutter) {
        final CompileDDCResponse response = await dartServices
            .compileDDC(compileRequest)
            .timeout(longServiceCallTimeout);

        ga.sendTiming(
          'action-perf',
          'compilation-e2e',
          compilationTimer.elapsedMilliseconds,
        );

        _clearOutput();

        return executionService.execute(
          _context.htmlSource,
          _context.cssSource,
          response.result,
          modulesBaseUrl: response.modulesBaseUrl,
        );
      } else {
        final CompileResponse response = await dartServices
            .compile(compileRequest)
            .timeout(longServiceCallTimeout);

        ga.sendTiming(
          'action-perf',
          'compilation-e2e',
          compilationTimer.elapsedMilliseconds,
        );

        _clearOutput();

        return await executionService.execute(
          _context.htmlSource,
          _context.cssSource,
          response.result,
        );

      }
    } catch (e) {
      ga.sendException('${e.runtimeType}');
      final message = (e is DetailedApiRequestError) ? e.message : '$e';
      _showSnackbar('Error compiling to JavaScript');
      _showOutput('Error compiling to JavaScript:\n$message', error: true);
    } finally {
      runButton.disabled = false;
    }
  }

  /// Perform static analysis of the source code. Return whether the code
  /// analyzed cleanly (had no errors or warnings).
  Future<bool> _performAnalysis() {
    SourceRequest input = SourceRequest()..source = _context.dartSource;

    Lines lines = Lines(input.source);

    Future<AnalysisResults> request =
        dartServices.analyze(input).timeout(serviceCallTimeout);
    _analysisRequest = request;

    return request.then((AnalysisResults result) {
      // Discard if we requested another analysis.
      if (_analysisRequest != request) return false;

      // Discard if the document has been mutated since we requested analysis.
      if (input.source != _context.dartSource) return false;

      busyLight.reset();

      _displayIssues(result.issues);

      _context.dartDocument
          .setAnnotations(result.issues.map((AnalysisIssue issue) {
        int startLine = lines.getLineForOffset(issue.charStart);
        int endLine =
            lines.getLineForOffset(issue.charStart + issue.charLength);

        Position start = Position(
            startLine, issue.charStart - lines.offsetForLine(startLine));
        Position end = Position(
            endLine,
            issue.charStart +
                issue.charLength -
                lines.offsetForLine(startLine));

        return Annotation(issue.kind, issue.message, issue.line,
            start: start, end: end);
      }).toList());

      bool hasErrors = result.issues.any((issue) => issue.kind == 'error');
      bool hasWarnings = result.issues.any((issue) => issue.kind == 'warning');

      // TODO: show errors or warnings

      return hasErrors == false && hasWarnings == false;
    }).catchError((e) {
      _context.dartDocument.setAnnotations([]);
      busyLight.reset();
      _logger.severe(e);
    });
  }

  Future _format() {
    String originalSource = _context.dartSource;
    SourceRequest input = SourceRequest()..source = originalSource;
    formatButton.disabled = true;

    Future<FormatResponse> request =
        dartServices.format(input).timeout(serviceCallTimeout);
    return request.then((FormatResponse result) {
      busyLight.reset();
      formatButton.disabled = false;

      if (result.newString == null || result.newString.isEmpty) {
        _logger.fine('Format returned null/empty result');
        return;
      }

      if (originalSource != result.newString) {
        editor.document.updateValue(result.newString);
        _showSnackbar('Format successful.');
      } else {
        _showSnackbar('No formatting changes.');
      }
    }).catchError((e) {
      busyLight.reset();
      formatButton.disabled = false;
      _logger.severe(e);
    });
  }

  void _clearOutput() {
    _outputHost.text = '';
  }

  final _bufferedOutput = <SpanElement>[];
  final _outputDuration = Duration(milliseconds: 32);

  void _showOutput(String message, {bool error = false}) {
    SpanElement span = SpanElement()..text = '$message\n';
    span.classes.add(error ? 'errorOutput' : 'normal');
    // Buffer the console output so that heavy writing to stdout does not starve
    // the DOM thread.
    _bufferedOutput.add(span);
    if (_bufferedOutput.length == 1) {
      Timer(_outputDuration, () {
        _outputHost.children.addAll(_bufferedOutput);
        _outputHost.children.last.scrollIntoView(ScrollAlignment.BOTTOM);
        _bufferedOutput.clear();
      });
    }
  }

  void _showSnackbar(String message) {
    var div = querySelector('.mdc-snackbar');
    var snackbar = MDCSnackbar(div)..labelText = message;
    snackbar.open();
  }

  void _changeLayout(Layout layout) {
    _layout = layout;

    for (var checkbox in _layouts.keys) {
      if (_layouts[checkbox] == layout) {
        checkbox.checked = true;
      } else {
        checkbox.checked = false;
      }
    }

    if (layout == Layout.dart) {
      _frame.hidden = true;
    } else if (layout == Layout.flutter) {
      _frame.hidden = false;
    } else if (layout == Layout.web) {
      _frame.hidden = false;
    }
  }

  // GistContainer interface
  @override
  MutableGist get mutableGist => editableGist;

  @override
  void overrideNextRoute(Gist gist) {
    _overrideNextRouteGist = gist;
  }

  Future _showCreateGistDialog() async {
    var result = await dialog.showOkCancel(
        'Create New Pad', 'Discard changes to the current pad?');
    if (result == DialogResult.ok) {
      await createNewGist();
    }
  }

  Future _showResetDialog() async {
    var result = await dialog.showOkCancel(
        'Reset Pad', 'Discard changes to the current pad?');
    if (result == DialogResult.ok) {
      _resetGists();
    }
  }

  void _showSharingPage() {
    window.open(
        'https://github.com/dart-lang/dart-pad/wiki/Sharing-Guide', '_sharing');
  }

  @override
  Future createNewGist() {
    print('clearing stored gist');
    _gistStorage.clearStoredGist();

    if (ga != null) ga.sendEvent('main', 'new');

    _showSnackbar('New pad created');
    router.go('gist', {'gist': ''}, forceReload: true);

    return Future.value();
  }

  void _resetGists() {
    _gistStorage.clearStoredGist();
    editableGist.reset();
    // Delay to give time for the model change event to propagate through
    // to the editor component (which is where `_performAnalysis()` pulls
    // the Dart source from).
    Timer.run(_performAnalysis);
    _clearOutput();
  }

  @override
  Future shareAnon({String summary = ''}) {
    return gistLoader
        .createAnon(mutableGist.createGist(summary: summary))
        .then((Gist newGist) {
      editableGist.setBackingGist(newGist);
      overrideNextRoute(newGist);
      router.go('gist', {'gist': newGist.id});
      _showSnackbar('Created ${newGist.id}');
      GistToInternalIdMapping mapping = GistToInternalIdMapping()
        ..gistId = newGist.id
        ..internalId = _mappingId;
      dartSupportServices.storeGist(mapping);
    }).catchError((e) {
      String message = 'Error saving gist: $e';
      _showSnackbar(message);
      ga.sendException('GistLoader.createAnon: failed to create gist');
    });
  }

  void _displayIssues(List<AnalysisIssue> issues) {
    // TODO(ryjohn)
  }

  void _jumpToLine(int line) {
    Document doc = editor.document;

    editor.focus();
  }
}

/// Adds a ripple effect to material design buttons
class MDCButton extends DButton {
  final MDCRipple ripple;
  MDCButton(ButtonElement element)
      : ripple = MDCRipple(element),
        super(element);
}

enum Layout {
  flutter,
  dart,
  web,
}

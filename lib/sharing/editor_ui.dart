import 'dart:async';
import 'dart:html';

import 'package:logging/logging.dart';
import 'package:mdc_web/mdc_web.dart';
import 'package:meta/meta.dart';

import '../context.dart';
import '../dart_pad.dart';
import '../editing/editor.dart';
import '../elements/analysis_results_controller.dart';
import '../elements/button.dart';
import '../elements/dialog.dart';
import '../elements/elements.dart';
import '../services/common.dart';
import '../services/dartservices.dart';
import '../services/execution.dart';
import '../util/keymap.dart';

abstract class EditorUi {
  final Logger logger = Logger('dartpad');

  ContextBase get context;

  Future<AnalysisResults>? analysisRequest;
  late final DBusyLight busyLight;
  late final AnalysisResultsController analysisResultsController;
  late final Editor editor;
  late final MDCButton runButton;
  late final ExecutionService executionService;

  /// The dialog box for information like pub package versions.
  final Dialog dialog = Dialog();

  /// The dialog box for Keyboard shortcuts/settings.
  final KeyboardDialog _keyboardDialog = KeyboardDialog();

  String get fullDartSource => context.dartSource;

  bool get shouldCompileDDC;

  bool get shouldAddFirebaseJs;

  void clearOutput();

  void showOutput(String message, {bool error = false});

  void displayIssues(List<AnalysisIssue> issues) {
    analysisResultsController.display(issues);
  }

  @mustCallSuper
  void initKeyBindings() {
    keys.bind(['ctrl-enter', 'macctrl-enter'], handleRun, 'Run');
    keys.bind(['shift-ctrl-/', 'shift-macctrl-/'], () {
      showKeyboardDialog();
    }, 'Keyboard Shortcuts');
  }

  Future<void> showKeyboardDialog() async {
    await _keyboardDialog.show(editor);
  }

  /// Show the Pub package versions which are currently in play in [dialog].
  ///
  /// Each package name links to its page at pub.dev; each package version
  /// links to the version page at pub.dev; Each link opens in a new tab.
  void showPackageVersionsDialog() {
    final directlyImportableList = StringBuffer('<dl>');
    final indirectList = StringBuffer('<dl>');
    for (final package in _packageInfo) {
      final packageUrl = 'https://pub.dev/packages/${package.name}';
      final packageLink = AnchorElement()
        ..href = packageUrl
        ..setAttribute('target', '_blank')
        ..text = package.name;
      final dt = '<dt>${packageLink.outerHtml}</dt>';
      final packageVersion = package.version;
      final versionLink = SpanElement()
        ..children.add(AnchorElement()
          ..href = '$packageUrl/versions/$packageVersion'
          ..setAttribute('target', '_blank')
          ..text = packageVersion);
      final dd = '<dd>${versionLink.outerHtml}</dd>';
      if (package.supported) {
        directlyImportableList.write(dt);
        directlyImportableList.write(dd);
      } else {
        indirectList.write(dt);
        indirectList.write(dd);
      }
    }
    directlyImportableList.write('</dl>');
    indirectList.write('</dl>');
    final directDl = Element.html(directlyImportableList.toString(),
        treeSanitizer: NodeTreeSanitizer.trusted);
    final indirectDl = Element.html(indirectList.toString(),
        treeSanitizer: NodeTreeSanitizer.trusted);

    final div = DivElement()
      ..children.add(DivElement()
        ..children
            .add(ParagraphElement()..text = 'Directly importable packages')
        ..children.add(directDl)
        ..children.add(ParagraphElement()
          ..text = 'Packages available transitively'
          ..children.add(BRElement())
          ..children.add(SpanElement()
            ..text = '(These are not directly importable.)'
            ..classes.add('muted')))
        ..children.add(indirectDl)
        ..classes.add('keys-dialog'));
    dialog.showOk('Pub package versions', div.innerHtml);
  }

  void showSnackbar(String message) => snackbar.showMessage(message);

  MDCSnackbar get snackbar => MDCSnackbar(querySelector('.mdc-snackbar')!);

  Document get currentDocument => editor.document;

  /// Perform static analysis of the source code. Return whether the code
  /// analyzed cleanly (had no errors or warnings).
  Future<bool> performAnalysis() async {
    final input = SourceRequest()..source = fullDartSource;

    final lines = Lines(input.source);

    final request = dartServices.analyze(input).timeout(serviceCallTimeout);
    analysisRequest = request;

    try {
      final result = await request;
      // Discard if we requested another analysis.
      if (analysisRequest != request) return false;

      // Discard if the document has been mutated since we requested analysis.
      if (input.source != fullDartSource) return false;

      busyLight.reset();

      displayIssues(result.issues);

      currentDocument.setAnnotations(result.issues.map((AnalysisIssue issue) {
        final startLine = lines.getLineForOffset(issue.charStart);
        final endLine =
            lines.getLineForOffset(issue.charStart + issue.charLength);
        final offsetForStartLine = lines.offsetForLine(startLine);

        final start = Position(startLine, issue.charStart - offsetForStartLine);
        final end = Position(
            endLine, issue.charStart + issue.charLength - offsetForStartLine);

        return Annotation(issue.kind, issue.message, issue.line,
            start: start, end: end);
      }).toList());

      final hasErrors = result.issues.any((issue) => issue.kind == 'error');
      final hasWarnings = result.issues.any((issue) => issue.kind == 'warning');
      return !hasErrors && !hasWarnings;
    } catch (e) {
      if (e is! TimeoutException) {
        final message = e is ApiRequestError ? e.message : '$e';

        displayIssues([
          AnalysisIssue()
            ..kind = 'error'
            ..line =
                -1 // set invalid line number, so NO line # will be displayed
            ..message = message
        ]);
      } else {
        logger.severe(e);
      }

      currentDocument.setAnnotations([]);
      busyLight.reset();
      return false;
    }
  }

  Future<bool> handleRun() async {
    ga.sendEvent('main', 'run');
    runButton.disabled = true;

    final compilationTimer = Stopwatch()..start();
    final compileRequest = CompileRequest()..source = fullDartSource;

    try {
      if (shouldCompileDDC) {
        final response = await dartServices
            .compileDDC(compileRequest)
            .timeout(longServiceCallTimeout);

        _sendCompilationTiming(compilationTimer.elapsedMilliseconds);
        clearOutput();

        await executionService.execute(
          context.htmlSource,
          context.cssSource,
          response.result,
          modulesBaseUrl: response.modulesBaseUrl,
          addRequireJs: true,
          addFirebaseJs: shouldAddFirebaseJs,
          // TODO(srawlins): Determine if we need to destroy the frame when
          // changing channels.
          // TODO(ryjohn) Determine how to preserve the iframe
          // https://github.com/dart-lang/dart-pad/issues/2269
          destroyFrame: true,
        );
      } else {
        final response = await dartServices
            .compile(compileRequest)
            .timeout(longServiceCallTimeout);

        _sendCompilationTiming(compilationTimer.elapsedMilliseconds);
        clearOutput();

        await executionService.execute(
          context.htmlSource,
          context.cssSource,
          response.result,
          // TODO(ryjohn) Determine how to preserve the iframe
          // https://github.com/dart-lang/dart-pad/issues/2269
          destroyFrame: true,
        );
      }
      return true;
    } catch (e) {
      ga.sendException('${e.runtimeType}');
      final message = e is ApiRequestError ? e.message : '$e';
      showSnackbar('Error compiling to JavaScript');
      clearOutput();
      showOutput('Error compiling to JavaScript:\n$message', error: true);
      return false;
    } finally {
      runButton.disabled = false;
    }
  }

  /// Updates the Flutter and Dart SDK versions in the bottom right.
  Future<void> updateVersions() async {
    try {
      final response = await dartServices.version();
      // "Based on Flutter 1.19.0-4.1.pre Dart SDK 2.8.4"
      final versionText = 'Based on Flutter ${response.flutterVersion}'
          ' Dart SDK ${response.sdkVersionFull}';
      querySelector('#dartpad-version')!.text = versionText;
      if (response.packageVersions.isNotEmpty) {
        _packageInfo.clear();
        _packageInfo.addAll(response.packageInfo);
      }
    } catch (_) {
      // Don't crash the app.
    }
  }

  /// A list of each package's information.
  ///
  /// This list is set on page load, and each time the Null Safety switch is
  /// toggled.
  final List<PackageInfo> _packageInfo = [];

  void _sendCompilationTiming(int milliseconds) {
    ga.sendTiming(
      'action-perf',
      'compilation-e2e',
      milliseconds,
    );
  }

  /// Resize Codemirror when the size of the panel changes. This keeps the
  /// virtual scrollbar in sync with the size of the panel.
  void listenForResize(Element element) {
    ResizeObserver((entries, observer) {
      editor.resize();
    }).observe(element);
  }
}

class Channel {
  final String name;
  final String dartVersion;
  final String flutterVersion;
  final bool hidden;

  static Future<Channel> fromVersion(String name, {bool hidden = false}) async {
    var rootUrl = urlMapping[name];
    // If the user provided bad URL query parameter (`?channel=nonsense`),
    // default to the stable channel.
    rootUrl ??= stableServerUrl;

    final dartservicesApi = DartservicesApi(browserClient, rootUrl: rootUrl);
    final versionResponse = await dartservicesApi.version();
    return Channel._(
      name: name,
      dartVersion: versionResponse.sdkVersionFull,
      flutterVersion: versionResponse.flutterVersion,
      hidden: hidden,
    );
  }

  static const urlMapping = {
    'stable': stableServerUrl,
    'beta': betaServerUrl,
    'old': oldServerUrl,
    'dev': devServerUrl,
  };

  Channel._({
    required this.name,
    required this.dartVersion,
    required this.flutterVersion,
    required this.hidden,
  });
}

class KeyboardDialog {
  final MDCDialog _mdcDialog;
  final MDCButton _okButton;
  final MDCSwitch _vimSwitch;

  KeyboardDialog()
      : assert(querySelector('#keyboard-dialog') != null),
        assert(querySelector('#keyboard-ok-button') != null),
        assert(querySelector('#vim-switch-container') != null),
        assert(querySelector('#vim-switch-container .mdc-switch') != null),
        _mdcDialog = MDCDialog(querySelector('#keyboard-dialog')!),
        _okButton =
            MDCButton(querySelector('#keyboard-ok-button') as ButtonElement),
        _vimSwitch =
            MDCSwitch(querySelector('#vim-switch-container .mdc-switch'));

  String get selectedKeyboardLayout {
    return _vimSwitch.checked! ? 'vim' : 'default';
  }

  Future<DialogResult> show(Editor editor) {
    // populate with the keymap info
    final DElement keyMapInfoDiv =
        DElement(querySelector('#keyboard-map-info')!);
    final Element info = Element.html(keyMapToHtml(keys.inverseBindings));
    keyMapInfoDiv.clearChildren();
    keyMapInfoDiv.add(info);

    // set switch according to keyboard state
    final String currentKeyMap = editor.keyMap;
    _vimSwitch.checked = (currentKeyMap == 'vim');

    final completer = Completer<DialogResult>();

    _okButton.onClick.listen((_) {
      final bool vimSet = _vimSwitch.checked!;

      // change keyMap if needed and *remember* their choice for next startup
      if (vimSet) {
        if (currentKeyMap != 'vim') editor.keyMap = 'vim';
        window.localStorage['codemirror_keymap'] = 'vim';
      } else {
        if (currentKeyMap != 'default') editor.keyMap = 'default';
        window.localStorage['codemirror_keymap'] = 'default';
      }
      completer.complete(vimSet ? DialogResult.yes : DialogResult.ok);
    });

    _mdcDialog.open();

    return completer.future.then((v) {
      _mdcDialog.close();
      return v;
    });
  }
}

import 'dart:async';
import 'dart:html';

import 'package:dart_pad/elements/button.dart';
import 'package:dart_pad/elements/dialog.dart';
import 'package:dart_pad/services/execution.dart';
import 'package:dart_pad/util/keymap.dart';
import 'package:logging/logging.dart';
import 'package:mdc_web/mdc_web.dart';
import 'package:meta/meta.dart';

import '../context.dart';
import '../dart_pad.dart';
import '../editing/editor.dart';
import '../elements/analysis_results_controller.dart';
import '../elements/elements.dart';
import '../services/common.dart';
import '../services/dartservices.dart';

abstract class EditorUi {
  final Logger logger = Logger('dartpad');

  ContextBase get context;

  Future<AnalysisResults>? analysisRequest;
  late final DBusyLight busyLight;
  late final AnalysisResultsController analysisResultsController;
  late final Editor editor;
  late final MDCButton runButton;
  late final ExecutionService executionService;

  /// The dialog box for information like Keyboard shortcuts.
  final Dialog dialog = Dialog();

  /// The source-of-truth for whether null safety is enabled.
  ///
  /// On page load, this may be originally derived from local storage.
  late bool nullSafetyEnabled;

  /// Whether null safety was enabled for the previous execution.
  bool nullSafetyWasPreviouslyEnabled = false;

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

  void showKeyboardDialog() {
    dialog.showOk('Keyboard shortcuts', keyMapToHtml(keys.inverseBindings));
  }

  /// Show the Pub package versions which are currently in play in [dialog].
  ///
  /// Each package name links to its page at pub.dev; each package version
  /// links to the version page at pub.dev; Each link opens in a new tab.
  void showPackageVersionsDialog() {
    var directlyImportableList = StringBuffer('<dl>');
    var indirectList = StringBuffer('<dl>');
    for (var package in _packageInfo) {
      var packageUrl = 'https://pub.dev/packages/${package.name}';
      var packageLink = AnchorElement()
        ..href = packageUrl
        ..setAttribute('target', '_blank')
        ..text = package.name;
      var dt = '<dt>${packageLink.outerHtml}</dt>';
      var packageVersion = package.version;
      var versionLink = SpanElement()
        ..children.add(AnchorElement()
          ..href = '$packageUrl/versions/$packageVersion'
          ..setAttribute('target', '_blank')
          ..text = packageVersion);
      var dd = '<dd>${versionLink.outerHtml}</dd>';
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
    var directDl = Element.html(directlyImportableList.toString(),
        treeSanitizer: NodeTreeSanitizer.trusted);
    var indirectDl = Element.html(indirectList.toString(),
        treeSanitizer: NodeTreeSanitizer.trusted);

    var div = DivElement()
      ..children.add(DivElement()
        ..children
            .add(ParagraphElement()..text = 'Directly importable packages')
        ..children.add(directDl)
        ..children
            .add(ParagraphElement()..text = 'Packages available transitively')
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
    var input = SourceRequest()..source = fullDartSource;

    var lines = Lines(input.source);

    var request = dartServices.analyze(input).timeout(serviceCallTimeout);
    analysisRequest = request;

    try {
      var result = await request;
      // Discard if we requested another analysis.
      if (analysisRequest != request) return false;

      // Discard if the document has been mutated since we requested analysis.
      if (input.source != fullDartSource) return false;

      busyLight.reset();

      displayIssues(result.issues);

      currentDocument.setAnnotations(result.issues.map((AnalysisIssue issue) {
        var startLine = lines.getLineForOffset(issue.charStart);
        var endLine =
            lines.getLineForOffset(issue.charStart + issue.charLength);
        var offsetForStartLine = lines.offsetForLine(startLine);

        var start = Position(startLine, issue.charStart - offsetForStartLine);
        var end = Position(
            endLine, issue.charStart + issue.charLength - offsetForStartLine);

        return Annotation(issue.kind, issue.message, issue.line,
            start: start, end: end);
      }).toList());

      var hasErrors = result.issues.any((issue) => issue.kind == 'error');
      var hasWarnings = result.issues.any((issue) => issue.kind == 'warning');
      return !hasErrors && !hasWarnings;
    } catch (e) {
      if (e is! TimeoutException) {
        final message = e is ApiRequestError ? e.message : '$e';

        displayIssues([
          AnalysisIssue()
            ..kind = 'error'
            ..line = 1
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
    // If the null safety toggle has changed from the last execution to this
    // one, destroy the frame.
    final shouldDestroyFrame =
        nullSafetyWasPreviouslyEnabled == !nullSafetyEnabled;

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
          destroyFrame: shouldDestroyFrame,
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
          destroyFrame: shouldDestroyFrame,
        );
      }
      // Only after successful execution can we safely set the "previous" null
      // safety state. If compilation or execution threw, we leave the previous
      // null safety state so that we know to still destroy the frame on the
      // next attempt.
      nullSafetyWasPreviouslyEnabled = nullSafetyEnabled;
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
  void updateVersions() async {
    try {
      var response = await dartServices.version();
      // "Based on Flutter 1.19.0-4.1.pre Dart SDK 2.8.4"
      var versionText = 'Based on Flutter ${response.flutterVersion}'
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

  static Future<Channel> fromVersion(String name) async {
    var rootUrl = urlMapping[name];
    // If the user provided bad URL query parameter (`?channel=nonsense`),
    // default to the stable channel.
    rootUrl ??= stableServerUrl;

    var dartservicesApi = DartservicesApi(browserClient, rootUrl: rootUrl);
    var versionResponse = await dartservicesApi.version();
    return Channel._(
      name: name,
      dartVersion: versionResponse.sdkVersionFull,
      flutterVersion: versionResponse.flutterVersion,
    );
  }

  static const urlMapping = {
    'stable': stableServerUrl,
    'beta': betaServerUrl,
    'dev': devServerUrl,
    'old': oldServerUrl,
  };

  Channel._({
    required this.name,
    required this.dartVersion,
    required this.flutterVersion,
  });
}

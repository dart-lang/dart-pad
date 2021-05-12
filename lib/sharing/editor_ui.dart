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

  Future<AnalysisResults> analysisRequest;
  DBusyLight busyLight;
  AnalysisResultsController analysisResultsController;
  Editor editor;
  MDCButton runButton;
  ExecutionService executionService;

  /// The dialog box for information like Keyboard shortcuts.
  final Dialog dialog = Dialog();

  /// The source-of-truth for whether null safety is enabled.
  ///
  /// On page load, this may be originally derived from local storage.
  bool nullSafetyEnabled;

  /// Whether null safety was enabled for the previous execution.
  bool nullSafetyWasPreviouslyEnabled;

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

  void showSnackbar(String message) {
    var div = querySelector('.mdc-snackbar');
    var snackbar = MDCSnackbar(div)..labelText = message;
    snackbar.open();
  }

  Document get currentDocument => editor.document;

  /// Perform static analysis of the source code. Return whether the code
  /// analyzed cleanly (had no errors or warnings).
  Future<bool> performAnalysis() {
    var input = SourceRequest()..source = fullDartSource;

    var lines = Lines(input.source);

    var request = dartServices.analyze(input).timeout(serviceCallTimeout);
    analysisRequest = request;

    return request.then((AnalysisResults result) {
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

        var start = Position(
            startLine, issue.charStart - lines.offsetForLine(startLine));
        var end = Position(
            endLine,
            issue.charStart +
                issue.charLength -
                lines.offsetForLine(startLine));

        return Annotation(issue.kind, issue.message, issue.line,
            start: start, end: end);
      }).toList());

      var hasErrors = result.issues.any((issue) => issue.kind == 'error');
      var hasWarnings = result.issues.any((issue) => issue.kind == 'warning');

      return hasErrors == false && hasWarnings == false;
    }).catchError((e) {
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
    });
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

  void _sendCompilationTiming(int milliseconds) {
    ga.sendTiming(
      'action-perf',
      'compilation-e2e',
      milliseconds,
    );
  }
}

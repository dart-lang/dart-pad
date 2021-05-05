import 'dart:async';
import 'dart:html';

import 'package:dart_pad/elements/button.dart';
import 'package:logging/logging.dart';
import 'package:mdc_web/mdc_web.dart';

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

  bool get shouldCompileDDC;

  bool get shouldAddFirebaseJs;

  void clearOutput();

  void showOutput(String message, {bool error = false});

  void displayIssues(List<AnalysisIssue> issues) {
    analysisResultsController.display(issues);
  }

  void showSnackbar(String message) {
    var div = querySelector('.mdc-snackbar');
    var snackbar = MDCSnackbar(div)..labelText = message;
    snackbar.open();
  }

  /// Perform static analysis of the source code. Return whether the code
  /// analyzed cleanly (had no errors or warnings).
  Future<bool> performAnalysis() {
    var input = SourceRequest()..source = context.dartSource;

    var lines = Lines(input.source);

    var request = dartServices.analyze(input).timeout(serviceCallTimeout);
    analysisRequest = request;

    return request.then((AnalysisResults result) {
      // Discard if we requested another analysis.
      if (analysisRequest != request) return false;

      // Discard if the document has been mutated since we requested analysis.
      if (input.source != context.dartSource) return false;

      busyLight.reset();

      displayIssues(result.issues);

      editor.document.setAnnotations(result.issues.map((AnalysisIssue issue) {
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

      editor.document.setAnnotations([]);
      busyLight.reset();
    });
  }

  Future<bool> handleRun() async {
    ga.sendEvent('main', 'run');
    runButton.disabled = true;

    var compilationTimer = Stopwatch()..start();

    final compileRequest = CompileRequest()..source = context.dartSource;

    try {
      if (shouldCompileDDC) {
        final response = await dartServices
            .compileDDC(compileRequest)
            .timeout(longServiceCallTimeout);

        ga.sendTiming(
          'action-perf',
          'compilation-e2e',
          compilationTimer.elapsedMilliseconds,
        );

        clearOutput();

        await executionService.execute(
          context.htmlSource,
          context.cssSource,
          response.result,
          modulesBaseUrl: response.modulesBaseUrl,
          addRequireJs: true,
          addFirebaseJs: shouldAddFirebaseJs,
        );
      } else {
        final response = await dartServices
            .compile(compileRequest)
            .timeout(longServiceCallTimeout);

        ga.sendTiming(
          'action-perf',
          'compilation-e2e',
          compilationTimer.elapsedMilliseconds,
        );

        clearOutput();

        await executionService.execute(
          context.htmlSource,
          context.cssSource,
          response.result,
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
}

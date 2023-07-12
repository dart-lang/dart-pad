// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'gists.dart';
import 'samples.g.dart';
import 'services/dartservices.dart';
import 'utils.dart';

// TODO: make sure that service calls have built-in timeouts (10s, 60s, ...)

abstract class ExecutionService {
  Future<void> execute(String javaScript);
  Stream<String> get onStdout;
  Future<void> tearDown();
}

abstract class EditorService {
  void showCompletions();

  void jumpTo(AnalysisIssue issue);
}

class AppModel {
  final ValueNotifier<bool> appReady = ValueNotifier(false);

  final ValueNotifier<List<AnalysisIssue>> analysisIssues = ValueNotifier([]);

  final ValueNotifier<String> title = ValueNotifier('');

  final TextEditingController sourceCodeController = TextEditingController();
  final TextEditingController consoleOutputController = TextEditingController();

  final ValueNotifier<bool> formattingBusy = ValueNotifier(false);
  final ValueNotifier<bool> compilingBusy = ValueNotifier(false);

  final StatusController editorStatus = StatusController();
  final StatusController executionStatus = StatusController();

  final ValueNotifier<VersionResponse> runtimeVersions =
      ValueNotifier(VersionResponse());

  final OutputAreaMode outputAreaMode = OutputAreaMode();

  AppModel() {
    consoleOutputController.addListener(() {
      outputAreaMode.hasStdout = consoleOutputController.text.isNotEmpty;
    });
  }

  void appendLineToConsole(String str) {
    consoleOutputController.text += '$str\n';
  }

  void clearConsole() => consoleOutputController.clear();

  set executableIsFlutter(bool value) {
    outputAreaMode.executableIsFlutter = value;
  }
}

class OutputAreaMode {
  final ValueNotifier<ModeValue> _showing =
      ValueNotifier(const ModeValue(appArea: false, console: true));

  ValueListenable<ModeValue> get showing => _showing;

  bool? _executableIsFlutter;
  bool? outputHasContent;

  set executableIsFlutter(bool value) {
    _executableIsFlutter = value;
    _updateExecutionAreasVisibility();
  }

  set hasStdout(bool value) {
    outputHasContent = value;
    _updateExecutionAreasVisibility();
  }

  void _updateExecutionAreasVisibility() {
    final appShowing = _executableIsFlutter ?? false;
    final consoleShowing = !appShowing | (outputHasContent ?? true);

    _showing.value = ModeValue(appArea: appShowing, console: consoleShowing);
  }
}

class ModeValue {
  final bool appArea;
  final bool console;

  const ModeValue({required this.appArea, required this.console});

  @override
  bool operator ==(Object other) {
    return other is ModeValue &&
        appArea == other.appArea &&
        console == other.console;
  }

  bool get bothVisible => appArea && console;

  @override
  int get hashCode => Object.hash(appArea, console);

  @override
  String toString() => 'appArea: $appArea, console: $console';
}

class AppServices {
  final AppModel appModel;
  final DartservicesApi services;

  ExecutionService? _executionService;
  EditorService? _editorService;

  StreamSubscription<String>? stdoutSub;

  // TODO: Consider using DebounceStreamTransformer from package:rxdart?
  Timer? reanalysisDebouncer;

  AppServices(this.appModel, this.services) {
    appModel.sourceCodeController.addListener(_handleCodeChanged);
    appModel.analysisIssues.addListener(_updateEditorProblemsStatus);
  }

  EditorService? get editorService => _editorService;

  void resetTo({String? type}) {
    type ??= 'dart';
    final source = Samples.getDefault(type: type);

    // reset the source
    appModel.sourceCodeController.text = source;

    // reset the title
    appModel.title.value = generateSnippetName();

    // reset the console
    appModel.clearConsole();

    // TODO: reset the execution area

    appModel.editorStatus.showToast('Created new ${titleCase(type)} snippet');
  }

  void _handleCodeChanged() {
    reanalysisDebouncer?.cancel();
    reanalysisDebouncer = Timer(const Duration(milliseconds: 1000), () {
      _reAnalyze();
      reanalysisDebouncer = null;
    });
  }

  void dispose() {
    appModel.sourceCodeController.removeListener(_handleCodeChanged);
  }

  Future<void> populateVersions() async {
    final version = await services.version();
    appModel.runtimeVersions.value = version;
  }

  Future<void> performInitialLoad({
    String? sampleId,
    String? gistId,
    required String fallbackSnippet,
  }) async {
    // Delay a bit for codemirror to initialize.
    await Future<void>.delayed(const Duration(milliseconds: 1));

    var sample = Samples.getById(sampleId);
    if (sample != null) {
      appModel.title.value = sample.name;
      appModel.sourceCodeController.text = sample.source;
      appModel.appReady.value = true;
      return;
    }

    if (gistId == null) {
      appModel.sourceCodeController.text = fallbackSnippet;
      appModel.appReady.value = true;
      return;
    }

    final gistLoader = GistLoader();
    final progress = appModel.editorStatus.showMessage(initialText: 'Loading…');
    try {
      final gist = await gistLoader.load(gistId);
      progress.close();

      var title = gist.description ?? '';
      appModel.title.value =
          title.length > 40 ? '${title.substring(0, 40)}…' : title;

      final source = gist.mainDartSource;
      if (source == null) {
        appModel.editorStatus.showToast('main.dart not found');
        appModel.sourceCodeController.text = fallbackSnippet;
      } else {
        appModel.sourceCodeController.text = source;
      }

      appModel.appReady.value = true;
    } catch (e) {
      appModel.editorStatus.showToast('Error loading gist');
      progress.close();

      appModel.appendLineToConsole('Error loading gist: $e');

      appModel.sourceCodeController.text = fallbackSnippet;
      appModel.appReady.value = true;
    } finally {
      gistLoader.dispose();
    }
  }

  Future<FormatResponse> format(SourceRequest request) async {
    try {
      appModel.formattingBusy.value = true;
      return await services.format(request);
    } finally {
      appModel.formattingBusy.value = false;
    }
  }

  Future<CompileResponse> compile(CompileRequest request) async {
    try {
      appModel.compilingBusy.value = true;
      return await services.compile(request);
    } finally {
      appModel.compilingBusy.value = false;
    }
  }

  void registerExecutionService(ExecutionService? executionService) {
    // unregister the old
    stdoutSub?.cancel();

    // replace the service
    _executionService = executionService;

    // register the new
    if (_executionService != null) {
      stdoutSub = _executionService!.onStdout.listen((event) {
        appModel.appendLineToConsole(event);
      });
    }
  }

  void registerEditorService(EditorService? editorService) {
    _editorService = editorService;
  }

  void executeJavaScript(String javaScript) {
    appModel.executableIsFlutter = hasFlutterWebMarker(javaScript);

    _executionService?.execute(javaScript);
  }

  Future<void> _reAnalyze() async {
    try {
      final results = await services
          .analyze(SourceRequest(source: appModel.sourceCodeController.text));
      final issues = results.issues.toList()..sort(_compareIssues);
      appModel.analysisIssues.value = issues;
    } catch (error) {
      var message = error is ApiRequestError ? error.message : '$error';
      appModel.analysisIssues.value = [
        AnalysisIssue(kind: 'error', message: message),
      ];
    }
  }

  void _updateEditorProblemsStatus() {
    final issues = appModel.analysisIssues.value;
    final progress = appModel.editorStatus.getNamedMessage('problems');

    if (issues.isEmpty) {
      progress?.close();
    } else {
      final message = '${issues.length} ${pluralize('issue', issues.length)}';
      if (progress == null) {
        appModel.editorStatus
            .showMessage(initialText: message, name: 'problems');
      } else {
        progress.updateText(message);
      }
    }
  }
}

int _compareIssues(AnalysisIssue a, AnalysisIssue b) {
  var diff = a.severity - b.severity;
  if (diff != 0) return -diff;

  return a.charStart - b.charStart;
}

extension AnalysisIssueExtension on AnalysisIssue {
  int get severity => switch (kind) {
        'error' => 3,
        'warning' => 2,
        'info' => 1,
        _ => 0,
      };
}

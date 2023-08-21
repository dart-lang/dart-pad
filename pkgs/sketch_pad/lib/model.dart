// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'gists.dart';
import 'samples.g.dart';
import 'src/dart_services.dart';
import 'utils.dart';

// TODO: make sure that calls have built-in timeouts (10s, 60s, ...)

abstract class ExecutionService {
  Future<void> execute(String javaScript);
  Stream<String> get onStdout;
  Future<void> reset();
  Future<void> tearDown();
}

abstract class EditorService {
  void showCompletions();
  void jumpTo(AnalysisIssue issue);
}

class AppModel {
  bool? _appIsFlutter;

  final ValueNotifier<bool> appReady = ValueNotifier(false);

  final ValueNotifier<List<AnalysisIssue>> analysisIssues = ValueNotifier([]);

  final ValueNotifier<String> title = ValueNotifier('');

  final TextEditingController sourceCodeController = TextEditingController();
  final TextEditingController consoleOutputController = TextEditingController();

  final ValueNotifier<bool> formattingBusy = ValueNotifier(false);
  final ValueNotifier<bool> compilingBusy = ValueNotifier(false);

  final StatusController editorStatus = StatusController();

  final ValueNotifier<VersionResponse> runtimeVersions =
      ValueNotifier(VersionResponse());

  final ValueNotifier<LayoutMode> _layoutMode = ValueNotifier(LayoutMode.both);
  ValueListenable<LayoutMode> get layoutMode => _layoutMode;

  AppModel() {
    consoleOutputController.addListener(_recalcLayout);
  }

  void appendLineToConsole(String str) {
    consoleOutputController.text += '$str\n';
  }

  void clearConsole() => consoleOutputController.clear();

  void dispose() {
    consoleOutputController.removeListener(_recalcLayout);
  }

  void _recalcLayout() {
    final hasConsoleText = consoleOutputController.text.isNotEmpty;
    final isFlutter = _appIsFlutter;

    if (isFlutter == null) {
      _layoutMode.value = LayoutMode.both;
    } else if (!isFlutter) {
      _layoutMode.value = LayoutMode.justConsole;
    } else {
      _layoutMode.value = hasConsoleText ? LayoutMode.both : LayoutMode.justDom;
    }
  }
}

enum LayoutMode {
  both(true, true),
  justDom(true, false),
  justConsole(false, true);

  static const double _dividerSplit = 0.78;

  final bool domIsVisible;
  final bool consoleIsVisible;

  const LayoutMode(this.domIsVisible, this.consoleIsVisible);

  double calcDomHeight(double height) {
    if (!domIsVisible) return 1;
    if (!consoleIsVisible) return height;

    return height * _dividerSplit;
  }

  double calcConsoleHeight(double height) {
    if (!consoleIsVisible) return 0;
    if (!domIsVisible) return height - 1;

    return height * (1 - _dividerSplit);
  }
}

class AppServices {
  final AppModel appModel;
  final Channel channel;

  late final http.Client httpClient;
  late final DartservicesApi services;

  ExecutionService? _executionService;
  EditorService? _editorService;

  StreamSubscription<String>? stdoutSub;

  // TODO: Consider using DebounceStreamTransformer from package:rxdart.
  Timer? reanalysisDebouncer;

  AppServices(this.appModel, this.channel) {
    httpClient = http.Client();
    services = DartservicesApi(httpClient, rootUrl: channel.url);

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
    httpClient.close();

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

  @Deprecated('prefer to use `build`')
  Future<CompileResponse> compile(CompileRequest request) async {
    try {
      appModel.compilingBusy.value = true;
      return await services.compile(request);
    } finally {
      appModel.compilingBusy.value = false;
    }
  }

  Future<FlutterBuildResponse> build(FlutterBuildRequest request) async {
    try {
      appModel.compilingBusy.value = true;
      return await services.flutterBuild(request);
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
    final usesFlutter = hasFlutterWebMarker(javaScript);
    appModel._appIsFlutter = usesFlutter;
    appModel._recalcLayout();

    _executionService?.execute(javaScript);
  }

  Future<void> _reAnalyze() async {
    try {
      final results = await services.analyze(
        SourceRequest(source: appModel.sourceCodeController.text),
      );
      final issues = results.issues.toList()..sort(_compareIssues);
      appModel.analysisIssues.value = issues;
    } catch (error) {
      var message = error is ApiRequestError ? error.message : '$error';
      appModel.analysisIssues.value = [
        AnalysisIssue()
          ..kind = 'error'
          ..message = message,
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

enum Channel {
  stable('Stable', 'https://stable.api.dartpad.dev/'),
  beta('Beta', 'https://beta.api.dartpad.dev/'),
  // This channel is only used for local development.
  localhost('Localhost', 'http://localhost:8082/');

  final String displayName;
  final String url;

  const Channel(this.displayName, this.url);

  static const defaultChannel = Channel.stable;

  static List<Channel> get valuesWithoutLocalhost {
    return values.whereNot((channel) => channel == localhost).toList();
  }

  static Channel? channelForName(String name) {
    name = name.trim().toLowerCase();

    return Channel.values.firstWhereOrNull((c) => c.name == name);
  }
}

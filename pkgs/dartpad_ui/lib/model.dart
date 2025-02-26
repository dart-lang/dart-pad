// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dartpad_shared/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

import 'flutter_samples.dart';
import 'gists.dart';
import 'samples.g.dart';
import 'utils.dart';

// TODO: make sure that calls have built-in timeouts (10s, 60s, ...)

abstract class ExecutionService {
  Future<void> execute(
    String javaScript, {
    String? modulesBaseUrl,
    String? engineVersion,
    required bool isNewDDC,
    required bool reload,
    required bool isFlutter,
  });
  Stream<String> get onStdout;
  Future<void> reset();
  Future<void> tearDown();
  set ignorePointer(bool ignorePointer);
}

abstract class EditorService {
  void showCompletions({required bool autoInvoked});
  void showQuickFixes();
  void jumpTo(AnalysisIssue issue);
  int get cursorOffset;
  void focus();
}

class AppModel {
  final ValueNotifier<bool?> _appIsFlutter = ValueNotifier(null);
  bool? _usesPackageWeb;
  AppType get appType =>
      _appIsFlutter.value ?? false ? AppType.flutter : AppType.dart;

  final ValueNotifier<bool> appReady = ValueNotifier(false);

  final ValueNotifier<List<AnalysisIssue>> analysisIssues = ValueNotifier([]);

  final ValueNotifier<String> title = ValueNotifier('');

  final TextEditingController sourceCodeController = TextEditingController();
  final ValueNotifier<String> consoleOutput = ValueNotifier('');

  final ValueNotifier<bool> formattingBusy = ValueNotifier(false);
  final ValueNotifier<bool> compilingBusy = ValueNotifier(false);
  final ValueNotifier<bool> docHelpBusy = ValueNotifier(false);

  final ValueNotifier<bool> hasRun = ValueNotifier(false);
  final ValueNotifier<bool> canReload = ValueNotifier(false);

  final StatusController editorStatus = StatusController();

  final ValueNotifier<VersionResponse?> runtimeVersions = ValueNotifier(null);

  final ValueNotifier<LayoutMode> _layoutMode = ValueNotifier(LayoutMode.both);
  ValueListenable<LayoutMode> get layoutMode => _layoutMode;

  final ValueNotifier<SplitDragState> splitViewDragState =
      ValueNotifier(SplitDragState.inactive);

  final SplitDragStateManager splitDragStateManager = SplitDragStateManager();
  late final StreamSubscription<SplitDragState> _splitSubscription;

  final ValueNotifier<bool> vimKeymapsEnabled = ValueNotifier(false);

  bool _consoleShowingError = false;
  bool get consoleShowingError => _consoleShowingError;
  final ValueNotifier<bool> showReload = ValueNotifier(false);
  final ValueNotifier<bool> _useNewDDC = ValueNotifier(false);
  final ValueNotifier<String?> currentDeltaDill = ValueNotifier(null);

  AppModel() {
    consoleOutput.addListener(_recalcLayout);
    void updateCanReload() => canReload.value =
        hasRun.value && !compilingBusy.value && currentDeltaDill.value != null;
    hasRun.addListener(updateCanReload);
    compilingBusy.addListener(updateCanReload);
    currentDeltaDill.addListener(updateCanReload);

    void updateShowReload() {
      showReload.value = _useNewDDC.value && (_appIsFlutter.value ?? false);
    }

    _useNewDDC.addListener(updateShowReload);
    _appIsFlutter.addListener(updateShowReload);

    _splitSubscription =
        splitDragStateManager.onSplitDragUpdated.listen((SplitDragState value) {
      splitViewDragState.value = value;
    });
  }

  static final _errorRe = RegExp(
    r'\b(unhandled|exception)\b',
    caseSensitive: false,
  );

  void appendLineToConsole(String str) {
    consoleOutput.value += '$str\n';

    // NOTE(csells): workaround for https://github.com/dart-lang/dart-pad/issues/3148;
    // this heuristic is not foolproof, but seems to work well for both Dart and
    // Flutter unhandled exceptions based on limited testing.
    if (_errorRe.hasMatch(str)) _consoleShowingError = true;
  }

  void clearConsole() {
    consoleOutput.value = '';
    _consoleShowingError = false;
  }

  void dispose() {
    consoleOutput.removeListener(_recalcLayout);
    _splitSubscription.cancel();
  }

  void _recalcLayout() {
    final hasConsoleText = consoleOutput.value.isNotEmpty;
    final isFlutter = _appIsFlutter.value;
    final usesPackageWeb = _usesPackageWeb;

    if (isFlutter == null || usesPackageWeb == null) {
      _layoutMode.value = LayoutMode.both;
    } else if (usesPackageWeb) {
      _layoutMode.value = LayoutMode.both;
    } else if (!isFlutter) {
      _layoutMode.value = LayoutMode.justConsole;
    } else {
      _layoutMode.value = hasConsoleText ? LayoutMode.both : LayoutMode.justDom;
    }
  }
}

const double dividerSplit = 0.78;

enum LayoutMode {
  both(true, true),
  justDom(true, false),
  justConsole(false, true);

  final bool domIsVisible;
  final bool consoleIsVisible;

  const LayoutMode(this.domIsVisible, this.consoleIsVisible);

  double calcDomHeight(double height) {
    if (!domIsVisible) return 1;
    if (!consoleIsVisible) return height;

    return height * dividerSplit;
  }

  double calcConsoleHeight(double height) {
    if (!consoleIsVisible) return 0;
    if (!domIsVisible) return height - 1;

    return height * (1 - dividerSplit);
  }
}

class AppServices {
  final AppModel appModel;
  final ValueNotifier<Channel> _channel = ValueNotifier(Channel.defaultChannel);

  final Client _httpClient = Client();
  late ServicesClient services;

  ExecutionService? _executionService;
  EditorService? _editorService;

  StreamSubscription<String>? stdoutSub;

  // TODO: Consider using DebounceStreamTransformer from package:rxdart.
  Timer? reanalysisDebouncer;

  static const Set<Channel> _hotReloadableChannels = {
    Channel.localhost,
    Channel.main,
  };

  AppServices(this.appModel, Channel channel) {
    _channel.value = channel;
    services = ServicesClient(_httpClient, rootUrl: channel.url);

    appModel.sourceCodeController.addListener(_handleCodeChanged);
    appModel.analysisIssues.addListener(_updateEditorProblemsStatus);

    void updateUseNewDDC() {
      appModel._useNewDDC.value =
          _hotReloadableChannels.contains(_channel.value);
    }

    updateUseNewDDC();
    _channel.addListener(updateUseNewDDC);
  }

  EditorService? get editorService => _editorService;
  ExecutionService? get executionService => _executionService;

  ValueListenable<Channel> get channel => _channel;

  Future<VersionResponse> setChannel(Channel channel) async {
    services = ServicesClient(_httpClient, rootUrl: channel.url);
    final versionResponse = await populateVersions();
    _channel.value = channel;
    return versionResponse;
  }

  void resetTo({String? type}) {
    type ??= 'dart';
    final source =
        Samples.defaultSnippet(forFlutter: type.toLowerCase() == 'flutter');

    // Reset the source.
    appModel.sourceCodeController.text = source;

    // Reset the title.
    appModel.title.value = '';

    // Reset the console.
    appModel.clearConsole();

    // Reset the execution area.
    executionService?.reset();

    appModel.editorStatus.showToast('Created new ${titleCase(type)} snippet');
  }

  void _handleCodeChanged() {
    reanalysisDebouncer?.cancel();
    reanalysisDebouncer = Timer(const Duration(milliseconds: 1000), () {
      _reAnalyze();
      reanalysisDebouncer = null;
    });
  }

  Future<VersionResponse> populateVersions() async {
    final version = await services.version();
    appModel.runtimeVersions.value = version;
    return version;
  }

  Future<void> performInitialLoad({
    String? gistId,
    String? sampleId,
    String? flutterSampleId,
    String? channel,
    String? keybinding,
    required String Function() getFallback,
  }) async {
    // Delay a bit for codemirror to initialize.
    await Future<void>.delayed(const Duration(milliseconds: 1));

    final sample = Samples.getById(sampleId);
    if (sample != null) {
      appModel.title.value = sample.name;
      appModel.sourceCodeController.text = sample.source;
      appModel.appReady.value = true;
      return;
    }

    if (flutterSampleId != null) {
      final loader = FlutterSampleLoader();
      final progress =
          appModel.editorStatus.showMessage(initialText: 'Loading…');
      try {
        final sample = await loader.loadFlutterSample(
          sampleId: flutterSampleId,
          channel: channel,
        );
        progress.close();

        appModel.title.value = flutterSampleId;
        appModel.sourceCodeController.text = sample;

        appModel.appReady.value = true;
      } catch (e) {
        appModel.editorStatus.showToast('Error loading sample');
        progress.close();

        appModel.appendLineToConsole('Error loading sample: $e');

        appModel.sourceCodeController.text = getFallback();
        appModel.appReady.value = true;
      } finally {
        loader.dispose();
      }

      return;
    }

    if (gistId != null) {
      final gistLoader = GistLoader();
      final progress =
          appModel.editorStatus.showMessage(initialText: 'Loading…');
      try {
        final gist = await gistLoader.load(gistId);
        progress.close();

        final title = gist.description ?? '';
        appModel.title.value =
            title.length > 40 ? '${title.substring(0, 40)}…' : title;

        final source = gist.mainDartSource;
        if (source == null) {
          appModel.editorStatus.showToast('main.dart not found');
          appModel.sourceCodeController.text = getFallback();
        } else {
          appModel.sourceCodeController.text = source;

          if (gist.validationIssues.isNotEmpty) {
            final message = gist.validationIssues.join('\n');
            appModel.editorStatus.showToast(
              message,
              duration: const Duration(seconds: 10),
            );
          }
        }

        appModel.appReady.value = true;
      } catch (e) {
        appModel.editorStatus.showToast('Error loading gist');
        progress.close();

        appModel.appendLineToConsole('Error loading gist: $e');

        appModel.sourceCodeController.text = getFallback();
        appModel.appReady.value = true;
      } finally {
        gistLoader.dispose();
      }

      return;
    }

    if (keybinding != null && keybinding == 'vim') {
      appModel.vimKeymapsEnabled.value = true;
    }

    // Neither gistId nor flutterSampleId were passed in.
    appModel.sourceCodeController.text = getFallback();
    appModel.appReady.value = true;
  }

  Future<void> _performCompileAndAction({required bool reload}) async {
    final source = appModel.sourceCodeController.text;
    final progress =
        appModel.editorStatus.showMessage(initialText: 'Compiling…');

    try {
      CompileDDCResponse response;
      if (!appModel._useNewDDC.value) {
        response = await _compileDDC(CompileRequest(source: source));
      } else if (reload) {
        response = await _compileNewDDCReload(CompileRequest(
            source: source, deltaDill: appModel.currentDeltaDill.value!));
      } else {
        response = await _compileNewDDC(CompileRequest(source: source));
      }
      if (!reload || appModel._consoleShowingError) {
        appModel.clearConsole();
      }
      _executeJavaScript(
        response.result,
        modulesBaseUrl: response.modulesBaseUrl,
        engineVersion: appModel.runtimeVersions.value?.engineVersion,
        dartSource: source,
        isNewDDC: appModel._useNewDDC.value,
        reload: reload,
      );
      appModel.currentDeltaDill.value = response.deltaDill;
      appModel.hasRun.value = true;
    } catch (error) {
      appModel.clearConsole();

      appModel.editorStatus.showToast('Compilation failed');

      if (error is ApiRequestError) {
        appModel.appendLineToConsole(error.message);
        appModel.appendLineToConsole(error.body);
      } else {
        appModel.appendLineToConsole('$error');
      }
      appModel._consoleShowingError = true;
    } finally {
      progress.close();
    }
  }

  Future<void> performCompileAndReload() async {
    _performCompileAndAction(reload: true);
  }

  Future<void> performCompileAndRun() async {
    _performCompileAndAction(reload: false);
  }

  Future<void> performCompileAndReloadOrRun() async {
    if (appModel.showReload.value && appModel.canReload.value) {
      performCompileAndReload();
    } else {
      performCompileAndRun();
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

  Future<DocumentResponse> document(SourceRequest request) async {
    return await services.document(request);
  }

  Future<CompileResponse> compile(CompileRequest request) async {
    try {
      appModel.compilingBusy.value = true;
      return await services.compile(request);
    } finally {
      appModel.compilingBusy.value = false;
    }
  }

  Stream<String> suggestFix(SuggestFixRequest request) {
    return services.suggestFix(request);
  }

  Stream<String> generateCode(GenerateCodeRequest request) {
    return services.generateCode(request);
  }

  Stream<String> updateCode(UpdateCodeRequest request) {
    return services.updateCode(request);
  }

  Future<CompileDDCResponse> _compileDDC(CompileRequest request) async {
    try {
      appModel.compilingBusy.value = true;
      return await services.compileDDC(request);
    } finally {
      appModel.compilingBusy.value = false;
    }
  }

  Future<CompileDDCResponse> _compileNewDDC(CompileRequest request) async {
    try {
      appModel.compilingBusy.value = true;
      return await services.compileNewDDC(request);
    } finally {
      appModel.compilingBusy.value = false;
    }
  }

  Future<CompileDDCResponse> _compileNewDDCReload(
      CompileRequest request) async {
    try {
      appModel.compilingBusy.value = true;
      return await services.compileNewDDCReload(request);
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
      stdoutSub =
          _executionService!.onStdout.listen(appModel.appendLineToConsole);
    }
  }

  void registerEditorService(EditorService? editorService) {
    _editorService = editorService;
  }

  void _executeJavaScript(
    String javaScript, {
    required String dartSource,
    String? modulesBaseUrl,
    String? engineVersion,
    required bool isNewDDC,
    required bool reload,
  }) {
    final appIsFlutter = hasFlutterWebMarker(javaScript, isNewDDC: isNewDDC);
    appModel._appIsFlutter.value = appIsFlutter;
    appModel._usesPackageWeb = hasPackageWebImport(dartSource);
    appModel._recalcLayout();

    _executionService?.execute(javaScript,
        modulesBaseUrl: modulesBaseUrl,
        engineVersion: engineVersion,
        reload: reload,
        isNewDDC: isNewDDC,
        isFlutter: appIsFlutter);
  }

  void dispose() {
    _httpClient.close();

    appModel.sourceCodeController.removeListener(_handleCodeChanged);
  }

  Future<void> _reAnalyze() async {
    try {
      final results = await services.analyze(
        SourceRequest(source: appModel.sourceCodeController.text),
      );
      appModel.analysisIssues.value = results.issues;
    } catch (error) {
      appModel.analysisIssues.value = [
        AnalysisIssue(
          kind: 'error',
          message: '$error',
          location: Location(line: 0, column: 0),
        ),
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

enum Channel {
  stable('Stable', 'https://stable.api.dartpad.dev/'),
  beta('Beta', 'https://beta.api.dartpad.dev/'),
  main('Main', 'https://master.api.dartpad.dev/'),
  // This channel is only used for local development.
  localhost('Localhost', 'http://localhost:8080/');

  final String displayName;
  final String url;

  const Channel(this.displayName, this.url);

  static const defaultChannel = Channel.stable;

  static List<Channel> get valuesWithoutLocalhost {
    return values.whereNot((channel) => channel == localhost).toList();
  }

  static Channel? forName(String name) {
    name = name.trim().toLowerCase();

    // Alias 'master' to 'main'.
    if (name == 'master') {
      name = 'main';
    }

    return Channel.values.firstWhereOrNull((c) => c.name == name);
  }
}

extension VersionResponseExtension on VersionResponse {
  String get label => 'Dart $dartVersion • Flutter $flutterVersion';
}

class SplitDragStateManager {
  final _splitDragStateController =
      StreamController<SplitDragState>.broadcast();
  late final Stream<SplitDragState> onSplitDragUpdated;

  SplitDragStateManager(
      {Duration timeout = const Duration(milliseconds: 100)}) {
    onSplitDragUpdated = _splitDragStateController.stream.timeout(timeout,
        onTimeout: (eventSink) {
      eventSink.add(SplitDragState.inactive);
    });
  }

  void handleSplitChanged() {
    _splitDragStateController.add(SplitDragState.active);
  }
}

enum SplitDragState { inactive, active }

class PromptDialogResponse {
  const PromptDialogResponse({
    required this.appType,
    required this.prompt,
    this.attachments = const [],
  });

  final AppType appType;
  final String prompt;
  final List<Attachment> attachments;
}

enum CompilingState {
  none(false),
  reloading(true),
  restarting(true);

  final bool busy;

  const CompilingState(this.busy);
}

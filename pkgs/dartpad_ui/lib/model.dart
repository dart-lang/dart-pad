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
import 'widgets.dart';

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
  Stream<String> get onStderr;
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

enum GenAiState { standby, generating, awaitingAcceptReject }

class AppModel {
  final ValueNotifier<bool?> appIsFlutter = ValueNotifier(null);
  AppType get appType =>
      appIsFlutter.value == true ? AppType.flutter : AppType.dart;

  final ValueNotifier<bool> appReady = ValueNotifier(false);

  final ValueNotifier<List<AnalysisIssue>> analysisIssues = ValueNotifier([]);
  final ValueNotifier<List<String>> importUrls = ValueNotifier([]);

  final ValueNotifier<String> title = ValueNotifier('');

  final TextEditingController sourceCodeController = TextEditingController();
  final ConsoleNotifier consoleNotifier = ConsoleNotifier('', '');

  final ValueNotifier<bool> formattingBusy = ValueNotifier(false);
  final ValueNotifier<CompilingState> compilingState = ValueNotifier(
    CompilingState.none,
  );
  final ValueNotifier<bool> docHelpBusy = ValueNotifier(false);

  final ValueNotifier<bool> hasRun = ValueNotifier(false);
  final ValueNotifier<bool> canReload = ValueNotifier(false);

  final StatusController editorStatus = StatusController();

  final ValueNotifier<VersionResponse?> runtimeVersions = ValueNotifier(null);

  final ValueNotifier<LayoutMode> _layoutMode = ValueNotifier(LayoutMode.both);
  ValueListenable<LayoutMode> get layoutMode => _layoutMode;

  final ValueNotifier<SplitDragState> splitViewDragState = ValueNotifier(
    SplitDragState.inactive,
  );

  final SplitDragStateManager splitDragStateManager = SplitDragStateManager();
  late final StreamSubscription<SplitDragState> _splitSubscription;

  final ValueNotifier<bool> vimKeymapsEnabled = ValueNotifier(false);

  bool get consoleShowingError => consoleNotifier.error.isNotEmpty;

  final ValueNotifier<bool> showReload = ValueNotifier(false);
  final ValueNotifier<bool> useNewDDC = ValueNotifier(false);
  final ValueNotifier<String?> currentDeltaDill = ValueNotifier(null);

  final ValueNotifier<GenAiState> genAiState = ValueNotifier(
    GenAiState.standby,
  );
  final ValueNotifier<Stream<String>> genAiCodeStream = ValueNotifier(
    Stream<String>.empty(),
  );
  final ValueNotifier<StringBuffer> genAiCodeStreamBuffer = ValueNotifier(
    StringBuffer(),
  );
  final ValueNotifier<bool> genAiCodeStreamIsDone = ValueNotifier(true);
  PromptDialogResponse? genAiActivePromptInfo;
  TextEditingController? genAiActivePromptTextController;
  ImageAttachmentsManager? genAiActiveImageAttachmentsManager;
  final TextEditingController genAiNewCodePromptController =
      TextEditingController();
  final TextEditingController genAiCodeEditPromptController =
      TextEditingController();
  final ValueNotifier<bool> genAiGeneratingNewProject = ValueNotifier(true);

  AppModel() {
    consoleNotifier.addListener(_recalcLayout);
    void updateCanReload() =>
        canReload.value =
            hasRun.value &&
            !compilingState.value.busy &&
            currentDeltaDill.value != null;
    hasRun.addListener(updateCanReload);
    compilingState.addListener(updateCanReload);
    currentDeltaDill.addListener(updateCanReload);

    void updateShowReload() {
      showReload.value = useNewDDC.value && (appIsFlutter.value ?? false);
    }

    void updateAppType() {
      appIsFlutter.value = hasFlutterImports(importUrls.value);
    }

    useNewDDC.addListener(updateShowReload);
    appIsFlutter.addListener(updateShowReload);
    importUrls.addListener(updateAppType);

    _splitSubscription = splitDragStateManager.onSplitDragUpdated.listen((
      SplitDragState value,
    ) {
      splitViewDragState.value = value;
    });
  }

  void appendLineToConsole(String str) {
    consoleNotifier.output += '$str\n';
  }

  void appendError(String str) {
    consoleNotifier.error += '$str\n';
  }

  void clearConsole() {
    consoleNotifier.clear();
  }

  void dispose() {
    consoleNotifier.removeListener(_recalcLayout);
    _splitSubscription.cancel();
  }

  void _recalcLayout() {
    final hasConsoleText = !consoleNotifier.isEmpty;
    final isFlutter = appIsFlutter.value;
    final usesPackageWeb = hasPackageWebImport(importUrls.value);

    if (isFlutter == null) {
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
  StreamSubscription<String>? stderrSub;

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
      appModel.useNewDDC.value = _hotReloadableChannels.contains(
        _channel.value,
      );
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
    final source = Samples.defaultSnippet(
      forFlutter: type.toLowerCase() == 'flutter',
    );

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
      final progress = appModel.editorStatus.showMessage(
        initialText: 'Loading…',
      );
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

        appModel.appendError('Error loading sample: $e');

        appModel.sourceCodeController.text = getFallback();
        appModel.appReady.value = true;
      } finally {
        loader.dispose();
      }

      return;
    }

    if (gistId != null) {
      final gistLoader = GistLoader();
      final progress = appModel.editorStatus.showMessage(
        initialText: 'Loading…',
      );
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

        appModel.appendError('Error loading gist: $e');

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
    final willUseReload = reload && appModel.useNewDDC.value;

    final source = appModel.sourceCodeController.text;
    final progress = appModel.editorStatus.showMessage(
      initialText: willUseReload ? 'Reloading…' : 'Compiling…',
    );

    try {
      CompileDDCResponse response;
      if (!appModel.useNewDDC.value) {
        response = await _compileDDC(CompileRequest(source: source));
      } else if (reload) {
        response = await _compileNewDDCReload(
          CompileRequest(
            source: source,
            deltaDill: appModel.currentDeltaDill.value!,
          ),
        );
      } else {
        response = await _compileNewDDC(CompileRequest(source: source));
      }
      if (!reload || appModel.consoleShowingError) {
        appModel.clearConsole();
      }
      _executeJavaScript(
        response.result,
        modulesBaseUrl: response.modulesBaseUrl,
        engineVersion: appModel.runtimeVersions.value?.engineVersion,
        dartSource: source,
        isNewDDC: appModel.useNewDDC.value,
        reload: reload,
      );
      appModel.currentDeltaDill.value = response.deltaDill;
      appModel.hasRun.value = true;
    } catch (error) {
      appModel.clearConsole();

      appModel.editorStatus.showToast('Compilation failed');

      if (error is ApiRequestError) {
        appModel.appendError(error.message);
        appModel.appendError(error.body);
      } else {
        appModel.appendError('$error');
      }
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
      appModel.compilingState.value = CompilingState.restarting;
      return await services.compile(request);
    } finally {
      appModel.compilingState.value = CompilingState.none;
    }
  }

  Stream<String> suggestFix(SuggestFixRequest request) {
    return services.suggestFix(request);
  }

  Stream<String> generateCode(GenerateCodeRequest request) {
    return services.generateCode(request);
  }

  Stream<String> generateUi(GenerateUiRequest request) {
    return services.generateUi(request);
  }

  Stream<String> updateCode(UpdateCodeRequest request) {
    return services.updateCode(request);
  }

  Future<CompileDDCResponse> _compileDDC(CompileRequest request) async {
    try {
      appModel.compilingState.value = CompilingState.restarting;
      return await services.compileDDC(request);
    } finally {
      appModel.compilingState.value = CompilingState.none;
    }
  }

  Future<CompileDDCResponse> _compileNewDDC(CompileRequest request) async {
    try {
      appModel.compilingState.value = CompilingState.restarting;
      return await services.compileNewDDC(request);
    } finally {
      appModel.compilingState.value = CompilingState.none;
    }
  }

  Future<CompileDDCResponse> _compileNewDDCReload(
    CompileRequest request,
  ) async {
    try {
      appModel.compilingState.value = CompilingState.reloading;
      return await services.compileNewDDCReload(request);
    } finally {
      appModel.compilingState.value = CompilingState.none;
    }
  }

  void registerExecutionService(ExecutionService? executionService) {
    // unregister the old
    stdoutSub?.cancel();
    stderrSub?.cancel();

    // replace the service
    _executionService = executionService;

    // register the new
    if (_executionService != null) {
      stdoutSub = _executionService!.onStdout.listen((msg) {
        appModel.appendLineToConsole(msg);
      });
      stderrSub = _executionService!.onStderr.listen(
        (msg) => appModel.appendError(msg),
      );
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
    appModel._recalcLayout();

    _executionService?.execute(
      javaScript,
      modulesBaseUrl: modulesBaseUrl,
      engineVersion: engineVersion,
      reload: reload,
      isNewDDC: isNewDDC,
      isFlutter: appModel.appIsFlutter.value ?? false,
    );
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
      appModel.importUrls.value = results.imports;
    } catch (error) {
      appModel.analysisIssues.value = [
        AnalysisIssue(
          kind: 'error',
          message: '$error',
          location: Location(line: 0, column: 0),
        ),
      ];
      appModel.importUrls.value = [];
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
        appModel.editorStatus.showMessage(
          initialText: message,
          name: 'problems',
        );
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

  SplitDragStateManager({
    Duration timeout = const Duration(milliseconds: 100),
  }) {
    onSplitDragUpdated = _splitDragStateController.stream.timeout(
      timeout,
      onTimeout: (eventSink) {
        eventSink.add(SplitDragState.inactive);
      },
    );
  }

  void handleSplitChanged() {
    _splitDragStateController.add(SplitDragState.active);
  }
}

enum SplitDragState { inactive, active }

enum CompilingState {
  none(false),
  reloading(true),
  restarting(true);

  final bool busy;

  const CompilingState(this.busy);
}

class PromptDialogResponse {
  const PromptDialogResponse({
    required this.appType,
    required this.prompt,
    required this.promptTextController,
    required this.imageAttachmentsManager,
  });

  final AppType appType;
  final String prompt;
  final TextEditingController promptTextController;
  final ImageAttachmentsManager imageAttachmentsManager;
}

class ConsoleNotifier extends ChangeNotifier {
  String _output;
  String _error;

  ConsoleNotifier(this._output, this._error);

  String get output => _output;

  set output(String value) {
    _output = value;
    notifyListeners();
  }

  String get error => _error;
  set error(String value) {
    _error = value;
    notifyListeners();
  }

  void clear() {
    _output = '';
    _error = '';
    notifyListeners();
  }

  bool get isEmpty => _output.isEmpty && _error.isEmpty;
  bool get hasError => _error.isNotEmpty;
  String get valueToDisplay => hasError ? _error : _output;
}

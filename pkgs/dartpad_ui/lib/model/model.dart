// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_shared/backend_client.dart';
import 'package:dartpad_shared/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../primitives/enable_websockets.dart';
import '../primitives/flutter_samples.dart';
import '../primitives/gists.dart';
import '../primitives/samples.g.dart';
import '../primitives/utils.dart';

abstract class ExecutionService {
  Future<void> execute(
    Channel usingChannel,
    String javaScript, {
    String? engineVersion,
    required bool isNewDDC,
    required bool reload,
    required bool isFlutter,
  });
  Stream<String> get onStdout;
  Stream<String> get onStderr;
  Stream<String> get onJavascriptError;
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

  /// Let the editor know to account for any resizing or visibility changes.
  void refreshViewAfterWait();
}

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

  final GenAiManager genAiManager = GenAiManager();

  AppModel() {
    consoleNotifier.addListener(_recalcLayout);
    void updateCanReload() => canReload.value =
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
    consoleNotifier.hasJavascriptError = false;
  }

  void appendError(String str, {bool isJavascript = false}) {
    consoleNotifier.error += '$str\n';
    if (isJavascript) {
      consoleNotifier.hasJavascriptError = true;
    } else {
      consoleNotifier.hasJavascriptError = false;
    }
  }

  void clearConsole() {
    consoleNotifier.clear();
    consoleNotifier.hasJavascriptError = false;
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

  late DartServicesClient services;
  WebsocketServicesClient? webSocketServices;

  ExecutionService? _executionService;
  EditorService? _editorService;

  StreamSubscription<String>? stdoutSub;
  StreamSubscription<String>? stderrSub;
  StreamSubscription<String>? javascriptErrorSub;

  // TODO: Consider using DebounceStreamTransformer from package:rxdart.
  Timer? reanalysisDebouncer;

  static const Set<Channel> _hotReloadableChannels = {
    Channel.stable,
    Channel.beta,
    Channel.main,
    Channel.localhost,
  };

  /// Create a new instance of [AppServices].
  ///
  /// Note that after object creation, [init] must still be called in order to
  /// finish initialization.
  AppServices(this.appModel, Channel channel) {
    _channel.value = channel;

    services = DartServicesClient(
      DartServicesHttpClient(),
      rootUrl: channel.url,
    );

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

  /// Initialize async elements of the service connection.
  Future<void> init() async {
    if (useWebsockets) {
      webSocketServices = await WebsocketServicesClient.connect(
        services.rootUrl,
      );
    }
  }

  EditorService? get editorService => _editorService;
  ExecutionService? get executionService => _executionService;

  ValueListenable<Channel> get channel => _channel;

  Future<VersionResponse> setChannel(Channel channel) async {
    services = DartServicesClient(services.client, rootUrl: channel.url);

    if (useWebsockets) {
      webSocketServices = await WebsocketServicesClient.connect(
        services.rootUrl,
      );
    }

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
    VersionResponse version;
    if (useWebsockets) {
      version = await webSocketServices!.version();
      appModel.runtimeVersions.value = version;
    } else {
      // ignore: deprecated_member_use
      version = await services.version();
      appModel.runtimeVersions.value = version;
    }
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
        appModel.title.value = title.length > 40
            ? '${title.substring(0, 40)}…'
            : title;

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
      if (useWebsockets) {
        return await webSocketServices!.format(request);
      } else {
        // ignore: deprecated_member_use
        return await services.format(request);
      }
    } finally {
      appModel.formattingBusy.value = false;
    }
  }

  Future<DocumentResponse> document(SourceRequest request) async {
    if (useWebsockets) {
      return await webSocketServices!.document(request);
    } else {
      // ignore: deprecated_member_use
      return await services.document(request);
    }
  }

  Stream<String> suggestFix(SuggestFixRequest request) {
    if (useWebsockets) {
      return webSocketServices!.suggestFix(request);
    } else {
      // ignore: deprecated_member_use
      return services.suggestFix(request);
    }
  }

  /// Generates the code with Gemini.
  Stream<String> generateCode(GenerateCodeRequest request) {
    if (useWebsockets) {
      return webSocketServices!.generateCode(request);
    } else {
      // ignore: deprecated_member_use
      return services.generateCode(request);
    }
  }

  /// Updates code with Gemini.
  Stream<String> updateCode(UpdateCodeRequest request) {
    if (useWebsockets) {
      return webSocketServices!.updateCode(request);
    } else {
      // ignore: deprecated_member_use
      return services.updateCode(request);
    }
  }

  Future<CompileDDCResponse> _compileDDC(CompileRequest request) async {
    try {
      appModel.compilingState.value = CompilingState.restarting;
      if (useWebsockets) {
        return await webSocketServices!.compileDDC(request);
      } else {
        // ignore: deprecated_member_use
        return await services.compileDDC(request);
      }
    } finally {
      appModel.compilingState.value = CompilingState.none;
    }
  }

  Future<CompileDDCResponse> _compileNewDDC(CompileRequest request) async {
    try {
      appModel.compilingState.value = CompilingState.restarting;
      if (useWebsockets) {
        return await webSocketServices!.compileNewDDC(request);
      } else {
        // ignore: deprecated_member_use
        return await services.compileNewDDC(request);
      }
    } finally {
      appModel.compilingState.value = CompilingState.none;
    }
  }

  Future<CompileDDCResponse> _compileNewDDCReload(
    CompileRequest request,
  ) async {
    try {
      appModel.compilingState.value = CompilingState.reloading;
      if (useWebsockets) {
        return await webSocketServices!.compileNewDDCReload(request);
      } else {
        // ignore: deprecated_member_use
        return await services.compileNewDDCReload(request);
      }
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
      javascriptErrorSub = _executionService!.onJavascriptError.listen(
        (msg) => appModel.appendError(msg, isJavascript: true),
      );
    }
  }

  void registerEditorService(EditorService? editorService) {
    _editorService = editorService;
  }

  void _executeJavaScript(
    String javaScript, {
    required String dartSource,
    String? engineVersion,
    required bool isNewDDC,
    required bool reload,
  }) {
    appModel._recalcLayout();

    void execute() {
      _executionService?.execute(
        channel.value,
        javaScript,
        engineVersion: engineVersion,
        reload: reload,
        isNewDDC: isNewDDC,
        isFlutter: appModel.appIsFlutter.value ?? false,
      );
    }

    if (appModel.appIsFlutter.value == null) {
      final completer = Completer<void>();
      void listener() {
        completer.complete();
      }

      final callback = listener;

      appModel.appIsFlutter.addListener(callback);
      completer.future.then((_) {
        appModel.appIsFlutter.removeListener(callback);
        execute();
      });
    } else {
      execute();
    }
  }

  void dispose() {
    services.dispose();

    appModel.sourceCodeController.removeListener(_handleCodeChanged);
  }

  Future<void> _reAnalyze() async {
    try {
      final AnalysisResponse results;
      if (useWebsockets) {
        results = await webSocketServices!.analyze(
          SourceRequest(source: appModel.sourceCodeController.text),
        );
      } else {
        // ignore: deprecated_member_use
        results = await services.analyze(
          SourceRequest(source: appModel.sourceCodeController.text),
        );
      }

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

extension VersionResponseExtension on VersionResponse {
  String get label => 'Dart $dartVersion • Flutter $flutterVersion';
}

class SplitDragStateManager {
  // We need broadcast, because sometimes a new widget wants to subscribe,
  // when state of previous one is not disposed yet.
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
    this.attachments = const [],
  });

  final AppType appType;
  final String prompt;
  final List<Attachment> attachments;
}

class ConsoleNotifier extends ChangeNotifier {
  String _output;
  String _error;
  bool _hasJavascriptError = false;

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

  bool get hasJavascriptError => _hasJavascriptError;
  set hasJavascriptError(bool value) {
    _hasJavascriptError = value;
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

enum GenAiActivity { generating, awaitingAcceptance }

enum GenAiCuj { generateCode, editCode, suggestFix }

/// GenAI related state for the application.
class GenAiManager {
  final ValueNotifier<GenAiActivity?> activity = ValueNotifier(null);
  final ValueNotifier<Stream<String>> stream = ValueNotifier(
    Stream<String>.empty(),
  );
  final ValueNotifier<StringBuffer> streamBuffer = ValueNotifier(
    StringBuffer(),
  );
  final ValueNotifier<bool> streamIsDone = ValueNotifier(true);

  final TextEditingController newCodePromptController = TextEditingController();
  final TextEditingController codeEditPromptController =
      TextEditingController();

  final List<Attachment> newCodeAttachments = [];
  final List<Attachment> codeEditAttachments = [];

  final ValueNotifier<GenAiCuj?> cuj = ValueNotifier(null);
  final ValueNotifier<String> preGenAiSourceCode = ValueNotifier('');

  GenAiManager();

  ValueNotifier<GenAiActivity?> get currentActivity {
    return activity;
  }

  void enterGeneratingNew() {
    activity.value = GenAiActivity.generating;
    cuj.value = GenAiCuj.generateCode;
  }

  void enterGeneratingEdit() {
    activity.value = GenAiActivity.generating;
    cuj.value = GenAiCuj.editCode;
  }

  void enterSuggestingFix() {
    activity.value = GenAiActivity.generating;
    cuj.value = GenAiCuj.suggestFix;
  }

  void finishActivity() {
    activity.value = null;
    streamIsDone.value = true;
    streamBuffer.value.clear();
    newCodeAttachments.clear();
    codeEditAttachments.clear();
  }

  void enterAwaitingAcceptance() {
    activity.value = GenAiActivity.awaitingAcceptance;
  }

  void startStream(Stream<String> newStream, [VoidCallback? onDone]) {
    stream.value = newStream.asBroadcastStream();
  }

  void setStreamIsDone(bool isDone) {
    streamIsDone.value = isDone;
  }

  void resetState() {
    codeEditPromptController.text = '';
    newCodePromptController.text = '';
    finishActivity();
    cuj.value = null;
  }

  String generatedCode() {
    return streamBuffer.value.toString();
  }

  void setEditPromptText(String newPrompt) {
    codeEditPromptController.text = newPrompt;
  }

  void writeToStreamBuffer(String text) {
    streamBuffer.value.write(text);
  }

  void setStreamBufferValue(String text) {
    streamBuffer.value.clear();
    streamBuffer.value.write(text);
  }
}

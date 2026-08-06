// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/preview/models/compiler_session.dart';
import 'package:dartpad_frontend/features/preview/models/preview_sandbox.dart';
import 'package:dartpad_frontend/features/preview/models/preview_state.dart';
import 'package:dartpad_frontend/features/preview/view_models/preview_view_model.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/events/log_event.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

final class FakeWorkspaceResourceApi implements WorkspaceResourceApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 50));

class FakeCompilerSession implements CompilerSession {
  int compileCount = 0;
  int closeCount = 0;

  FutureOr<({String? code, List<String> compiledLibraryUris, String? log})> Function()? onCompile;
  Future<void> Function()? onClose;

  @override
  Future<({String? code, List<String> compiledLibraryUris, String? log})> compile() async {
    compileCount++;
    if (onCompile != null) {
      return onCompile!();
    }
    return (code: 'compiled_code', compiledLibraryUris: <String>['package:app/main.dart'], log: 'compiled log');
  }

  @override
  Future<void> close() async {
    closeCount++;
    if (onClose != null) {
      await onClose!();
    }
  }
}

class FakePreviewSandbox implements PreviewSandbox {
  int disposeCount = 0;
  int loadModuleCount = 0;
  int runAppCount = 0;
  int hotReloadCount = 0;

  final consoleController = StreamController<ConsoleMessage>.broadcast();
  final errorController = StreamController<({String message})>.broadcast();
  final rejectionController = StreamController<({String message})>.broadcast();

  String? loadedCode;
  Uri? runUri;
  String? reloadedCode;
  List<Uri>? reloadedLibraries;

  Future<void> Function({required String code})? onLoadModule;
  Future<void> Function(Uri libraryUri)? onRunApp;
  Future<void> Function({required String? code, required List<Uri> librariesToReload})? onHotReload;

  @override
  void dispose() {
    disposeCount++;
    consoleController.close();
    errorController.close();
    rejectionController.close();
  }

  @override
  Future<void> loadModule({required String code}) async {
    loadModuleCount++;
    loadedCode = code;
    if (onLoadModule != null) {
      await onLoadModule!(code: code);
    }
  }

  @override
  Future<void> runApp(Uri libraryUri) async {
    runAppCount++;
    runUri = libraryUri;
    if (onRunApp != null) {
      await onRunApp!(libraryUri);
    }
  }

  @override
  Future<void> hotReload({required String? code, required List<Uri> librariesToReload}) async {
    hotReloadCount++;
    reloadedCode = code;
    reloadedLibraries = librariesToReload;
    if (onHotReload != null) {
      await onHotReload!(code: code, librariesToReload: librariesToReload);
    }
  }

  @override
  Stream<ConsoleMessage> get onConsole => consoleController.stream;

  @override
  Stream<({String message})> get onError => errorController.stream;

  @override
  Stream<({String message})> get onUnhandledRejection => rejectionController.stream;
}

class FakeWorkspaceRepository extends WorkspaceRepository {
  FakeWorkspaceRepository(AppEventBus events, WorkspaceResourceApi workspaceResourceApi)
    : super(
        events: events,
        workspaceResourceApi: workspaceResourceApi,
        workspaceFuture: Completer<Workspace>().future,
      );

  int startHotReloadCompilerCount = 0;
  int convertToPackageUriCount = 0;

  CompilerSession Function(Uri uri)? onStartHotReloadCompiler;
  Uri Function(String filePath)? onConvertToPackageUri;

  @override
  Future<CompilerSession> startHotReloadCompiler(Uri uri) async {
    startHotReloadCompilerCount++;
    if (onStartHotReloadCompiler != null) {
      return onStartHotReloadCompiler!(uri);
    }
    return FakeCompilerSession();
  }

  @override
  Future<Uri> convertToPackageUri(String filePath) async {
    convertToPackageUriCount++;
    if (onConvertToPackageUri != null) {
      return onConvertToPackageUri!(filePath);
    }
    return Uri.parse('package:app/main.dart');
  }
}

void main() {
  group('PreviewViewModel', () {
    late AppEventBus events;
    late FakeWorkspaceRepository repository;
    late List<LogEvent> loggedEvents;
    late StreamSubscription<LogEvent> logSubscription;

    setUp(() {
      events = AppEventBus();
      loggedEvents = [];
      logSubscription = events.on<LogEvent>().listen(loggedEvents.add);
      repository = FakeWorkspaceRepository(events, FakeWorkspaceResourceApi());
    });

    tearDown(() async {
      await logSubscription.cancel();
      await events.dispose();
    });

    test('initial state is correct', () {
      final viewModel = PreviewViewModel(
        workspaceRepository: repository,
        eventBus: events,
      );

      expect(viewModel.state, isA<PreviewInitial>());
      expect(viewModel.canStart, isTrue);
      expect(viewModel.canRestart, isFalse);
      expect(viewModel.canHotReload, isFalse);
      expect(viewModel.canStop, isFalse);
      expect(viewModel.isRunning, isFalse);

      viewModel.dispose();
    });

    test('runCode compiles and runs successfully', () async {
      final fakeSandbox = FakePreviewSandbox();
      final fakeCompiler = FakeCompilerSession();

      repository.onStartHotReloadCompiler = (_) => fakeCompiler;

      final viewModel = PreviewViewModel(
        workspaceRepository: repository,
        eventBus: events,
        createSandbox: (_, {required assetBaseUrl}) async => fakeSandbox,
      );

      final stateChanges = <PreviewState>[];
      viewModel.addListener(() {
        stateChanges.add(viewModel.state);
      });

      await viewModel.runCode('lib/main.dart');
      await pump();

      expect(stateChanges, [
        isA<PreviewStarting>(),
        isA<PreviewRunning>(),
      ]);

      expect(viewModel.state, isA<PreviewRunning>());
      expect(viewModel.canStart, isFalse);
      expect(viewModel.canRestart, isTrue);
      expect(viewModel.canHotReload, isTrue);
      expect(viewModel.canStop, isTrue);
      expect(viewModel.isRunning, isTrue);

      expect(fakeCompiler.compileCount, 1);
      expect(fakeSandbox.loadModuleCount, 1);
      expect(fakeSandbox.loadedCode, 'compiled_code');
      expect(fakeSandbox.runAppCount, 1);
      expect(fakeSandbox.runUri, Uri.parse('package:app/main.dart'));

      final logMessages = loggedEvents.map((e) => e.message).toList();
      expect(
        logMessages,
        containsAll([
          'Run lib/main.dart',
          'Starting compiler...',
          'Creating hot reload compiler...',
          'Compilation succeeded.',
          'Running application...',
          'App is running.',
        ]),
      );

      viewModel.dispose();
      expect(fakeCompiler.closeCount, 1);
      expect(fakeSandbox.disposeCount, 1);
    });

    test('runCode fails compilation with CompilationFailedException', () async {
      final fakeCompiler = FakeCompilerSession()..onCompile = () => throw CompilationFailedException('syntax error');

      repository.onStartHotReloadCompiler = (_) => fakeCompiler;

      final viewModel = PreviewViewModel(
        workspaceRepository: repository,
        eventBus: events,
      );

      await viewModel.runCode('lib/main.dart');
      await pump();

      expect(viewModel.state, isA<PreviewCompileError>());
      final errState = viewModel.state as PreviewCompileError;
      expect(errState.message, 'syntax error');
      expect(errState.entrypoint, 'lib/main.dart');

      expect(loggedEvents.any((e) => e.message == 'Compilation failed' && e.level == Level.SEVERE), isTrue);

      viewModel.dispose();
    });

    test('runCode fails with generic runtime error', () async {
      final fakeSandbox = FakePreviewSandbox()..onRunApp = (_) => throw Exception('load crash');

      final viewModel = PreviewViewModel(
        workspaceRepository: repository,
        eventBus: events,
        createSandbox: (_, {required assetBaseUrl}) async => fakeSandbox,
      );

      await viewModel.runCode('lib/main.dart');
      await pump();

      expect(viewModel.state, isA<PreviewCompileError>());
      final errState = viewModel.state as PreviewCompileError;
      expect(errState.message, contains('load crash'));

      expect(loggedEvents.any((e) => e.message == 'Run failed' && e.level == Level.SEVERE), isTrue);

      viewModel.dispose();
    });

    test('runCode skipRecompilation = true reuses previous compilation', () async {
      final fakeSandbox1 = FakePreviewSandbox();
      final fakeSandbox2 = FakePreviewSandbox();
      final fakeCompiler = FakeCompilerSession();

      repository.onStartHotReloadCompiler = (_) => fakeCompiler;

      var currentSandboxIndex = 0;
      final viewModel = PreviewViewModel(
        workspaceRepository: repository,
        eventBus: events,
        createSandbox: (_, {required assetBaseUrl}) async {
          currentSandboxIndex++;
          return currentSandboxIndex == 1 ? fakeSandbox1 : fakeSandbox2;
        },
      );

      await viewModel.runCode('lib/main.dart');
      expect(fakeCompiler.compileCount, 1);
      expect(fakeSandbox1.loadModuleCount, 1);

      // Trigger restart which skips recompilation
      await viewModel.runCode('lib/main.dart', skipRecompilation: true);

      // Compiler should NOT be called again
      expect(fakeCompiler.compileCount, 1);
      expect(fakeSandbox1.disposeCount, 1);
      expect(fakeSandbox2.loadModuleCount, 1);
      expect(fakeSandbox2.loadedCode, 'compiled_code'); // Reuses compiled code

      viewModel.dispose();
    });

    test('hotReloadCode compiles and reloads successfully', () async {
      final fakeSandbox = FakePreviewSandbox();
      final fakeCompiler = FakeCompilerSession();

      repository.onStartHotReloadCompiler = (_) => fakeCompiler;

      final viewModel = PreviewViewModel(
        workspaceRepository: repository,
        eventBus: events,
        createSandbox: (_, {required assetBaseUrl}) async => fakeSandbox,
      );

      await viewModel.runCode('lib/main.dart');
      expect(viewModel.state, isA<PreviewRunning>());

      // Modify compilation output for reload
      fakeCompiler.onCompile = () =>
          (code: 'updated_code', compiledLibraryUris: <String>['package:app/main.dart'], log: 'reload compile log');

      final stateChanges = <PreviewState>[];
      viewModel.addListener(() {
        stateChanges.add(viewModel.state);
      });

      await viewModel.hotReloadCode();
      await pump();

      expect(stateChanges, [
        isA<PreviewHotReloading>(),
        isA<PreviewRunning>(),
      ]);

      expect(fakeCompiler.compileCount, 2);
      expect(fakeSandbox.hotReloadCount, 1);
      expect(fakeSandbox.reloadedCode, 'updated_code');
      expect(fakeSandbox.reloadedLibraries, [Uri.parse('package:app/main.dart')]);

      expect(loggedEvents.map((e) => e.message), contains('Hot reload completed successfully.'));

      viewModel.dispose();
    });

    test('hotReloadCode handles HotReloadRejectedException', () async {
      final fakeSandbox = FakePreviewSandbox()
        ..onHotReload = ({code, required librariesToReload}) => throw HotReloadRejectedException('rejected reload');

      final viewModel = PreviewViewModel(
        workspaceRepository: repository,
        eventBus: events,
        createSandbox: (_, {required assetBaseUrl}) async => fakeSandbox,
      );

      await viewModel.runCode('lib/main.dart');
      await viewModel.hotReloadCode();
      await pump();

      expect(viewModel.state, isA<PreviewCompileError>());
      expect((viewModel.state as PreviewCompileError).message, 'rejected reload');

      expect(loggedEvents.any((e) => e.message == 'Hot reload rejected' && e.level == Level.WARNING), isTrue);

      viewModel.dispose();
    });

    test('stopCode stops and resets everything', () async {
      final fakeSandbox = FakePreviewSandbox();
      final fakeCompiler = FakeCompilerSession();

      repository.onStartHotReloadCompiler = (_) => fakeCompiler;

      final viewModel = PreviewViewModel(
        workspaceRepository: repository,
        eventBus: events,
        createSandbox: (_, {required assetBaseUrl}) async => fakeSandbox,
      );

      await viewModel.runCode('lib/main.dart');
      expect(viewModel.state, isA<PreviewRunning>());

      final stateChanges = <PreviewState>[];
      viewModel.addListener(() {
        stateChanges.add(viewModel.state);
      });

      await viewModel.stopCode();

      expect(stateChanges, [
        isA<PreviewStopping>(),
        isA<PreviewInitial>(),
      ]);

      expect(viewModel.state, isA<PreviewInitial>());
      expect(fakeSandbox.disposeCount, 1);
      expect(fakeCompiler.closeCount, 1);

      // Subsequent skipRecompilation should trigger compile since cache was cleared
      fakeSandbox.loadModuleCount = 0;
      await viewModel.runCode('lib/main.dart', skipRecompilation: true);
      expect(fakeCompiler.compileCount, 2);

      viewModel.dispose();
    });

    test('forwards sandbox console events correctly', () async {
      final fakeSandbox = FakePreviewSandbox();

      final viewModel = PreviewViewModel(
        workspaceRepository: repository,
        eventBus: events,
        createSandbox: (_, {required assetBaseUrl}) async => fakeSandbox,
      );

      await viewModel.runCode('lib/main.dart');

      fakeSandbox.consoleController.add((level: ConsoleLevel.warn, message: 'warning message'));
      await pump();
      fakeSandbox.consoleController.add((level: ConsoleLevel.error, message: 'error message'));
      await pump();
      fakeSandbox.consoleController.add((level: ConsoleLevel.info, message: 'info message'));
      await pump();
      fakeSandbox.consoleController.add((level: ConsoleLevel.log, message: 'log message'));
      await pump();

      fakeSandbox.errorController.add((message: 'critical runtime error'));
      await pump();
      fakeSandbox.rejectionController.add((message: 'unhandled promise rejection'));
      await pump();

      final appLogs = loggedEvents.where((e) => e.message.startsWith('[app] ')).toList();
      expect(appLogs.map((e) => e.message), [
        '[app] warning message',
        '[app] error message',
        '[app] info message',
        '[app] log message',
        '[app] critical runtime error',
        '[app] unhandled promise rejection',
      ]);

      expect(appLogs[0].level, Level.WARNING);
      expect(appLogs[1].level, Level.SEVERE);
      expect(appLogs[2].level, Level.INFO);
      expect(appLogs[3].level, Level.INFO);
      expect(appLogs[4].level, Level.SEVERE);
      expect(appLogs[5].level, Level.SEVERE);

      viewModel.dispose();
    });

    test('runCode aborts and cleans up if disposed during compilation', () async {
      final compiler = FakeCompilerSession();
      final compilerCompleter = Completer<({String? code, List<String> compiledLibraryUris, String? log})>();
      compiler.onCompile = () => compilerCompleter.future;

      repository.onStartHotReloadCompiler = (_) => compiler;

      final viewModel = PreviewViewModel(
        workspaceRepository: repository,
        eventBus: events,
      );

      final runFuture = viewModel.runCode('lib/main.dart');

      // Dispose the view model while compilation is pending
      viewModel.dispose();

      // Complete compilation
      compilerCompleter.complete((
        code: 'some_code',
        compiledLibraryUris: <String>['package:app/main.dart'],
        log: 'log',
      ));

      await runFuture;

      // The compiler should have been closed/disposed because the view model was disposed
      expect(compiler.closeCount, 1);
    });
  });
}

// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/preview/models/preview_sandbox.dart';
import 'package:dartpad_frontend/features/preview/models/preview_state.dart';
import 'package:dartpad_frontend/features/preview/models/run_mode.dart';
import 'package:dartpad_frontend/features/preview/view_models/preview_view_model.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/events/log_event.dart';
import 'package:dartpad_frontend/features/shared/log_source.dart';
import 'package:dartpad_frontend/features/shared/sdk_info.dart';
import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:dartpad_frontend/sdks.g.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

final class FakeWorkspaceResourceApi implements WorkspaceResourceApi {
  @override
  Future<bool> fileExist(String uri) async => uri == 'pubspec.yaml';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> pump() => Future<void>.delayed(Duration.zero);

final class _CancelFailingStream extends Stream<String> {
  _CancelFailingStream(this._delegate);

  final Stream<String> _delegate;

  @override
  StreamSubscription<String> listen(
    void Function(String event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _CancelFailingSubscription(
    _delegate.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError),
  );
}

final class _CancelFailingSubscription implements StreamSubscription<String> {
  _CancelFailingSubscription(this._delegate);

  final StreamSubscription<String> _delegate;

  @override
  Future<void> cancel() async {
    await _delegate.cancel();
    throw StateError('cancel failed');
  }

  @override
  void onData(void Function(String data)? handleData) => _delegate.onData(handleData);

  @override
  void onError(Function? handleError) => _delegate.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _delegate.onDone(handleDone);

  @override
  void pause([Future<void>? resumeSignal]) => _delegate.pause(resumeSignal);

  @override
  void resume() => _delegate.resume();

  @override
  bool get isPaused => _delegate.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) => _delegate.asFuture(futureValue);
}

final class FakePreviewSandbox implements PreviewSandbox {
  int disposeCount = 0;
  int runCount = 0;
  int hotRestartCount = 0;
  int hotReloadCount = 0;
  String? path;
  String? mode;
  final consoleController = StreamController<String>.broadcast(sync: true);
  final errorController = StreamController<String>.broadcast(sync: true);
  final rejectionController = StreamController<String>.broadcast(sync: true);
  Future<void> Function()? onRun;
  Future<void> Function()? onRestart;
  Future<void> Function()? onReload;
  Future<void> Function()? onClose;
  Exception? closeError;
  Stream<String>? consoleStream;
  @override
  List<String> modes = ['console', 'flutter'];
  @override
  Future<({String log})> run(String path, {required String mode}) async {
    runCount++;
    this.path = path;
    this.mode = mode;
    await onRun?.call();
    return (log: 'compiled and ran');
  }

  @override
  Future<({String log})> hotRestart() async {
    hotRestartCount++;
    await onRestart?.call();
    return (log: 'restarted');
  }

  @override
  Future<({String log})> hotReload() async {
    hotReloadCount++;
    await onReload?.call();
    return (log: 'reloaded');
  }

  @override
  Stream<String> get console => consoleStream ?? consoleController.stream;
  @override
  Stream<String> get errors => errorController.stream;
  @override
  Stream<String> get unhandledRejections => rejectionController.stream;
  @override
  Future<void> close() async {
    disposeCount++;
    await onClose?.call();
    await consoleController.close();
    await errorController.close();
    await rejectionController.close();
    if (closeError case final error?) {
      throw error;
    }
  }
}

WorkspaceRepository fakeWorkspaceRepository(
  AppEventBus events,
  WorkspaceResourceApi api, {
  SdkInfo? sdk,
}) => WorkspaceRepository(
  events: events,
  taskStatus: TaskStatusController(),
  workspaceResourceApi: api,
  sdk: sdk ?? defaultSdk,
  workspaceFuture: Completer<Workspace>().future,
);

void main() {
  late AppEventBus events;
  late WorkspaceRepository repository;
  late FakePreviewSandbox sandbox;
  late PreviewViewModel preview;
  late List<LogEvent> logs;
  late StreamSubscription<LogEvent> subscription;
  setUp(() {
    events = AppEventBus();
    repository = fakeWorkspaceRepository(events, FakeWorkspaceResourceApi());
    sandbox = FakePreviewSandbox();
    logs = [];
    subscription = events.on<LogEvent>().listen(logs.add);
    preview = PreviewViewModel(
      initialMode: RunMode.flutter,
      initialEntrypoint: 'lib/main.dart',
      workspaceRepository: repository,
      eventBus: events,
      createSandbox: (_, {required assetBaseUrl}) async => sandbox,
    );
  });
  tearDown(() async {
    preview.dispose();
    await preview.closed;
    await subscription.cancel();
    repository.taskStatus.dispose();
    await events.dispose();
  });

  test('starts in an idle state and respects blocking prerequisites', () async {
    expect(preview.previewMode, RunMode.flutter);
    expect(preview.canRun, isTrue);
    expect(preview.canStart, isTrue);
    final task = repository.taskStatus.startTask(TaskKind.pubGet, blocksPreview: true);
    expect(preview.canRun, isFalse);
    expect(preview.canStart, isFalse);
    await preview.runCode('lib/main.dart');
    expect(sandbox.runCount, 0);
    task.succeed();
    expect(preview.canRun, isTrue);
    expect(preview.canStart, isTrue);
  });

  test('without an initial entrypoint Run stays disabled until a file is explicitly run', () async {
    preview.dispose();
    await preview.closed;
    preview = PreviewViewModel(
      initialMode: RunMode.console,
      workspaceRepository: repository,
      eventBus: events,
      createSandbox: (_, {required assetBaseUrl}) async => sandbox,
    );
    expect(preview.canRun, isTrue);
    expect(preview.canStart, isFalse);
    await preview.runCurrent();
    expect(sandbox.runCount, 0);
    await preview.runCode('tool/check.dart');
    expect(preview.entrypoint, 'tool/check.dart');
    expect(sandbox.mode, 'console');
    await preview.runCurrent();
    expect(sandbox.hotRestartCount, 1);
  });

  test('explicit console override remains active when selecting a different run file', () async {
    preview.dispose();
    await preview.closed;
    preview = PreviewViewModel(
      initialMode: RunMode.console,
      workspaceRepository: repository,
      eventBus: events,
      initialEntrypoint: 'lib/main.dart',
      modeOverride: RunMode.console,
      createSandbox: (_, {required assetBaseUrl}) async => sandbox,
    );
    expect(preview.previewMode, RunMode.console);
    expect(sandbox.runCount, 0);
    await preview.runCurrent();
    expect(sandbox.mode, 'console');
    expect(preview.entrypoint, 'lib/main.dart');
  });

  test('uses explicit console mode with the Flutter SDK and routes early output', () async {
    sandbox.onRun = () async {
      sandbox.consoleController.add('early print');
    };
    await preview.runCode('lib/main.dart', mode: RunMode.console);
    expect(sandbox.mode, 'console');
    expect(preview.state, isA<PreviewDartReady>());
    expect(preview.previewMode, RunMode.console);
    expect(preview.appLogs.single.message, 'early print');
    expect(preview.canStart, isTrue);
    expect(preview.canStop, isFalse);
    expect(preview.canHotReload, isFalse);

    await preview.stopCode();
    expect(preview.previewMode, RunMode.console);
  });

  test('failed console run with the Flutter SDK retains console mode', () async {
    sandbox.onRun = () async {
      throw CompilationFailedException('syntax error');
    };

    await preview.runCode('lib/main.dart', mode: RunMode.console);

    expect(preview.state, isA<PreviewCompileError>());
    expect(preview.previewMode, RunMode.console);
  });

  test('Flutter start, hot reload, and restart use the same sandbox', () async {
    await preview.runCode('examples/counter/lib/main.dart', mode: RunMode.flutter);
    expect(preview.state, isA<PreviewRunning>());
    expect(sandbox.mode, 'flutter');
    await preview.hotReloadCode();
    await preview.restartCode();
    expect(sandbox.runCount, 1);
    expect(sandbox.hotReloadCount, 1);
    expect(sandbox.hotRestartCount, 1);
    expect(sandbox.disposeCount, 0);
    expect(sandbox.path, 'examples/counter/lib/main.dart');
  });

  test('restart is a no-op without a running preview', () async {
    await preview.restartCode();

    expect(sandbox.runCount, 0);
    expect(sandbox.hotRestartCount, 0);
  });

  test('another console run recompiles via hot restart', () async {
    await preview.runCode('bin/main.dart');
    expect(sandbox.mode, 'console');
    expect(preview.state, isA<PreviewDartReady>());
    await preview.runCode('bin/main.dart');
    expect(sandbox.runCount, 1);
    expect(sandbox.hotRestartCount, 1);
  });

  test('tool entrypoint starts in resolved console mode even with Flutter SDK', () async {
    preview.dispose();
    await preview.closed;
    preview = PreviewViewModel(
      workspaceRepository: repository,
      eventBus: events,
      initialEntrypoint: 'tool/check.dart',
      initialMode: await repository.runModeFor('tool/check.dart'),
      createSandbox: (_, {required assetBaseUrl}) async => sandbox,
    );
    expect(preview.previewMode, RunMode.console);
    expect(sandbox.runCount, 0);
    await preview.runCurrent();
    expect(sandbox.mode, 'console');
  });

  test('Dart SDK defaults to console', () async {
    preview.dispose();
    await preview.closed;
    repository.taskStatus.dispose();
    repository = fakeWorkspaceRepository(
      events,
      FakeWorkspaceResourceApi(),
      sdk: const SdkInfo(id: 'dart', name: 'Dart', path: 'dartpad/dart/', dartVersion: '3.14.0'),
    );
    preview = PreviewViewModel(
      initialMode: RunMode.console,
      initialEntrypoint: 'lib/main.dart',
      workspaceRepository: repository,
      eventBus: events,
      createSandbox: (_, {required assetBaseUrl}) async => sandbox,
    );
    expect(preview.previewMode, RunMode.console);
    await preview.runCode('lib/main.dart');
    expect(sandbox.mode, 'console');
    expect(preview.state, isA<PreviewDartReady>());
  });

  test('changed entrypoint or mode creates a new sandbox', () async {
    final created = <FakePreviewSandbox>[];
    preview.dispose();
    preview = PreviewViewModel(
      initialMode: RunMode.flutter,
      initialEntrypoint: 'lib/main.dart',
      workspaceRepository: repository,
      eventBus: events,
      createSandbox: (_, {required assetBaseUrl}) async {
        final value = FakePreviewSandbox();
        created.add(value);
        return value;
      },
    );
    await preview.runCode('lib/main.dart');
    await preview.runCode('lib/other.dart');
    await preview.runCode('lib/other.dart', mode: RunMode.console);
    expect(created.length, 3);
    expect(created.take(2).map((s) => s.disposeCount), [1, 1]);
    expect(created.last.mode, 'console');
  });

  test('save and flush finish before each run, restart and reload', () async {
    final order = <String>[];
    preview.dispose();
    preview = PreviewViewModel(
      initialMode: RunMode.flutter,
      initialEntrypoint: 'lib/main.dart',
      workspaceRepository: repository,
      eventBus: events,
      createSandbox: (_, {required assetBaseUrl}) async => sandbox,
      onSaveAll: () async {
        order.add('save');
      },
    );
    repository.onFlush = () async {
      order.add('flush');
    };
    sandbox.onRun = () async {
      order.add('run');
    };
    sandbox.onReload = () async {
      order.add('reload');
    };
    sandbox.onRestart = () async {
      order.add('restart');
    };
    await preview.runCode('lib/main.dart');
    await preview.hotReloadCode();
    await preview.runCode('lib/main.dart');
    expect(order, ['save', 'flush', 'run', 'save', 'flush', 'reload', 'save', 'flush', 'restart']);
  });

  test('failed synchronization prevents compilation', () async {
    repository.onFlush = () async {
      throw StateError('write failed');
    };
    await preview.runCode('lib/main.dart');
    expect(sandbox.runCount, 0);
    expect(preview.state, isA<PreviewCompileError>());
  });

  test('failed save prevents run and failed reload save preserves running app', () async {
    var fail = false;
    preview.dispose();
    preview = PreviewViewModel(
      initialMode: RunMode.flutter,
      initialEntrypoint: 'lib/main.dart',
      workspaceRepository: repository,
      eventBus: events,
      createSandbox: (_, {required assetBaseUrl}) async => sandbox,
      onSaveAll: () async {
        if (fail) {
          throw StateError('save failed');
        }
      },
    );
    await preview.runCode('lib/main.dart');
    fail = true;
    await preview.hotReloadCode();
    expect(sandbox.hotReloadCount, 0);
    expect(preview.state, isA<PreviewRunning>());
    await preview.runCode('lib/main.dart');
    expect(sandbox.hotRestartCount, 0);
    expect(preview.state, isA<PreviewCompileError>());
  });

  test('compilation and restart errors retain typed launch context', () async {
    await preview.runCode('lib/main.dart');
    sandbox.onRestart = () async {
      throw CompilationFailedException('syntax error');
    };
    await preview.runCode('lib/main.dart');
    final failure = preview.state as PreviewCompileError;
    expect(failure.message, 'syntax error');
    expect(failure.action, PreviewLaunchAction.restart);
    expect(failure.failedTask, TaskKind.compilingApplication);
    expect(sandbox.disposeCount, 1);
  });

  test('cleanup failure still finishes the blocking preview task', () async {
    sandbox.onRun = () async {
      throw CompilationFailedException('syntax error');
    };
    sandbox.closeError = Exception('close failed');

    await preview.runCode('lib/main.dart');
    await pump();

    expect(preview.state, isA<PreviewCompileError>());
    expect(repository.taskStatus.hasBlockingPreviewTask, isFalse);
    expect(logs.any((event) => event.message == 'Preview cleanup failed'), isTrue);
  });

  test('rejected hot reload leaves the application running', () async {
    await preview.runCode('lib/main.dart');
    sandbox.onReload = () async {
      throw HotReloadRejectedException('restart required');
    };
    await preview.hotReloadCode();
    await pump();
    expect(preview.state, isA<PreviewRunning>());
    expect(logs.any((e) => e.level == Level.WARNING), isTrue);
    expect(sandbox.disposeCount, 0);
  });

  test('console errors and promise rejections preserve error severity', () async {
    await preview.runCode('lib/main.dart', mode: RunMode.console);
    sandbox.consoleController.add('print');
    sandbox.errorController.add('error');
    sandbox.rejectionController.add('rejection');
    expect(preview.appLogs.map((e) => e.level), [Level.INFO, Level.SEVERE, Level.SEVERE]);
    expect(preview.appLogs.every((entry) => entry.source == LogSource.app), isTrue);
    expect(preview.appLogs.every((entry) => entry.isApplicationOutput), isTrue);
  });

  test('Flutter output is dispatched with structured app metadata', () async {
    await preview.runCode('lib/main.dart', mode: RunMode.flutter);

    sandbox.consoleController.add('printed output');
    await pump();

    final output = logs.singleWhere((event) => event.message == 'printed output');
    expect(output.source, LogSource.app);
    expect(output.isApplicationOutput, isTrue);
    expect(output.message, isNot(startsWith('[app]')));
  });

  test('Flutter runtime status retains its app label without output highlighting', () async {
    await preview.runCode('lib/main.dart', mode: RunMode.flutter);

    sandbox.consoleController.add('Starting application from main method in: package:app/main.dart');
    await pump();

    final status = logs.singleWhere((event) => event.message.startsWith('Starting application from'));
    expect(status.source, LogSource.app);
    expect(status.isApplicationOutput, isFalse);
  });

  test('stream errors are captured as severe application output', () async {
    await preview.runCode('lib/main.dart', mode: RunMode.console);

    sandbox.consoleController.addError(StateError('stream failed'));

    expect(preview.appLogs.single.level, Level.SEVERE);
    expect(preview.appLogs.single.message, contains('Console stream failed'));
  });

  test('unsupported sandbox mode is rejected before run', () async {
    sandbox.modes = ['console'];
    await preview.runCode('lib/main.dart');
    expect(sandbox.runCount, 0);
    expect(preview.state, isA<PreviewCompileError>());
  });

  test('stop during pending run closes resources and ignores late completion', () async {
    final pending = Completer<void>();
    sandbox.onRun = () => pending.future;
    final run = preview.runCode('lib/main.dart');
    await pump();
    expect(preview.canStop, isTrue);
    await preview.stopCode();
    pending.complete();
    await run;
    expect(preview.state, isA<PreviewInitial>());
    expect(sandbox.disposeCount, 1);
  });

  test('dispose while creating a sandbox closes the late iframe', () async {
    final pending = Completer<PreviewSandbox>();
    preview.dispose();
    preview = PreviewViewModel(
      initialMode: RunMode.flutter,
      initialEntrypoint: 'lib/main.dart',
      workspaceRepository: repository,
      eventBus: events,
      createSandbox: (_, {required assetBaseUrl}) => pending.future,
    );
    final run = preview.runCode('lib/main.dart');
    await pump();
    preview.dispose();
    pending.complete(sandbox);
    await run;
    expect(sandbox.disposeCount, 1);
    expect(sandbox.runCount, 0);
  });

  test('dispose awaits an in-flight sandbox close', () async {
    await preview.runCode('lib/main.dart');
    final closeStarted = Completer<void>();
    final allowClose = Completer<void>();
    sandbox.onClose = () {
      closeStarted.complete();
      return allowClose.future;
    };

    final stop = preview.stopCode();
    await closeStarted.future;
    preview.dispose();
    var closed = false;
    unawaited(preview.closed.then((_) => closed = true));

    await pump();
    expect(closed, isFalse);
    expect(sandbox.disposeCount, 1);

    allowClose.complete();
    await preview.closed;
    await stop;
    expect(closed, isTrue);
    expect(sandbox.disposeCount, 1);
    expect(preview.state, isA<PreviewStopping>());
  });

  test('concurrent stop callers wait for the complete stop operation', () async {
    await preview.runCode('lib/main.dart');
    final closeStarted = Completer<void>();
    final allowClose = Completer<void>();
    sandbox.onClose = () {
      closeStarted.complete();
      return allowClose.future;
    };

    final firstStop = preview.stopCode();
    await closeStarted.future;
    final secondStop = preview.stopCode();
    var secondCompleted = false;
    unawaited(secondStop.then((_) => secondCompleted = true));

    await pump();
    expect(secondCompleted, isFalse);

    allowClose.complete();
    await Future.wait([firstStop, secondStop]);
    expect(secondCompleted, isTrue);
    expect(preview.state, isA<PreviewInitial>());
    expect(sandbox.disposeCount, 1);
  });

  test('subscription cancellation failure still closes the sandbox', () async {
    final streamController = StreamController<String>.broadcast();
    sandbox.consoleStream = _CancelFailingStream(streamController.stream);
    await preview.runCode('lib/main.dart');

    await preview.stopCode();

    expect(sandbox.disposeCount, 1);
    expect(preview.state, isA<PreviewInitial>());
    expect(logs.any((event) => event.message == 'Preview output subscription cleanup failed'), isTrue);
    await streamController.close();
  });

  test('stop during hot reload cannot revive the old run', () async {
    await preview.runCode('lib/main.dart');
    final pending = Completer<void>();
    sandbox.onReload = () => pending.future;
    final reload = preview.hotReloadCode();
    await pump();
    await preview.stopCode();
    pending.complete();
    await reload;
    expect(preview.state, isA<PreviewInitial>());
    expect(sandbox.disposeCount, 1);
  });
}

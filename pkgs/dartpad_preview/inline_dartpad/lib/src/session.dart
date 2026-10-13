// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:codemirror_dart/codemirror_dart.dart' as cm;
import 'package:dartpad/dartpad.dart';
import 'package:web/web.dart' as web;

import 'options.dart';
import 'pad.dart';

/// A line of output from the program in a pad.
typedef OutputHandler = void Function(String line, {required bool error});

/// What one page holds in the worker: a session with a workspace holding the
/// code of every pad, one language server for all editors, and a sandbox for
/// each pad that has been run recently.
///
/// The workspace folder is laid out as:
///  * `pubspec.yaml`, an empty package so analysis and compilation use the
///    language version of the SDK, and,
///  * [Pad.path], the code of each pad.
final class PadSession {
  /// Client for the session this page has with the worker.
  final DartPad client;

  /// Whether the worker is shared with other pages on this origin.
  ///
  /// When `false`, every page pays for its own worker, so pages should be
  /// conservative about starting anything the user didn't ask for.
  final bool isShared;

  final Workspace workspace;
  final LanguageServer languageServer;
  final cm.CodeMirrorLspClient lsp;
  final DartPadSdk _sdk;

  /// Sandboxes by pad, least recently run first.
  final _sandboxes = <Pad, _PadSandbox>{};

  /// How many sandboxes to keep alive, each one is an `<iframe>` with a Dart
  /// runtime and a compiler in the worker.
  static const _maxSandboxes = 3;

  PadSession._(this.client, this.workspace, this.languageServer, this.lsp, this._sdk, {required this.isShared});

  /// Whether this browser supports `SharedWorker`.
  static bool get isSharedWorkerSupported => web.window.has('SharedWorker');

  /// Connects to the worker, creates a workspace holding the code of [pads]
  /// and starts a language server for it.
  static Future<PadSession> connect(InlineDartPadOptions options, List<Pad> pads) async {
    final sdk = DartPadSdk(assetBaseUrl: options.sdk);
    final isShared = isSharedWorkerSupported;
    final client = isShared ? await sdk.sharedWorker(options.worker) : await sdk.dedicatedWorker();
    try {
      final workspace = await client.createWorkspace();
      final version = await client.version();
      final [major, minor, ...] = version.dartVersion.split('.');
      await workspace.writeFileFromText(
        'pubspec.yaml',
        'name: inline_dartpad\nenvironment:\n  sdk: ^$major.$minor.0-0\n',
      );
      await workspace.pub(command: 'get', args: ['--offline']);
      await Future.wait([for (final pad in pads) workspace.writeFileFromText(pad.path, pad.code)]);

      final languageServer = await workspace.startLanguageServer();
      final lsp = cm.CodeMirrorLspClient(
        (message) => languageServer.languageServerChannel.sink.add(jsonDecode(message)),
        Uri.file(workspace.workspaceFolder).toString(),
        onDisplayFile: (_) async {},
        onWorkspaceEdit: (_) async {},
        language: cm.dartLanguage(),
      );
      languageServer.languageServerChannel.stream.listen((message) => lsp.receiveFromServer(jsonEncode(message)));

      return PadSession._(client, workspace, languageServer, lsp, sdk, isShared: isShared);
    } catch (_) {
      client.close().ignore();
      rethrow;
    }
  }

  /// Completes when the session is gone: closed by this page, closed by the
  /// worker, or the worker went away.
  Future<void> get done => client.done;

  /// CodeMirror extension connecting the editor of [pad] to the language
  /// server.
  JSObject lspExtension(Pad pad) =>
      lsp.createExtension(Uri.file('${workspace.workspaceFolder}/${pad.path}').toString());

  /// Compiles and runs the code in [pad], returning the compiler log.
  ///
  /// The first run of a pad creates a sandboxed `<iframe>` for it inside
  /// [sandboxContainer], later runs hot restart it. Only the sandboxes of the
  /// [_maxSandboxes] most recently run pads are kept, though pads running at
  /// the same time all get one.
  Future<String> run(Pad pad, {required web.Element sandboxContainer, required OutputHandler onOutput}) async {
    await workspace.writeFileFromText(pad.path, pad.code);

    var padSandbox = _sandboxes.remove(pad);
    if (padSandbox == null) {
      for (final MapEntry(key: other, value: sandbox) in _sandboxes.entries.toList()) {
        if (_sandboxes.length < _maxSandboxes) {
          break;
        }
        if (!sandbox.busy) {
          _sandboxes.remove(other);
          sandbox.close().ignore();
        }
      }
      padSandbox = _PadSandbox(_createSandbox(sandboxContainer, onOutput));
    }
    _sandboxes[pad] = padSandbox;

    padSandbox.busy = true;
    try {
      final sandbox = await padSandbox.sandbox;
      if (padSandbox.started) {
        return (await sandbox.hotRestart()).log;
      }
      final result = await sandbox.run(pad.path, mode: 'console');
      padSandbox.started = true;
      return result.log;
    } on CompilationFailedException {
      rethrow;
    } catch (_) {
      if (identical(_sandboxes[pad], padSandbox)) {
        _sandboxes.remove(pad);
        padSandbox.close().ignore();
      }
      rethrow;
    } finally {
      padSandbox.busy = false;
    }
  }

  Future<({SandboxedIframe iframe, Sandbox sandbox})> _createSandbox(
    web.Element sandboxContainer,
    OutputHandler onOutput,
  ) async {
    final iframe = await _sdk.createSandboxedIframe(sandboxContainer);
    try {
      final sandbox = await workspace.connectSandboxedIframe(iframe.port);
      sandbox.console.listen((event) => _handleConsole(event, onOutput));
      return (iframe: iframe, sandbox: sandbox);
    } catch (_) {
      iframe.close().ignore();
      rethrow;
    }
  }

  /// Forwards console output to the pad, except for the lines the DDC embedder
  /// logs whenever it (re)starts the program.
  void _handleConsole(({ConsoleLevel level, String message}) event, OutputHandler onOutput) {
    final message = event.message;
    if (message.startsWith('Starting application from main method') ||
        message.startsWith('Hot restarting application from main method')) {
      return;
    }
    onOutput(message, error: event.level >= ConsoleLevel.warn);
  }

  /// Closes the session, releasing everything held in the worker and
  /// removing the sandboxes.
  Future<void> close() async {
    await lsp.dispose();
    for (final padSandbox in _sandboxes.values) {
      padSandbox.close().ignore();
    }
    _sandboxes.clear();
    await client.close();
  }
}

/// The `<iframe>` and [Sandbox] a pad runs in, from the moment they are
/// requested.
final class _PadSandbox {
  final Future<({SandboxedIframe iframe, Sandbox sandbox})> _created;

  /// Whether a run is in progress, such sandboxes are not evicted.
  bool busy = false;

  /// Whether [Sandbox.run] has succeeded, after which runs hot restart. A
  /// failed compilation leaves the sandbox ready for another [Sandbox.run].
  bool started = false;

  _PadSandbox(this._created);

  Future<Sandbox> get sandbox async => (await _created).sandbox;

  Future<void> close() async {
    final (:iframe, :sandbox) = await _created;
    await iframe.close();
    await sandbox.close();
  }
}

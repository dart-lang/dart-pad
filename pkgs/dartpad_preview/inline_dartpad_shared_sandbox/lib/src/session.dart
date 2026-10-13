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

/// Output from the program in the sandbox, attributed to the pad it came from
/// when the line was tagged.
typedef ConsoleHandler = void Function(Pad? pad, String line, {required bool error});

/// What one page holds in the worker: a session with a workspace holding the
/// code of every pad, one language server for all editors and, once
/// something has run, one sandbox.
///
/// The workspace folder is laid out as:
///  * `pubspec.yaml`, an empty package so analysis and compilation use the
///    language version of the SDK,
///  * [Pad.path], the code of each pad, and,
///  * [entrypoint], rewritten before every run to import and run the pad the
///    user asked for, since a sandbox can only [Sandbox.run] once and is
///    [Sandbox.hotRestart]ed afterwards.
final class PadSession {
  /// Client for the session this page has with the worker.
  final DartPad client;

  /// The pads on the page, output is tagged with their position in this list.
  final List<Pad> pads;

  /// Name of the generated entrypoint, `main.dart` unless a pad took it.
  final String entrypoint;

  /// Whether the worker is shared with other pages on this origin.
  ///
  /// When `false`, every page pays for its own worker, so pages should be
  /// conservative about starting anything the user didn't ask for.
  final bool isShared;

  final Workspace workspace;
  final LanguageServer languageServer;
  final cm.CodeMirrorLspClient lsp;
  final DartPadSdk _sdk;
  final ConsoleHandler _onConsole;

  SandboxedIframe? _iframe;
  Sandbox? _sandbox;

  /// Whether [Sandbox.run] has succeeded, after which runs hot restart. A
  /// failed compilation leaves the sandbox ready for another [Sandbox.run].
  bool _started = false;

  PadSession._(
    this.client,
    this.pads,
    this.workspace,
    this.languageServer,
    this.lsp,
    this._sdk,
    this._onConsole, {
    required this.entrypoint,
    required this.isShared,
  });

  /// Whether this browser supports `SharedWorker`.
  static bool get isSharedWorkerSupported => web.window.has('SharedWorker');

  /// Connects to the worker, creates a workspace holding the code of [pads]
  /// and starts a language server for it, [onConsole] receives output from
  /// programs run later.
  static Future<PadSession> connect(
    InlineDartPadOptions options,
    List<Pad> pads, {
    required ConsoleHandler onConsole,
  }) async {
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

      return PadSession._(
        client,
        pads,
        workspace,
        languageServer,
        lsp,
        sdk,
        onConsole,
        entrypoint: uniqueFilenames([...pads.map((pad) => pad.path), 'main.dart']).last,
        isShared: isShared,
      );
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
  /// The first run creates a sandboxed `<iframe>` inside [sandboxContainer],
  /// later runs hot restart the sandbox with a rewritten [entrypoint].
  Future<String> run(Pad pad, {required web.Element sandboxContainer}) async {
    await Future.wait([
      workspace.writeFileFromText(pad.path, pad.code),
      workspace.writeFileFromText(entrypoint, _entrypointCode(pad)),
    ]);
    if (_started) {
      return (await _sandbox!.hotRestart()).log;
    }
    if (_sandbox == null) {
      final iframe = _iframe ??= await _sdk.createSandboxedIframe(sandboxContainer);
      final sandbox = _sandbox = await workspace.connectSandboxedIframe(iframe.port);
      sandbox.console.listen(_handleConsole);
    }
    final result = await _sandbox!.run(entrypoint, mode: 'console');
    _started = true;
    return result.log;
  }

  /// Output is tagged by the entrypoint with the index of the pad it comes
  /// from, see [_entrypointCode]; anything else is attributed to no pad, except
  /// for the lines the DDC embedder logs whenever it (re)starts the program.
  void _handleConsole(({ConsoleLevel level, String message}) event) {
    final message = event.message;
    final error = event.level >= ConsoleLevel.warn;
    if (message.startsWith('\u0001')) {
      final end = message.indexOf('\u0002');
      final index = end > 0 ? int.tryParse(message.substring(1, end)) : null;
      if (index != null && index < pads.length) {
        _onConsole(pads[index], message.substring(end + 1), error: error);
        return;
      }
    }
    if (message.startsWith('Starting application from main method') ||
        message.startsWith('Hot restarting application from main method')) {
      return;
    }
    _onConsole(null, message, error: error);
  }

  /// The [entrypoint] running `main` from [pad] in a zone that tags everything
  /// printed, and any uncaught error, with the index of the pad.
  String _entrypointCode(Pad pad) =>
      '''
// Generated by inline_dartpad to run `${pad.path}`.
import 'dart:async';

import '${Uri(path: pad.path)}' as pad;

void main() {
  const tag = '\\u0001${pads.indexOf(pad)}\\u0002';
  runZonedGuarded(
    () {
      final Function main = pad.main;
      if (main is void Function(List<String>)) {
        main(const <String>[]);
      } else {
        (main as void Function())();
      }
    },
    (error, _) => Zone.root.print('\${tag}Uncaught error: \$error'),
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => parent.print(zone, '\$tag\$line'),
    ),
  );
}
''';

  /// Closes the session, releasing everything held in the worker and
  /// removing the sandbox.
  Future<void> close() async {
    await lsp.dispose();
    await _iframe?.close();
    await client.close();
  }
}

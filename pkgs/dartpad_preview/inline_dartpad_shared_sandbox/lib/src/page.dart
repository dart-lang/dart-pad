// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';

import 'package:dartpad/dartpad.dart';
import 'package:web/web.dart' as web;

import 'options.dart';
import 'pad.dart';
import 'session.dart';

/// All inline DartPads on a page.
///
/// Per page there is one worker session with one workspace, one language
/// server and one hidden sandbox. Per pad there is an
/// editor and a console. Programs run one at a time: running a pad hot
/// restarts the sandbox with that pad's code.
final class InlineDartPadPage {
  final InlineDartPadOptions options;
  final pads = <Pad>[];

  /// The session being created or in use, `null` when there is none.
  ///
  /// The editors are the only state worth keeping: when the session is lost
  /// it is dropped and the next [_connect] starts over with the code
  /// currently in the editors.
  Future<PadSession>? _session;
  Future<void> _runs = Future.value();
  Pad? _runningPad;
  web.HTMLElement? _sandboxContainer;

  InlineDartPadPage._(this.options);

  /// Upgrades every `<pre data-dartpad-filename="...">` on the page.
  ///
  /// Options are read from the `<script>` element currently executing.
  static Future<void> start() async {
    final script = web.document.currentScript as web.HTMLScriptElement;
    await InlineDartPadPage._(InlineDartPadOptions.fromScript(script))._start();
  }

  Future<void> _start() async {
    final elements = web.document.querySelectorAll('pre[data-dartpad-filename]');
    final specs = [for (var i = 0; i < elements.length; i++) PadSpec.fromElement(elements.item(i) as web.HTMLElement)];
    final paths = uniqueFilenames(specs.map((spec) => spec.filename));

    final autoStart = <Pad>[];
    for (var i = 0; i < specs.length; i++) {
      final spec = specs[i];
      final pad = Pad.mount(paths[i], spec, onRun: spec.preview == PadPreview.none ? null : _run);
      (elements.item(i) as web.Element).replaceWith(pad.element);
      pads.add(pad);
      if (spec.preview == PadPreview.start) {
        autoStart.add(pad);
      }
    }

    // Connect right away so the language server is warm when the user starts
    // typing, and start pads marked for it as they scroll into view. Without
    // a shared worker, running costs a worker per page, so only run on request.
    _connect().ignore();
    if (autoStart.isNotEmpty && PadSession.isSharedWorkerSupported) {
      late final web.IntersectionObserver observer;
      observer = web.IntersectionObserver(
        ((JSArray<web.IntersectionObserverEntry> entries) {
          for (final entry in entries.toDart) {
            if (entry.isIntersecting) {
              observer.unobserve(entry.target);
              _run(pads.firstWhere((pad) => pad.element == entry.target));
            }
          }
        }).toJS,
      );
      for (final pad in autoStart) {
        observer.observe(pad.element);
      }
    }

    // The session closes itself when the page is hidden, pick it up again
    // when the user comes back to a page restored from the back/forward cache
    // or to a page that was frozen in the background long enough for the
    // worker to forget it.
    web.window.addEventListener(
      'pageshow',
      ((web.PageTransitionEvent event) {
        if (event.persisted) {
          _connect().ignore();
        }
      }).toJS,
    );
    web.document.addEventListener(
      'visibilitychange',
      ((web.Event _) {
        if (web.document.visibilityState == 'visible') {
          _connect().ignore();
        }
      }).toJS,
    );
  }

  /// The session for this page, connecting if there is none.
  Future<PadSession> _connect() {
    if (_session case final session?) {
      return session;
    }
    late final Future<PadSession> session;
    session = _session = _createSession(onLost: () => _dropSession(session));
    return session;
  }

  Future<PadSession> _createSession({required void Function() onLost}) async {
    try {
      final session = await PadSession.connect(options, pads, onConsole: _onConsole);
      for (final pad in pads) {
        pad.setLanguageServer(session.lspExtension(pad));
      }
      session.done.whenComplete(() {
        onLost();
        session.close().ignore();
      }).ignore();
      return session;
    } catch (e) {
      web.console.error('Failed to start DartPad: $e'.toJS);
      onLost();
      rethrow;
    }
  }

  void _dropSession(Future<PadSession> session) {
    if (!identical(_session, session)) {
      return;
    }
    _session = null;
    for (final pad in pads) {
      pad.setLanguageServer(null);
    }
  }

  /// Runs [pad] after any run already in progress.
  void _run(Pad pad) {
    _runs = _runs.then((_) => _runNow(pad));
  }

  Future<void> _runNow(Pad pad) async {
    // The compiler names files by their URI in the workspace.
    String clean(String log) => log.trimRight().replaceAll('workspace:///', '');

    pad.clearConsole();
    pad.setStatus(_session == null ? 'Starting DartPad…' : 'Compiling…');
    try {
      final session = await _connect();
      pad.setStatus('Compiling…');
      _runningPad = pad;
      final container = _sandboxContainer ??= _createSandboxContainer();
      final log = await session.run(pad, sandboxContainer: container);
      if (log.trim().isNotEmpty) {
        pad.appendConsole(clean(log), error: true);
      }
    } on DartPadException catch (e) {
      pad.appendConsole(clean(e.message), error: true);
    } catch (e) {
      final lost = _session == null;
      pad.appendConsole(
        lost ? 'Lost the connection to the DartPad worker, run again to reconnect.' : '$e',
        error: true,
      );
    } finally {
      pad.setStatus(null);
    }
  }

  void _onConsole(Pad? pad, String line, {required bool error}) {
    (pad ?? _runningPad)?.appendConsole(line, error: error);
  }

  /// A hidden element, see the stylesheet, to hold the sandboxed `<iframe>`.
  static web.HTMLElement _createSandboxContainer() {
    final container = web.HTMLDivElement()..className = 'inline-dartpad-sandbox';
    web.document.body!.append(container);
    return container;
  }
}

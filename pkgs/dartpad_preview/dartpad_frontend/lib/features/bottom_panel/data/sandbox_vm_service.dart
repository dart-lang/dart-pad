// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:convert';

import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/service/vm_service_wrapper.dart';
import 'package:devtools_app/src/shared/environment_parameters/environment_parameters_base.dart';
import 'package:devtools_app/src/shared/environment_parameters/environment_parameters_external.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/preferences/preferences.dart';
import 'package:devtools_app/src/shared/primitives/storage.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';
import 'package:web/web.dart' as web;

import '../../preview/models/preview_sandbox.dart';
import '../../shared/app_event_bus.dart';
import '../../shared/events/open_file_event.dart';
import '../../shared/events/sandbox_event.dart';

/// A custom [VmServiceWrapper] implementation that routes extension method calls
/// and events directly to the active sandboxed DDC iframe runtime.
class SandboxVmService extends VmServiceWrapper {
  SandboxVmService(this.sandbox, this.eventBus)
    : super(
        StreamController<dynamic>().stream,
        (_) {},
        wsUri: 'ws://sandbox/ws',
      ) {
    _initExtensions();

    _subscription = sandbox.onExtensionEvent.listen((e) {
      if (e.kind == 'ServiceExtensionAdded') {
        final methodStr = e.data['extensionRPC'] as String?;
        if (methodStr != null) {
          _addRegisteredExtension(methodStr);
        }
      } else {
        if (e.kind == 'navigate') {
          var fileUri = e.data['fileUri'] as String?;
          final line = e.data['line'] as int?;
          final column = e.data['column'] as int?;
          if (fileUri != null && line != null && column != null) {
            final workspacePadRegex = RegExp(r'^file:///workspace/pad_\d+/');
            if (workspacePadRegex.hasMatch(fileUri)) {
              fileUri = fileUri.replaceFirst(workspacePadRegex, '');
            }
            eventBus.dispatch(
              OpenFileEvent(
                fileUri,
                line: line - 1,
                column: column - 1,
              ),
            );
          }
        }
        _extensionEventController.add(
          Event.parse({
            'kind': EventKind.kExtension,
            'extensionKind': e.kind,
            'extensionData': e.data,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          })!,
        );
      }
    });

    // Timeout fallback: if no extensions are registered within 5 seconds, we connect anyway
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
    });
  }

  void _addRegisteredExtension(String methodStr) {
    if (_isolateEventController.isClosed) {
      return;
    }
    if (_registeredExtensions.add(methodStr)) {
      // Notify the service manager about the newly registered service extension
      _isolateEventController.add(
        Event.parse({
          'kind': EventKind.kServiceExtensionAdded,
          'extensionRPC': methodStr,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        })!,
      );
    }

    // As soon as the first service extension is registered, the app is ready and we can connect
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
  }

  Future<void> _initExtensions() async {
    try {
      final extensionsJson = await sandbox.invokeExtension('getRegisteredExtensions', {});
      final list = jsonDecode(extensionsJson) as List<dynamic>;
      for (final item in list) {
        if (item is String) {
          _addRegisteredExtension(item);
        }
      }
    } catch (e, st) {
      print('SandboxVmService: failed to fetch registered extensions: $e\n$st');
    }
  }

  final AppEventBus eventBus;
  final PreviewSandbox sandbox;
  late final StreamSubscription<dynamic> _subscription;
  final _extensionEventController = StreamController<Event>.broadcast();
  final _isolateEventController = StreamController<Event>.broadcast();
  final _registeredExtensions = <String>{};
  final _readyCompleter = Completer<void>();

  Future<void> get ready => _readyCompleter.future;

  @override
  Stream<Event> get onExtensionEvent => _extensionEventController.stream;

  @override
  Stream<Event> get onIsolateEvent => _isolateEventController.stream;

  @override
  Future<Version> getVersion() async {
    return Version(major: 4, minor: 0);
  }

  @override
  Future<VM> getVM() async {
    return VM(
      name: 'SandboxVM',
      architectureBits: 64,
      targetCPU: 'x64',
      hostCPU: 'x64',
      version: '1.0.0',
      pid: 1234,
      startTime: DateTime.now().millisecondsSinceEpoch,
      isolates: [
        IsolateRef(
          id: 'sandbox-isolate',
          number: '1',
          name: 'main',
          isSystemIsolate: false,
        ),
      ],
      systemIsolates: [],
    );
  }

  @override
  Future<Isolate> getIsolate(String isolateId) async {
    return Isolate(
      id: 'sandbox-isolate',
      number: '1',
      name: 'main',
      isSystemIsolate: false,
      runnable: true,
      startTime: DateTime.now().millisecondsSinceEpoch,
      livePorts: 0,
      pauseOnExit: false,
      pauseEvent: Event(
        kind: EventKind.kResume,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
      libraries: [
        LibraryRef(
          id: 'package:flutter/src/widgets/framework.dart',
          name: 'flutter_framework',
          uri: 'package:flutter/src/widgets/framework.dart',
        ),
        LibraryRef(
          id: 'package:flutter/src/widgets/binding.dart',
          name: 'flutter_binding',
          uri: 'package:flutter/src/widgets/binding.dart',
        ),
        LibraryRef(
          id: 'package:flutter/src/widgets/widget_inspector.dart',
          name: 'flutter_widget_inspector',
          uri: 'package:flutter/src/widgets/widget_inspector.dart',
        ),
        LibraryRef(
          id: 'package:flutter',
          name: 'flutter',
          uri: 'package:flutter/material.dart',
        ),
        LibraryRef(
          id: 'dart:html',
          name: 'html',
          uri: 'dart:html',
        ),
        LibraryRef(
          id: 'dart:io',
          name: 'io',
          uri: 'dart:io',
        ),
      ],
      breakpoints: [],
      error: null,
      extensionRPCs: _registeredExtensions.toList(),
    );
  }

  @override
  Future<Success> streamListen(String streamId) async {
    return Success();
  }

  @override
  Future<Success> streamCancel(String streamId) async {
    return Success();
  }

  @override
  Future<Response> evaluate(
    String isolateId,
    String targetId,
    String expression, {
    Map<String, String>? scope,
    bool? disableBreakpoints,
    String? idZoneId,
  }) async {
    if (expression == 'Platform.isAndroid') {
      return InstanceRef(
        id: 'mock-bool-ref',
        kind: InstanceKind.kBool,
        valueAsString: 'false',
      );
    }
    return InstanceRef(
      id: 'mock-ref',
      kind: InstanceKind.kNull,
      valueAsString: 'null',
    );
  }

  @override
  Future<Response> invoke(
    String isolateId,
    String targetId,
    String selector,
    List<String> argumentIds, {
    bool? disableBreakpoints,
    String? idZoneId,
  }) async {
    return InstanceRef(
      id: 'mock-ref',
      kind: InstanceKind.kNull,
      valueAsString: 'null',
    );
  }

  @override
  Future<Response> callMethod(
    String method, {
    String? isolateId,
    Map<String, dynamic>? args,
  }) async {
    if (method == 'setFlag') {
      return Success();
    }
    if (method == 'requirePermissionToResume') {
      return Success();
    }
    if (method == 'flutterVersion') {
      return Response()
        ..json = {
          'frameworkRevision': 'unknown',
          'engineRevision': 'unknown',
          'dartSdkVersion': '1.0.0',
        };
    }

    if (method.startsWith('ext.')) {
      final stringArgs = <String, String>{};
      if (args != null) {
        args.forEach((key, value) {
          stringArgs[key] = value.toString();
        });
      }

      try {
        final resultJsonStr = await sandbox.invokeExtension(method, stringArgs);
        final decoded = jsonDecode(resultJsonStr) as Map<String, dynamic>;
        return Response()..json = decoded;
      } catch (e) {
        throw RPCError(
          method,
          -32603, // Internal error
          e.toString(),
        );
      }
    }

    // Default fallback to prevent hanging on unhandled methods
    return Success();
  }

  @override
  Future<Response> callServiceExtension(
    String method, {
    String? isolateId,
    Map<String, dynamic>? args,
  }) async {
    return callMethod(method, isolateId: isolateId, args: args);
  }

  @override
  Future<Success> setFlag(String name, String value) async {
    return Success();
  }

  @override
  Future<FlagList> getFlagList() async {
    return FlagList(flags: []);
  }

  @override
  Future<ProtocolList> getSupportedProtocols() async {
    return ProtocolList(protocols: []);
  }

  @override
  Future<void> dispose() async {
    await _subscription.cancel();
    await _extensionEventController.close();
    await _isolateEventController.close();
    await super.dispose();
  }
}

class BrowserStorage implements Storage {
  @override
  Future<String?> getValue(String key) async {
    return web.window.localStorage.getItem(key);
  }

  @override
  Future<void> setValue(String key, String value) async {
    web.window.localStorage.setItem(key, value);
  }
}

/// Manages bridging the current active [PreviewSandbox] to [serviceConnection].
class SandboxVmServiceManager {
  SandboxVmServiceManager(this.events) {
    _initGlobals();
    serviceConnection.serviceManager.registerLifecycleCallback(
      ServiceManagerLifecycle.beforeOpenVmService,
      (service) async {
        Future.delayed(const Duration(milliseconds: 100), () {
          final manager = serviceConnection.serviceManager;
          manager.registeredMethodsForService['flutterVersion'] = 'flutterVersion';
          final listenable = manager.registeredServiceListenable('flutterVersion');
          if (listenable is ValueNotifier<bool>) {
            listenable.value = false;
            listenable.value = true;
          }
        });
      },
    );
    _sandboxSubscription = events.on<SandboxChangedEvent>().listen(_onSandboxChanged, onDone: _disconnect);
    events.dispatchAsync(RequestSandboxEvent()).then(_onSandboxChanged);
  }

  final AppEventBus events;

  StreamSubscription<SandboxChangedEvent>? _sandboxSubscription;

  SandboxVmService? _currentService;
  Completer<void>? _onClosedCompleter;

  void _initGlobals() {
    if (globals[ServiceConnectionManager] == null) {
      setGlobal(ServiceConnectionManager, ServiceConnectionManager());
    }
    if (globals[IdeTheme] == null) {
      setGlobal(IdeTheme, getIdeTheme());
    }
    if (globals[DevToolsEnvironmentParameters] == null) {
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
    }
    if (globals[DTDManager] == null) {
      setGlobal(DTDManager, DTDManager());
    }
    if (globals[PreferencesController] == null) {
      setGlobal(PreferencesController, PreferencesController());
    }
    if (globals[Storage] == null) {
      setGlobal(Storage, BrowserStorage());
    }
  }

  void _onSandboxChanged(SandboxChangedEvent event) {
    final sandbox = event.sandbox;

    if (sandbox == null) {
      _disconnect();
      return;
    }

    if (!event.isFlutterApp) {
      _disconnect();
      return;
    }

    if (_currentService?.sandbox == sandbox) {
      return;
    }

    _connect(sandbox);
  }

  void _connect(PreviewSandbox sandbox) {
    _disconnect();

    _onClosedCompleter = Completer<void>();

    final service = SandboxVmService(sandbox, events);
    _currentService = service;

    unawaited(
      (() async {
        try {
          await service.ready;

          if (_currentService != service) {
            return null;
          }
          await serviceConnection.serviceManager.vmServiceOpened(
            service,
            onClosed: _onClosedCompleter!.future,
          );
        } catch (e, st) {
          print('SandboxVmServiceManager: vmServiceOpened failed with error: $e\n$st');
        }
      })(),
    );
  }

  void _disconnect() {
    final completer = _onClosedCompleter;
    _onClosedCompleter = null;
    _currentService?.dispose();
    _currentService = null;
    completer?.complete();
  }

  void dispose() {
    _sandboxSubscription?.cancel();
    _disconnect();
  }
}

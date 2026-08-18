// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service_interface/vm_service_interface.dart';

import '../../preview/view_models/preview_view_model.dart';
import '../../shared/events/open_file_event.dart';

/// A custom [Response] wrapper that preserves raw JSON result maps from
/// sandbox service extensions when serialized by [VmServerConnection].
final class ExtensionResponse extends Response {
  ExtensionResponse(this._result);

  final Map<String, dynamic> _result;

  @override
  Map<String, dynamic> toJson() => _result;
}

/// Bridges VM Service JSON-RPC requests from DevTools to the preview sandbox
/// and implements [VmServiceInterface] via [VmServerConnection].
///
/// The methods on this class are organized into three tiers of implementation:
/// 1. **Active Functionality**: Methods that provide real bridging behavior
///    between DevTools, the preview sandbox, and the workspace repository (e.g.,
///    service extension invocation, event stream subscriptions, and workspace/package
///    URI resolution).
/// 2. **Mocked / Stubbed Methods**: Methods that return valid mock metadata, static
///    structures, or safe no-ops required by DevTools during initialization and
///    inspection (e.g., VM and isolate metadata, protocol versions, flags, and empty
///    source reports).
/// 3. **Unsupported Methods**: Methods representing native VM debugging and profiling
///    features (e.g., breakpoints, isolate pause/resume control, expression evaluation,
///    heap snapshots, and timeline profiling) that are not available in the browser
///    sandbox and throw [UnsupportedError].
class VmServiceBridge implements VmServiceInterface {
  VmServiceBridge({required this.previewViewModel}) {
    _connection = VmServerConnection(
      _requestController.stream,
      _responseController.sink,
      _registry,
      this,
    );
    _responseController.stream.listen((responseMap) {
      final json = jsonEncode(responseMap);
      _sendCallback?.call(json);
      final id = responseMap['id'];
      if (id != null) {
        _pendingResponses.remove(id)?.complete();
      }
    });
    _initExtensionSubscription();
    previewViewModel.addListener(_onPreviewChanged);
  }

  final PreviewViewModel previewViewModel;

  final _requestController = StreamController<Map<String, Object>>.broadcast();
  final _responseController = StreamController<Map<String, Object?>>.broadcast();
  final _registry = ServiceExtensionRegistry();
  final _pendingResponses = <dynamic, Completer<void>>{};
  // ignore: unused_field
  late final VmServerConnection _connection;

  final _eventControllers = <String, StreamController<Event>>{};
  StreamSubscription<dynamic>? _extensionEventSub;
  void Function(String message)? _sendCallback;

  // ===========================================================================
  // SECTION 1: Active Functionality & Lifecycle
  // ===========================================================================

  void attachSender(void Function(String message) sendCallback) {
    _sendCallback = sendCallback;
  }

  /// Handles an incoming JSON-RPC message from DevTools and routes it through
  /// [VmServerConnection] or handles non-standard custom methods.
  Future<void> handleMessage(dynamic rawMessage, void Function(String response) sendResponse) async {
    _sendCallback = sendResponse;

    final String messageStr;
    if (rawMessage is String) {
      messageStr = rawMessage;
    } else {
      messageStr = rawMessage.toString();
    }

    final Map<String, dynamic> request;
    try {
      request = jsonDecode(messageStr) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final id = request['id'];
    final method = request['method'] as String?;

    if (method == null) {
      return;
    }

    // Handle non-standard / custom methods outside the VmServiceInterface contract.
    if (method == '_flutter.listViews' || method == 'flutterListViews') {
      if (id != null) {
        sendResponse(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': id,
            'result': {
              'type': 'FlutterViewList',
              'views': [
                {
                  'type': 'FlutterView',
                  'id': '_flutterView/main',
                  'isolate': {
                    'type': '@Isolate',
                    'id': 'isolates/main',
                    'name': 'main',
                    'number': '1',
                  },
                },
              ],
            },
          }),
        );
      }
      return;
    }

    if (method == 'yieldControlToEnableDevTools') {
      if (id != null) {
        sendResponse(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': id,
            'result': {'type': 'Success'},
          }),
        );
      }
      return;
    }

    if (method == 'hotReload') {
      await previewViewModel.hotReloadCode();
      if (id != null) {
        sendResponse(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': id,
            'result': {'type': 'Success'},
          }),
        );
      }
      return;
    }

    if (method == 'hotRestart') {
      final entrypoint = previewViewModel.state.entrypoint;
      if (entrypoint != null) {
        await previewViewModel.runCode(entrypoint, skipRecompilation: true);
      }
      if (id != null) {
        sendResponse(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': id,
            'result': {'type': 'Success'},
          }),
        );
      }
      return;
    }

    Completer<void>? completer;
    if (id != null) {
      completer = Completer<void>();
      _pendingResponses[id] = completer;
    }

    _requestController.add(request.cast<String, Object>());

    if (completer != null) {
      await completer.future;
    }
  }

  @override
  Stream<Event> onEvent(String streamId) {
    return _eventControllers.putIfAbsent(streamId, StreamController<Event>.broadcast).stream;
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
  Future<Response> callServiceExtension(
    String method, {
    String? isolateId,
    Map<String, dynamic>? args,
  }) async {
    final sandbox = previewViewModel.sandbox;
    if (sandbox == null) {
      return Success();
    }

    final stringArgs = <String, String>{};
    if (args != null) {
      for (final entry in args.entries) {
        if (entry.key == 'isolateId') {
          continue;
        }
        final val = entry.value;
        stringArgs[entry.key] = val is String ? val : jsonEncode(val);
      }
    }

    try {
      final rawResult = await sandbox.invokeExtension(method, stringArgs);
      final decoded = jsonDecode(rawResult);
      if (decoded is Map<String, dynamic>) {
        final inner = decoded['result'];
        if (inner is String) {
          try {
            decoded['result'] = jsonDecode(inner);
          } catch (_) {}
        }
        return ExtensionResponse(decoded);
      } else if (decoded is Map) {
        return ExtensionResponse(Map<String, dynamic>.from(decoded));
      }
      return Success();
    } catch (_) {
      return Success();
    }
  }

  @override
  Future<UriList> lookupPackageUris(String isolateId, List<String> uris) async {
    final wsFolder = await previewViewModel.workspaceRepository.workspaceFolder;
    final mappings = await previewViewModel.workspaceRepository.getPackageMappings();
    final resolved = <String?>[];

    for (final uriStr in uris) {
      final parsed = Uri.tryParse(uriStr);
      if (parsed == null) {
        resolved.add(null);
        continue;
      }
      final fileUri = (parsed.scheme.isEmpty) ? wsFolder.resolve(parsed.path) : parsed;

      String? matched;
      for (final mapping in mappings) {
        final libPath = mapping.packageUriRoot.path;
        if (fileUri.scheme == mapping.packageUriRoot.scheme &&
            fileUri.authority == mapping.packageUriRoot.authority &&
            fileUri.path.startsWith(libPath)) {
          final rel = fileUri.path.substring(libPath.length);
          matched = 'package:${mapping.name}/$rel';
          break;
        }
      }
      resolved.add(matched);
    }
    return UriList(uris: resolved);
  }

  @override
  Future<UriList> lookupResolvedPackageUris(
    String isolateId,
    List<String> uris, {
    bool? local,
  }) async {
    final mappings = await previewViewModel.workspaceRepository.getPackageMappings();
    final resolved = <String?>[];

    for (final uriStr in uris) {
      final parsed = Uri.tryParse(uriStr);
      if (parsed == null) {
        resolved.add(null);
        continue;
      }
      if (parsed.scheme == 'package') {
        final segments = parsed.pathSegments;
        if (segments.length > 1) {
          final pkgName = segments.first;
          final relativePath = segments.sublist(1).join('/');
          final mapping = mappings.where((m) => m.name == pkgName).firstOrNull;
          if (mapping != null) {
            resolved.add(mapping.packageUriRoot.resolve(relativePath).toString());
          } else {
            resolved.add(null);
          }
        } else {
          resolved.add(null);
        }
      } else if (parsed.scheme == 'file' || parsed.scheme.isEmpty) {
        resolved.add(uriStr);
      } else {
        resolved.add(uriStr);
      }
    }
    return UriList(uris: resolved);
  }

  void dispose() {
    _extensionEventSub?.cancel();
    _extensionEventSub = null;
    previewViewModel.removeListener(_onPreviewChanged);
    for (final controller in _eventControllers.values) {
      controller.close();
    }
    _eventControllers.clear();
    _requestController.close();
    _responseController.close();
  }

  void _onPreviewChanged() {
    _initExtensionSubscription();
  }

  void _initExtensionSubscription() {
    _extensionEventSub?.cancel();
    final sandbox = previewViewModel.sandbox;
    if (sandbox != null) {
      _extensionEventSub = sandbox.onExtensionEvent.listen(_handleExtensionEvent);
    }
  }

  void _handleExtensionEvent(({String kind, Map<String, Object?> data}) event) async {
    if (event.kind == 'navigate') {
      final fileUri = event.data['fileUri'] as String?;
      if (fileUri != null) {
        final wsFolder = await previewViewModel.workspaceRepository.workspaceFolder;
        final path = _resolveWorkspacePath(fileUri, wsFolder) ?? fileUri;
        final line = (event.data['line'] as num?)?.toInt();
        final column = (event.data['column'] as num?)?.toInt();
        previewViewModel.eventBus.dispatch(
          OpenFileEvent(path, line: line, column: column),
        );
      }
    }

    final controller = _eventControllers['Extension'];
    if (controller != null && controller.hasListener) {
      controller.add(
        Event(
          kind: EventKind.kExtension,
          extensionKind: event.kind,
          extensionData: ExtensionData.parse(event.data),
          timestamp: DateTime.now().millisecondsSinceEpoch,
          isolate: IsolateRef(
            id: 'isolates/main',
            name: 'main',
            number: '1',
            isSystemIsolate: false,
          ),
        ),
      );
    }
  }

  static String? _resolveWorkspacePath(String fileUri, Uri wsFolder) {
    final parsed = Uri.tryParse(fileUri);
    if (parsed == null) {
      return null;
    }
    final wsPath = wsFolder.path.endsWith('/') ? wsFolder.path : '${wsFolder.path}/';
    final isSameLocation =
        (parsed.scheme.isEmpty || parsed.scheme == wsFolder.scheme) &&
        (parsed.authority.isEmpty || parsed.authority == wsFolder.authority);
    if (isSameLocation && parsed.path.startsWith(wsPath)) {
      final relativePath = parsed.path.substring(wsPath.length);
      return workspaceContext.normalize(Uri.decodeFull(relativePath));
    }
    if (parsed.scheme.isEmpty && !parsed.path.startsWith('/')) {
      return workspaceContext.normalize(parsed.path);
    }
    return null;
  }

  String? _getResolvedEntrypoint() {
    final entry = previewViewModel.packageUri?.toString() ?? previewViewModel.state.entrypoint;
    return entry;
  }

  Isolate _buildIsolate() {
    final entrypoint = _getResolvedEntrypoint();
    return Isolate(
      id: 'isolates/main',
      name: 'main',
      number: '1',
      startTime: 0,
      livePorts: 1,
      pauseOnExit: false,
      pauseEvent: Event(
        kind: EventKind.kResume,
        timestamp: 0,
      ),
      rootLib: LibraryRef(
        id: 'libraries/main',
        name: 'main',
        uri: entrypoint,
      ),
      libraries: [
        LibraryRef(
          id: 'libraries/main',
          name: 'main',
          uri: entrypoint,
        ),
        LibraryRef(
          id: 'libraries/flutter_material',
          name: 'material',
          uri: 'package:flutter/material.dart',
        ),
        LibraryRef(
          id: 'libraries/flutter_widgets',
          name: 'widgets',
          uri: 'package:flutter/widgets.dart',
        ),
        LibraryRef(
          id: 'libraries/flutter_binding',
          name: 'binding',
          uri: 'package:flutter/src/widgets/binding.dart',
        ),
        LibraryRef(
          id: 'libraries/flutter_inspector',
          name: 'widget_inspector',
          uri: 'package:flutter/src/widgets/widget_inspector.dart',
        ),
        LibraryRef(
          id: 'libraries/flutter_framework',
          name: 'framework',
          uri: 'package:flutter/src/widgets/framework.dart',
        ),
        LibraryRef(
          id: 'libraries/flutter_foundation',
          name: 'foundation',
          uri: 'package:flutter/foundation.dart',
        ),
        LibraryRef(
          id: 'libraries/flutter_rendering',
          name: 'rendering',
          uri: 'package:flutter/rendering.dart',
        ),
        LibraryRef(
          id: 'libraries/dart_html',
          name: 'html',
          uri: 'dart:html',
        ),
        LibraryRef(
          id: 'libraries/dart_core',
          name: 'core',
          uri: 'dart:core',
        ),
        LibraryRef(
          id: 'libraries/dart_developer',
          name: 'developer',
          uri: 'dart:developer',
        ),
      ],
      runnable: true,
      isSystemIsolate: false,
      extensionRPCs: [
        // TODO: Retrieve this list from the sandbox once this is merged and published:
        // https://dart-review.googlesource.com/c/sdk/+/535941
        'ext.flutter.inspector.setPubRootDirectories',
        'ext.flutter.inspector.addPubRootDirectories',
        'ext.flutter.inspector.removePubRootDirectories',
        'ext.flutter.inspector.getPubRootDirectories',
        'ext.flutter.inspector.getRootWidget',
        'ext.flutter.inspector.getRootWidgetTree',
        'ext.flutter.inspector.getRootWidgetSummaryTree',
        'ext.flutter.inspector.getRootRenderObject',
        'ext.flutter.inspector.getDetailsSubtree',
        'ext.flutter.inspector.getChildren',
        'ext.flutter.inspector.getChildrenSummaryTree',
        'ext.flutter.inspector.getChildrenDetailsSubtree',
        'ext.flutter.inspector.getProperties',
        'ext.flutter.inspector.getSelectedWidget',
        'ext.flutter.inspector.getSelectedSummaryWidget',
        'ext.flutter.inspector.setSelectionById',
        'ext.flutter.inspector.isWidgetTreeReady',
        'ext.flutter.inspector.isWidgetCreationTracked',
        'ext.flutter.inspector.disposeAllGroups',
        'ext.flutter.inspector.disposeGroup',
        'ext.flutter.inspector.trackRebuildDirtyWidgets',
        'ext.flutter.inspector.trackRepaintWidgets',
        'ext.flutter.inspector.structuredErrors',
        'ext.flutter.inspector.show',
        'ext.flutter.inspector.screenshot',
        'ext.flutter.inspector.widgetLocationIdMap',
        'ext.flutter.inspector.getLayoutExplorerNode',
        'ext.flutter.inspector.setFlexFit',
        'ext.flutter.inspector.setFlexFactor',
        'ext.flutter.inspector.setFlexProperties',
        'ext.flutter.inspector.getParentChain',
        'ext.flutter.inspector.disposeId',
        'ext.flutter.inspector.getRootWidgetSummaryTreeWithPreviews',
        'ext.flutter.activeDevToolsServerAddress',
        'ext.flutter.connectedVmServiceUri',
        'ext.flutter.platformOverride',
        'ext.flutter.debugPaint',
        'ext.flutter.debugPaintBaselinesEnabled',
        'ext.flutter.repaintRainbow',
        'ext.flutter.showPerformanceOverlay',
        'ext.flutter.showMaterialGrid',
        'ext.flutter.profileWidgetBuilds',
        'ext.flutter.profileUserWidgetBuilds',
        'ext.flutter.reassemble',
      ],
    );
  }

  // ===========================================================================
  // SECTION 2: Mocked / Stubbed Methods (Valid Result or Safe Stubs)
  // ===========================================================================

  @override
  Future<ProtocolList> getSupportedProtocols() async {
    return ProtocolList(
      protocols: [
        Protocol(
          protocolName: 'VM Service',
          major: 3,
          minor: 69,
        ),
      ],
    );
  }

  @override
  Future<Version> getVersion() async {
    return Version(major: 3, minor: 69);
  }

  @override
  Future<VM> getVM() async {
    return VM(
      name: 'ChromeDebugProxy',
      architectureBits: 64,
      targetCPU: 'wasm',
      hostCPU: 'wasm',
      version: '3.12.0',
      operatingSystem: 'macos',
      pid: 1234,
      startTime: 0,
      isolates: [
        IsolateRef(
          id: 'isolates/main',
          name: 'main',
          number: '1',
          isSystemIsolate: false,
        ),
      ],
      systemIsolates: [],
    );
  }

  @override
  Future<Isolate> getIsolate(String isolateId) async {
    return _buildIsolate();
  }

  @override
  Future<IsolateGroup> getIsolateGroup(String isolateGroupId) async {
    return IsolateGroup(
      id: 'isolateGroups/main',
      name: 'main',
      number: '1',
      isSystemIsolateGroup: false,
      isolates: [
        IsolateRef(
          id: 'isolates/main',
          name: 'main',
          number: '1',
          isSystemIsolate: false,
        ),
      ],
    );
  }

  @override
  Future<Obj> getObject(
    String isolateId,
    String objectId, {
    int? offset,
    int? count,
    String? idZoneId,
  }) async {
    final entrypoint = _getResolvedEntrypoint();
    if (objectId.startsWith('scripts/')) {
      return Script(
        id: objectId,
        uri: entrypoint,
        source: '',
      );
    }
    return Obj(id: objectId);
  }

  @override
  Future<ScriptList> getScripts(String isolateId) async {
    return ScriptList(
      scripts: [
        ScriptRef(
          id: 'scripts/main',
          uri: _getResolvedEntrypoint(),
        ),
      ],
    );
  }

  @override
  Future<SourceReport> getSourceReport(
    String isolateId,
    List<String> reports, {
    String? scriptId,
    int? tokenPos,
    int? endTokenPos,
    bool? forceCompile,
    bool? reportLines,
    List<String>? libraryFilters,
    List<String>? librariesAlreadyCompiled,
  }) async {
    return SourceReport(ranges: [], scripts: []);
  }

  @override
  Future<MemoryUsage> getMemoryUsage(String isolateId) async {
    return MemoryUsage(
      heapUsage: 10000000,
      heapCapacity: 20000000,
      externalUsage: 0,
    );
  }

  @override
  Future<FlagList> getFlagList() async {
    return FlagList(flags: []);
  }

  @override
  Future<TimelineFlags> getVMTimelineFlags() async {
    return TimelineFlags(
      recordedStreams: [],
      availableStreams: [],
    );
  }

  @override
  Future<Success> setVMTimelineFlags(List<String> recordedStreams) async {
    return Success();
  }

  @override
  Future<Response> setFlag(String name, String value) async {
    return Success();
  }

  // ===========================================================================
  // SECTION 3: Unsupported Methods
  // ===========================================================================

  @override
  Future<Breakpoint> addBreakpoint(
    String isolateId,
    String scriptId,
    int line, {
    int? column,
  }) {
    throw UnsupportedError('addBreakpoint is not supported');
  }

  @override
  Future<Breakpoint> addBreakpointAtEntry(String isolateId, String functionId) {
    throw UnsupportedError('addBreakpointAtEntry is not supported');
  }

  @override
  Future<Breakpoint> addBreakpointWithScriptUri(
    String isolateId,
    String scriptUri,
    int line, {
    int? column,
  }) {
    throw UnsupportedError('addBreakpointWithScriptUri is not supported');
  }

  @override
  Future<Success> clearCpuSamples(String isolateId) {
    throw UnsupportedError('clearCpuSamples is not supported');
  }

  @override
  Future<Success> clearVMTimeline() {
    throw UnsupportedError('clearVMTimeline is not supported');
  }

  @override
  Future<IdZone> createIdZone(
    String isolateId,
    String backingBufferKind,
    String idAssignmentPolicy, {
    int? capacity,
  }) {
    throw UnsupportedError('createIdZone is not supported');
  }

  @override
  Future<Success> deleteIdZone(String isolateId, String idZoneId) {
    throw UnsupportedError('deleteIdZone is not supported');
  }

  @override
  Future<Response> evaluate(
    String isolateId,
    String targetId,
    String expression, {
    Map<String, String>? scope,
    bool? disableBreakpoints,
    String? idZoneId,
  }) {
    throw UnsupportedError('evaluate is not supported');
  }

  @override
  Future<Response> evaluateInFrame(
    String isolateId,
    int frameIndex,
    String expression, {
    Map<String, String>? scope,
    bool? disableBreakpoints,
    String? idZoneId,
  }) {
    throw UnsupportedError('evaluateInFrame is not supported');
  }

  @override
  Future<AllocationProfile> getAllocationProfile(
    String isolateId, {
    bool? reset,
    bool? gc,
  }) {
    throw UnsupportedError('getAllocationProfile is not supported');
  }

  @override
  Future<CpuSamples> getAllocationTraces(
    String isolateId, {
    int? timeOriginMicros,
    int? timeExtentMicros,
    String? classId,
  }) {
    throw UnsupportedError('getAllocationTraces is not supported');
  }

  @override
  Future<ClassList> getClassList(String isolateId) {
    throw UnsupportedError('getClassList is not supported');
  }

  @override
  Future<CpuSamples> getCpuSamples(
    String isolateId,
    int timeOriginMicros,
    int timeExtentMicros,
  ) {
    throw UnsupportedError('getCpuSamples is not supported');
  }

  @override
  Future<InboundReferences> getInboundReferences(
    String isolateId,
    String targetId,
    int limit, {
    String? idZoneId,
  }) {
    throw UnsupportedError('getInboundReferences is not supported');
  }

  @override
  Future<InstanceSet> getInstances(
    String isolateId,
    String objectId,
    int limit, {
    bool? includeSubclasses,
    bool? includeImplementers,
    String? idZoneId,
  }) {
    throw UnsupportedError('getInstances is not supported');
  }

  @override
  Future<InstanceRef> getInstancesAsList(
    String isolateId,
    String objectId, {
    bool? includeSubclasses,
    bool? includeImplementers,
    String? idZoneId,
  }) {
    throw UnsupportedError('getInstancesAsList is not supported');
  }

  @override
  Future<MemoryUsage> getIsolateGroupMemoryUsage(String isolateGroupId) {
    throw UnsupportedError('getIsolateGroupMemoryUsage is not supported');
  }

  @override
  Future<Event> getIsolatePauseEvent(String isolateId) {
    throw UnsupportedError('getIsolatePauseEvent is not supported');
  }

  @override
  Future<PerfettoCpuSamples> getPerfettoCpuSamples(
    String isolateId, {
    int? timeOriginMicros,
    int? timeExtentMicros,
  }) {
    throw UnsupportedError('getPerfettoCpuSamples is not supported');
  }

  @override
  Future<PerfettoTimeline> getPerfettoVMTimeline({
    int? timeOriginMicros,
    int? timeExtentMicros,
  }) {
    throw UnsupportedError('getPerfettoVMTimeline is not supported');
  }

  @override
  Future<PortList> getPorts(String isolateId) {
    throw UnsupportedError('getPorts is not supported');
  }

  @override
  Future<ProcessMemoryUsage> getProcessMemoryUsage() {
    throw UnsupportedError('getProcessMemoryUsage is not supported');
  }

  @override
  Future<RetainingPath> getRetainingPath(
    String isolateId,
    String targetId,
    int limit, {
    String? idZoneId,
  }) {
    throw UnsupportedError('getRetainingPath is not supported');
  }

  @override
  Future<Stack> getStack(
    String isolateId, {
    int? limit,
    String? idZoneId,
  }) {
    throw UnsupportedError('getStack is not supported');
  }

  @override
  Future<Timeline> getVMTimeline({
    int? timeOriginMicros,
    int? timeExtentMicros,
  }) {
    throw UnsupportedError('getVMTimeline is not supported');
  }

  @override
  Future<Timestamp> getVMTimelineMicros() {
    throw UnsupportedError('getVMTimelineMicros is not supported');
  }

  @override
  Future<Success> invalidateIdZone(String isolateId, String idZoneId) {
    throw UnsupportedError('invalidateIdZone is not supported');
  }

  @override
  Future<Response> invoke(
    String isolateId,
    String targetId,
    String selector,
    List<String> argumentIds, {
    bool? disableBreakpoints,
    String? idZoneId,
  }) {
    throw UnsupportedError('invoke is not supported');
  }

  @override
  Future<Success> kill(String isolateId) {
    throw UnsupportedError('kill is not supported');
  }

  @override
  Future<Success> pause(String isolateId) {
    throw UnsupportedError('pause is not supported');
  }

  @override
  Future<Success> registerService(String service, String alias) {
    throw UnsupportedError('registerService is not supported');
  }

  @override
  Future<ReloadReport> reloadSources(
    String isolateId, {
    bool? force,
    bool? pause,
    String? rootLibUri,
    String? packagesUri,
  }) {
    throw UnsupportedError('reloadSources is not supported');
  }

  @override
  Future<Success> removeBreakpoint(String isolateId, String breakpointId) {
    throw UnsupportedError('removeBreakpoint is not supported');
  }

  @override
  Future<Success> requestHeapSnapshot(String isolateId) {
    throw UnsupportedError('requestHeapSnapshot is not supported');
  }

  @override
  Future<Success> resume(String isolateId, {String? step, int? frameIndex}) {
    throw UnsupportedError('resume is not supported');
  }

  @override
  Future<Breakpoint> setBreakpointState(
    String isolateId,
    String breakpointId,
    bool enable,
  ) {
    throw UnsupportedError('setBreakpointState is not supported');
  }

  @override
  Future<Success> setExceptionPauseMode(String isolateId, String mode) {
    throw UnsupportedError('setExceptionPauseMode is not supported');
  }

  @override
  Future<Success> setIsolatePauseMode(
    String isolateId, {
    String? exceptionPauseMode,
    bool? shouldPauseOnExit,
  }) {
    throw UnsupportedError('setIsolatePauseMode is not supported');
  }

  @override
  Future<Success> setLibraryDebuggable(String isolateId, String libraryId, bool isDebuggable) {
    throw UnsupportedError('setLibraryDebuggable is not supported');
  }

  @override
  Future<Success> setName(String isolateId, String name) {
    throw UnsupportedError('setName is not supported');
  }

  @override
  Future<Success> setTraceClassAllocation(String isolateId, String classId, bool enable) {
    throw UnsupportedError('setTraceClassAllocation is not supported');
  }

  @override
  Future<Success> setVMName(String name) {
    throw UnsupportedError('setVMName is not supported');
  }

  @override
  Future<Success> streamCpuSamplesWithUserTag(List<String> userTags) {
    throw UnsupportedError('streamCpuSamplesWithUserTag is not supported');
  }

  @override
  Future<void> yieldControlToDDS(String uri) {
    throw UnsupportedError('yieldControlToDDS is not supported');
  }
}

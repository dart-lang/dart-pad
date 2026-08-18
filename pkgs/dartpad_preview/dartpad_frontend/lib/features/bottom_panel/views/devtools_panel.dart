// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../preview/view_models/preview_view_model.dart';
import '../services/vm_service_bridge.dart';

/// The DevTools bottom panel tab content embedding Flutter DevTools in an iframe.
class DevToolsPanel extends StatefulComponent {
  const DevToolsPanel({
    this.iframeUrl,
    this.previewViewModel,
    this.vmServiceBridge,
    this.onMessage,
    super.key,
  });

  /// Optional base URL for the DevTools iframe. If null, a theme-adaptive default URL is used.
  final String? iframeUrl;

  /// Optional preview view model to communicate with the running sandbox.
  final PreviewViewModel? previewViewModel;

  /// Optional VM Service bridge handling DevTools JSON-RPC communication.
  final VmServiceBridge? vmServiceBridge;

  /// Callback when a message is received from DevTools through the shared MessagePort.
  final void Function(dynamic data)? onMessage;

  @override
  State<DevToolsPanel> createState() => _DevToolsPanelState();

  @css
  static List<StyleRule> get styles => _DevToolsPanelState.styles;
}

class _DevToolsPanelState extends State<DevToolsPanel> {
  final GlobalNodeKey<web.HTMLIFrameElement> _iframeKey = GlobalNodeKey();
  web.MessageChannel? _channel;
  web.MutationObserver? _themeObserver;
  VmServiceBridge? _internalBridge;
  bool _isDark = false;

  VmServiceBridge? get _bridge =>
      component.vmServiceBridge ??
      _internalBridge ??
      (component.previewViewModel != null
          ? (_internalBridge = VmServiceBridge(previewViewModel: component.previewViewModel!))
          : null);

  @override
  void initState() {
    super.initState();
    _isDark = _checkIsDark();
    _initThemeObserver();
    _initChannel();
  }

  bool _checkIsDark() {
    final root = web.document.documentElement;
    if (root != null && root.hasAttribute('data-theme')) {
      return root.getAttribute('data-theme') == 'dark';
    }
    return web.window.localStorage.getItem('dartpad:theme') == 'dark';
  }

  void _initThemeObserver() {
    final root = web.document.documentElement;
    if (root == null) {
      return;
    }
    _themeObserver = web.MutationObserver(
      ((JSArray<web.MutationRecord> mutations, web.MutationObserver observer) {
        final isDark = _checkIsDark();
        if (isDark != _isDark) {
          setState(() {
            _isDark = isDark;
          });
        }
      }).toJS,
    );
    _themeObserver!.observe(
      root,
      web.MutationObserverInit(
        attributes: true,
        attributeFilter: ['data-theme'.toJS].toJS,
      ),
    );
  }

  String get _effectiveIframeUrl {
    final theme = _isDark ? 'dark' : 'light';
    final bg = _isDark ? '0C141D' : 'FFFFFF';
    if (component.iframeUrl case final customUrl?) {
      final uri = Uri.parse(customUrl);
      final queryParams = Map<String, String>.from(uri.queryParameters);
      queryParams['theme'] = theme;
      queryParams['backgroundColor'] = bg;
      return uri.replace(queryParameters: queryParams).toString();
    }
    return 'devtools/index.html?embedMode=one&theme=$theme&backgroundColor=$bg&compiler=wasm&uri=ws://0.0.0.0:1234/abc/ws';
  }

  void _initChannel() {
    _channel?.port1.close();
    _channel?.port2.close();
    final channel = web.MessageChannel();
    _channel = channel;

    channel.port1.start();

    _bridge?.attachSender((response) {
      channel.port1.postMessage(response.toJS);
    });

    channel.port1.onmessage = (web.MessageEvent event) {
      final data = event.data;
      component.onMessage?.call(data);
      _bridge?.handleMessage(data, (response) {
        channel.port1.postMessage(response.toJS);
      });
    }.toJS;
  }

  void _onIFrameLoaded() {
    final iframe = _iframeKey.currentNode;
    if (iframe == null) {
      return;
    }

    _initChannel();
    final channel = _channel;
    if (channel == null) {
      return;
    }

    final contentWindow = iframe.contentWindow;
    if (contentWindow != null) {
      // Transfer port2 to the iframe via postMessage.
      final ports = [channel.port2].toJS;
      contentWindow.postMessage('devtools-ws-port'.toJS, '*'.toJS, ports);

      // Also directly initialize port if accessible.
      _initPortDirect(contentWindow, channel.port2);
    }
  }

  void _initPortDirect(web.Window contentWindow, web.MessagePort port) {
    try {
      final jsWin = contentWindow as JSObject;
      final initFn = jsWin.getProperty<JSFunction?>('__initDevToolsWebSocketPort'.toJS);
      initFn?.callAsFunction(null, port);
    } catch (_) {
      // Ignore cross-origin errors if any.
    }
  }

  @override
  void dispose() {
    _themeObserver?.disconnect();
    _themeObserver = null;
    _channel?.port1.close();
    _channel?.port2.close();
    _channel = null;
    _internalBridge?.dispose();
    _internalBridge = null;
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'devtools-panel', [
      iframe(
        key: _iframeKey,
        classes: 'devtools-iframe',
        src: _effectiveIframeUrl,
        events: {
          'load': (_) => _onIFrameLoaded(),
        },
        [],
      ),
    ]);
  }

  static List<StyleRule> get styles => [
    css('.devtools-panel').styles(
      display: .flex,
      width: 100.percent,
      height: 100.percent,
      minHeight: .zero,
      overflow: .hidden,
      flexDirection: .column,
      flex: const Flex(grow: 1, basis: .zero),
      backgroundColor: Colors.transparent,
    ),
    css('.devtools-iframe').styles(
      width: 100.percent,
      height: 100.percent,
      border: .none,
      flex: const Flex(grow: 1, basis: .zero),
    ),
  ];
}

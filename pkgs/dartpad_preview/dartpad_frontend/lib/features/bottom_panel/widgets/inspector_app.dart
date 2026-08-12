// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'package:devtools_app/src/screens/inspector/inspector_controller.dart';
import 'package:devtools_app/src/screens/inspector/inspector_screen_body.dart';
import 'package:devtools_app/src/screens/inspector/inspector_tree_controller.dart';
import 'package:devtools_app/src/shared/console/primitives/simple_items.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/ui/hover.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'theme.dart';

class DevToolsInspectorApp extends StatefulWidget {
  const DevToolsInspectorApp({super.key});

  @override
  State<DevToolsInspectorApp> createState() => _DevToolsInspectorAppState();
}

class _DevToolsInspectorAppState extends State<DevToolsInspectorApp> {
  InspectorController? _controller;
  late final HoverCardController _hoverCardController;
  late final DartPadInspectorTheme _theme;

  @override
  void initState() {
    super.initState();
    _hoverCardController = HoverCardController();
    _theme = DartPadInspectorTheme(
      onThemeChanged: (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _theme.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ideTheme = globals[IdeTheme] as IdeTheme;
    final isDark = _theme.isDark;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: DartPadInspectorTheme.theme(isDark: false, baseIdeTheme: ideTheme),
      darkTheme: DartPadInspectorTheme.theme(isDark: true, baseIdeTheme: ideTheme),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: DefaultAssetBundle(
            bundle: DevToolsAssetBundle(),
            child: ListenableBuilder(
              listenable: serviceConnection.serviceManager.connectedState,
              builder: (context, _) {
                final isInitialized = serviceConnection.serviceManager.connectedAppInitialized;
                final inspectorService = serviceConnection.inspectorService;

                if (isInitialized && inspectorService != null) {
                  if (_controller == null) {
                    _controller = InspectorController(
                      inspectorTree: InspectorTreeController(),
                      treeType: FlutterTreeType.widget,
                    );
                    _controller!.setVisibleToUser(true);
                    _controller!.setActivate(true);
                  }
                  return Provider<HoverCardController>.value(
                    value: _hoverCardController,
                    child: InspectorScreenBody(controller: _controller!),
                  );
                }
                if (_controller != null) {
                  _controller!.dispose();
                  _controller = null;
                }
                return const Center(
                  child: Text('No active connection to preview sandbox.'),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class DevToolsAssetBundle extends PlatformAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key.startsWith('assets/') || key.startsWith('icons/')) {
      final String rewrittenKey = key.startsWith('assets/')
          ? 'packages/devtools_app/$key'
          : 'packages/devtools_app/assets/$key';
      try {
        final response = await http.get(Uri.parse('/$rewrittenKey'));
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          return ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
        }
      } catch (_) {
        // Fallback to normal behavior on error
      }
    }
    return super.load(key);
  }
}

// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_view/split_view.dart';
import 'package:url_strategy/url_strategy.dart';

import 'console.dart';
import 'editor/editor.dart';
import 'execution/execution.dart';
import 'model.dart';
import 'problems.dart';
import 'services/dartservices.dart';
import 'theme.dart';
import 'utils.dart';
import 'widgets.dart';

// TODO: have cmd-s re-run

// TODO: combine the app and console views

// TODO: window.flutterConfiguration

// TODO: support flutter snippets

// TODO: handle large console content

// TODO: explore using the monaco editor

const appName = 'SketchPad';

final ValueNotifier<bool> darkMode = ValueNotifier(true);

void main() async {
  setPathUrlStrategy();

  runApp(DartPadApp(prefs: await SharedPreferences.getInstance()));
}

class DartPadApp extends StatefulWidget {
  final SharedPreferences prefs;

  const DartPadApp({
    required this.prefs,
    super.key,
  });

  @override
  State<DartPadApp> createState() => _DartPadAppState();
}

class _DartPadAppState extends State<DartPadApp> {
  @override
  void initState() {
    super.initState();

    // Init the dark mode value notifier.
    darkMode.value = widget.prefs.getBool('darkMode') ?? true;
    darkMode.addListener(_storeThemeValue);
  }

  Future<void> _storeThemeValue() async {
    await widget.prefs.setBool('darkMode', darkMode.value);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: darkMode,
      builder: (BuildContext context, bool value, _) {
        return MaterialApp.router(
          title: appName,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSwatch(
              brightness: value ? Brightness.dark : Brightness.light,
            ),
          ),
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (BuildContext context, GoRouterState state) {
                  final id = state.queryParameters['id'];
                  return DartPadMainPage(
                    title: appName,
                    gistId: id,
                  );
                },
              ),
            ],
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }

  @override
  void dispose() {
    darkMode.removeListener(_storeThemeValue);

    super.dispose();
  }
}

class DartPadMainPage extends StatefulWidget {
  final String title;
  final String? gistId;

  const DartPadMainPage({
    required this.title,
    this.gistId,
    super.key,
  });

  @override
  State<DartPadMainPage> createState() => _DartPadMainPageState();
}

class _DartPadMainPageState extends State<DartPadMainPage> {
  final SplitViewController mainSplitter =
      SplitViewController(weights: [0.52, 0.48]);
  final SplitViewController uiConsoleSplitter =
      SplitViewController(weights: [0.64, 0.36]);

  late AppModel appModel;
  late AppServices appServices;

  @override
  void initState() {
    super.initState();

    final services = DartservicesApi(http.Client(),
        rootUrl: 'https://stable.api.dartpad.dev/');

    appModel = AppModel();
    appServices = AppServices(appModel, services);

    appServices.populateVersions();

    appServices.performInitialLoad(
      gistId: widget.gistId,
      fallbackSnippet: defaultSnippetSource,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final buttonStyle =
        TextButton.styleFrom(foregroundColor: colorScheme.onPrimary);

    final scaffold = Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/dart_logo_128.png',
              width: 32,
            ),
            const SizedBox(width: denseSpacing),
            const Text(appName),
            const SizedBox(width: defaultSpacing),
            Expanded(
              child: Center(
                child: ValueListenableBuilder<String>(
                  valueListenable: appModel.title,
                  builder: (BuildContext context, String value, _) {
                    return Text(value);
                  },
                ),
              ),
            ),
            const SizedBox(width: defaultSpacing),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => unimplemented(context, 'new snippet'),
            icon: const Icon(Icons.add_circle),
            label: const Text('New'),
            style: buttonStyle,
          ),
          const VerticalDivider(),
          TextButton.icon(
            onPressed: () => unimplemented(context, 'install sdk'),
            icon: const Icon(Icons.download),
            label: const Text('Install SDK'),
            style: buttonStyle,
          ),
          const VerticalDivider(),
          ValueListenableBuilder(
            valueListenable: darkMode,
            builder: (context, value, _) {
              // todo: animate the icon changes
              return IconButton(
                iconSize: defaultIconSize,
                splashRadius: defaultSplashRadius,
                onPressed: () => darkMode.value = !value,
                icon: value
                    ? const Icon(Icons.light_mode_outlined)
                    : const Icon(Icons.dark_mode_outlined),
              );
            },
          ),
          const SizedBox(width: denseSpacing),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Drawer Header',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Image.asset(
                'assets/dart_logo_128.png',
                width: defaultIconSize,
              ),
              title: const Text('Hello World'),
              onTap: () {
                Navigator.pop(context);
                context.push(Uri(path: '/', queryParameters: {
                  'id': 'c0f7c578204d61e08ec0fbc4d63456cd',
                }).toString());
              },
            ),
            ListTile(
              leading: Image.asset(
                'assets/dart_logo_128.png',
                width: defaultIconSize,
              ),
              title: const Text('Fibonacci'),
              onTap: () {
                Navigator.pop(context);
                context.push(Uri(path: '/', queryParameters: {
                  'id': 'd3bd83918d21b6d5f778bdc69c3d36d6',
                }).toString());
              },
            ),
            ListTile(
              leading: Image.asset(
                'assets/flutter_logo_192.png',
                width: defaultIconSize,
              ),
              title: const Text('Counter'),
              onTap: () {
                Navigator.pop(context);
                context.push(Uri(path: '/', queryParameters: {
                  'id': 'e75b493dae1287757c5e1d77a0dc73f1',
                }).toString());
              },
            ),
            ListTile(
              leading: Image.asset(
                'assets/flutter_logo_192.png',
                width: defaultIconSize,
              ),
              title: const Text('Sunflower'),
              onTap: () {
                Navigator.pop(context);
                context.push(Uri(path: '/', queryParameters: {
                  'id': '5c0e154dd50af4a9ac856908061291bc',
                }).toString());
              },
            ),
            const Divider(),
            const AboutListTile(icon: Icon(Icons.info)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: denseSpacing),
                child: SplitView(
                  viewMode: SplitViewMode.Horizontal,
                  gripColor: theme.scaffoldBackgroundColor,
                  gripColorActive: theme.scaffoldBackgroundColor,
                  gripSize: defaultGripSize,
                  controller: mainSplitter,
                  activeIndicator: SplitViewDragWidget.vertical(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: denseSpacing),
                      child: Column(
                        children: [
                          Expanded(
                            child: SectionWidget(
                              title: 'Code',
                              status: ProgressWidget(
                                status: appModel.editingProgressController,
                              ),
                              actions: [
                                ValueListenableBuilder<bool>(
                                  valueListenable: appModel.formattingBusy,
                                  builder: (context, bool value, _) {
                                    return MiniIconButton(
                                      icon: Icons.format_align_left,
                                      tooltip: 'Format',
                                      onPressed:
                                          value ? null : _handleFormatting,
                                    );
                                  },
                                ),
                                const SizedBox(width: denseSpacing),
                                const SizedBox(
                                    height: smallIconSize + 8,
                                    child: VerticalDivider()),
                                const SizedBox(width: denseSpacing),
                                ValueListenableBuilder<bool>(
                                  valueListenable: appModel.compilingBusy,
                                  builder: (context, bool value, _) {
                                    return MiniIconButton(
                                      icon: Icons.play_arrow,
                                      tooltip: 'Run',
                                      onPressed:
                                          value ? null : _handleCompiling,
                                    );
                                  },
                                ),
                              ],
                              child: EditorWidget(appModel: appModel),
                            ),
                          ),
                          ValueListenableBuilder<List<AnalysisIssue>>(
                            valueListenable: appModel.analysisIssues,
                            builder: (context, issues, _) {
                              return ProblemsWidget(problems: issues);
                            },
                          ),
                        ],
                      ),
                    ),
                    // ),
                    Padding(
                      padding: const EdgeInsets.only(right: denseSpacing),
                      child: SplitView(
                        viewMode: SplitViewMode.Vertical,
                        gripColor: theme.scaffoldBackgroundColor,
                        gripColorActive: theme.scaffoldBackgroundColor,
                        gripSize: defaultGripSize,
                        controller: uiConsoleSplitter,
                        activeIndicator: SplitViewDragWidget.horizontal(),
                        children: [
                          SectionWidget(
                            title: 'App',
                            status: ProgressWidget(
                              status: appModel.executionProgressController,
                            ),
                            actions: [
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable:
                                    appModel.consoleOutputController,
                                builder: (context, value, _) {
                                  return MiniIconButton(
                                    icon: Icons.playlist_remove,
                                    tooltip: 'Clear console',
                                    onPressed: value.text.isEmpty
                                        ? null
                                        : _clearConsole,
                                  );
                                },
                              ),
                              const SizedBox(width: denseSpacing),
                              const SizedBox(
                                  height: smallIconSize + 8,
                                  child: VerticalDivider()),
                              const SizedBox(width: denseSpacing),
                              CompilingStatusWidget(
                                  status: appModel.compilingBusy),
                            ],
                            child: ExecutionWidget(
                              appServices: appServices,
                            ),
                          ),
                          SectionWidget(
                            title: 'Console',
                            child: ConsoleWidget(
                                consoleOutputController:
                                    appModel.consoleOutputController),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const StatusLineWidget(),
        ],
      ),
    );

    return Provider<AppServices>.value(
      value: appServices,
      child: Provider<AppModel>.value(
        value: appModel,
        child: scaffold,
      ),
    );
  }

  Future<void> _handleFormatting() async {
    final value = appModel.sourceCodeController.text;

    // TODO: catch and handle exceptions
    var result = await appServices.format(SourceRequest(source: value));

    if (result.hasError()) {
      // TODO: in practice we don't get errors back, just no formatting changes
      appModel.editingProgressController.showToast('Error formatting code');
      appModel.appendLineToConsole('Formatting issue: ${result.error.message}');
    } else if (result.newString == value) {
      appModel.editingProgressController.showToast('No formatting changes');
    } else {
      appModel.editingProgressController.showToast('Format successful');
      appModel.sourceCodeController.text = result.newString;
    }
  }

  Future<void> _handleCompiling() async {
    final value = appModel.sourceCodeController.text;
    final progress = appModel.executionProgressController
        .showMessage(initialText: 'Compiling…');
    _clearConsole();

    try {
      final response = await appServices.compile(CompileRequest(source: value));

      appModel.executionProgressController
          .showToast('Running…', duration: const Duration(seconds: 1));
      appServices.executeJavaScript(response.result);
    } catch (error) {
      appModel.executionProgressController.showToast('Compilation failed');

      var message = error is ApiRequestError ? error.message : '$error';
      appModel.appendLineToConsole(message);
    } finally {
      progress.close();
    }
  }

  void _clearConsole() {
    appModel.clearConsole();
  }
}

class StatusLineWidget extends StatelessWidget {
  const StatusLineWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final darkTheme = colorScheme.brightness == Brightness.dark;
    final textColor = colorScheme.onPrimaryContainer;
    final textStyle = TextStyle(color: textColor);

    final appModel = Provider.of<AppModel>(context);

    return Container(
      decoration: BoxDecoration(
        color: darkTheme ? colorScheme.surface : colorScheme.primary,
        border: Border(top: Divider.createBorderSide(context, width: 1.0)),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: denseSpacing,
        horizontal: defaultSpacing,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                MiniIconButton(
                  icon: Icons.keyboard,
                  tooltip: 'Keybindings',
                  onPressed: () => unimplemented(context, 'keybindings legend'),
                  color: textColor,
                ),
                const Expanded(child: SizedBox(width: defaultSpacing)),
                ValueListenableBuilder(
                  valueListenable: appModel.runtimeVersions,
                  builder: (content, version, _) {
                    return Text(
                      version.sdkVersion.isEmpty
                          ? ''
                          : 'Dart ${version.sdkVersion}',
                      style: textStyle,
                    );
                  },
                ),
              ],
            ),
          ),
          Text(' • ', style: textStyle),
          Expanded(
            child: Row(
              children: [
                ValueListenableBuilder(
                  valueListenable: appModel.runtimeVersions,
                  builder: (content, version, _) {
                    return Text(
                      version.flutterVersion.isEmpty
                          ? ''
                          : 'Flutter ${version.flutterVersion}',
                      style: textStyle,
                    );
                  },
                ),
                const Expanded(child: SizedBox(width: defaultSpacing)),
                Hyperlink(
                  url: 'https://dart.dev/tools/dartpad/privacy',
                  displayText: 'Privacy notice',
                  style: textStyle,
                ),
                const SizedBox(width: defaultSpacing),
                Hyperlink(
                  url: 'https://github.com/dart-lang/dart-pad/issues',
                  displayText: 'Feedback',
                  style: textStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SectionWidget extends StatelessWidget {
  static const insets = 6.0;

  final String title;
  final Widget? status;
  final List<Widget> actions;
  final Widget child;

  const SectionWidget({
    required this.title,
    this.status,
    this.actions = const [],
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(denseSpacing),
            decoration: BoxDecoration(
              border:
                  Border(bottom: Divider.createBorderSide(context, width: 1)),
            ),
            child: SizedBox(
              height: defaultIconSize,
              child: Row(
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(width: defaultSpacing),
                  if (status != null) status!,
                  const Expanded(child: SizedBox(width: defaultSpacing)),
                  ...actions
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(denseSpacing),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

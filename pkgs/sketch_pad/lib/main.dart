// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:split_view/split_view.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import 'console.dart';
import 'editor/editor.dart';
import 'execution/execution.dart';
import 'model.dart';
import 'problems.dart';
import 'samples.dart';
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

void main() async {
  setPathUrlStrategy();

  runApp(const DartPadApp());
}

class DartPadApp extends StatefulWidget {
  const DartPadApp({
    super.key,
  });

  @override
  State<DartPadApp> createState() => _DartPadAppState();
}

class _DartPadAppState extends State<DartPadApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: appName,
      routerConfig: GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) {
              final idParam = state.queryParameters['id'];
              final sampleParam = state.queryParameters['sample'];
              final themeParam = state.queryParameters['theme'] ?? 'dark';
              final bool darkMode = themeParam == 'dark';

              return Theme(
                data: ThemeData(
                  colorScheme: ColorScheme.fromSwatch(
                    brightness: darkMode ? Brightness.dark : Brightness.light,
                  ),
                ),
                child: DartPadMainPage(
                  title: appName,
                  sampleId: sampleParam,
                  gistId: idParam,
                ),
              );
            },
          ),
        ],
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DartPadMainPage extends StatefulWidget {
  final String title;
  final String? sampleId;
  final String? gistId;

  const DartPadMainPage({
    required this.title,
    this.sampleId,
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
      sampleId: widget.sampleId,
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
            dartLogo(width: 32),
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
          const SizedBox(width: denseSpacing),
          const OverflowMenu(),
        ],
      ),
      drawer: const SamplesDrawer(),
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
                              child: Stack(
                                children: [
                                  EditorWidget(appModel: appModel),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Format action
                                      ValueListenableBuilder<bool>(
                                        valueListenable:
                                            appModel.formattingBusy,
                                        builder: (context, bool value, _) {
                                          return MiniIconButton(
                                            icon: Icons.format_align_left,
                                            tooltip: 'Format',
                                            onPressed: value
                                                ? null
                                                : _handleFormatting,
                                          );
                                        },
                                      ),
                                      const SizedBox(width: defaultSpacing),
                                      // Run action
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
                                  ),
                                ],
                              ),
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
                            child: Stack(
                              children: [
                                ExecutionWidget(
                                  appServices: appServices,
                                ),
                                Container(
                                  alignment: Alignment.topRight,
                                  child: SizedBox(
                                    width: 32,
                                    child: CompilingStatusWidget(
                                      status: appModel.compilingBusy,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SectionWidget(
                            title: 'Console',
                            child: Stack(
                              children: [
                                ConsoleWidget(
                                    consoleOutputController:
                                        appModel.consoleOutputController),
                                Container(
                                  alignment: Alignment.topRight,
                                  child:
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
                                ),
                              ],
                            ),
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
      appModel.statusController.showToast('Error formatting code');
      appModel.appendLineToConsole('Formatting issue: ${result.error.message}');
    } else if (result.newString == value) {
      appModel.statusController.showToast('No formatting changes');
    } else {
      appModel.statusController.showToast('Format successful');
      appModel.sourceCodeController.text = result.newString;
    }
  }

  Future<void> _handleCompiling() async {
    final value = appModel.sourceCodeController.text;
    final progress =
        appModel.statusController.showMessage(initialText: 'Compiling…');
    _clearConsole();

    try {
      final response = await appServices.compile(CompileRequest(source: value));

      appModel.statusController
          .showToast('Running…', duration: const Duration(seconds: 1));
      appServices.executeJavaScript(response.result);
    } catch (error) {
      appModel.statusController.showToast('Compilation failed');

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

    final darkTheme = colorScheme.darkMode;
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
        children: [
          Tooltip(
            message: 'Keybindinge',
            waitDuration: tooltipDelay,
            child: IconButton(
              icon: const Icon(Icons.keyboard),
              iconSize: smallIconSize,
              splashRadius: defaultIconSize,
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.all(2),
              visualDensity: VisualDensity.compact,
              onPressed: () => unimplemented(context, 'keybindings legend'),
              color: textColor,
            ),
          ),
          const SizedBox(width: defaultSpacing),
          ProgressWidget(status: appModel.statusController),
          const Expanded(child: SizedBox(width: defaultSpacing)),
          ValueListenableBuilder(
            valueListenable: appModel.runtimeVersions,
            builder: (content, version, _) {
              return Text(
                version.sdkVersion.isEmpty ? '' : 'Dart ${version.sdkVersion}',
                style: textStyle,
              );
            },
          ),
          Text(' • ', style: textStyle),
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
        ],
      ),
    );
  }
}

class SectionWidget extends StatelessWidget {
  static const insets = 6.0;

  final String title;
  final List<Widget> actions;
  final Widget child;

  const SectionWidget({
    required this.title,
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

class OverflowMenu extends StatelessWidget {
  const OverflowMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (context) {
        return <PopupMenuEntry<String>>[
          const PopupMenuItem(
            value: 'https://dart.dev',
            child: ListTile(
              title: Text('dart.dev'),
              trailing: Icon(Icons.launch),
            ),
          ),
          const PopupMenuItem(
            value: 'https://flutter.dev',
            child: ListTile(
              title: Text('flutter.dev'),
              trailing: Icon(Icons.launch),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'https://github.com/dart-lang/dart-pad/wiki/Sharing-Guide',
            child: ListTile(
              title: Text('Share'),
              trailing: Icon(Icons.launch),
            ),
          ),
          const PopupMenuItem(
            value: 'https://github.com/dart-lang/dart-pad',
            child: ListTile(
              title: Text('DartPad on GitHub'),
              trailing: Icon(Icons.launch),
            ),
          ),
        ];
      },
      onSelected: (url) {
        url_launcher.launchUrl(Uri.parse(url));
      },
    );
  }
}

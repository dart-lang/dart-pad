// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:split_view/split_view.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:url_strategy/url_strategy.dart';
import 'package:vtable/vtable.dart';

import 'console.dart';
import 'editor/editor.dart';
import 'execution/execution.dart';
import 'keys.dart' as keys;
import 'model.dart';
import 'problems.dart';
import 'samples.g.dart';
import 'services/dartservices.dart';
import 'theme.dart';
import 'utils.dart';
import 'widgets.dart';

// TODO: combine the app and console views

// TODO: window.flutterConfiguration

// TODO: support flutter snippets

// TODO: handle large console content

// TODO: explore using the monaco editor

// todo: have a theme toggle

const appName = 'DartPad';

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

    appModel = AppModel();
    appServices = AppServices(
      appModel,
      DartservicesApi(
        http.Client(),
        rootUrl: 'https://stable.api.dartpad.dev/',
      ),
    );

    appServices.populateVersions();

    appServices.performInitialLoad(
      sampleId: widget.sampleId,
      gistId: widget.gistId,
      fallbackSnippet: Samples.getDefault(type: 'dart'),
    );
  }

  @override
  void dispose() {
    appServices.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final buttonStyle =
        TextButton.styleFrom(foregroundColor: colorScheme.onPrimary);

    final scaffold = Scaffold(
      appBar: AppBar(
        title: SizedBox(
          height: toolbarItemHeight,
          child: Row(
            children: [
              dartLogo(width: 32),
              const SizedBox(width: denseSpacing),
              const Text(appName),
              const SizedBox(width: defaultSpacing * 4),
              NewSnippetWidget(
                appServices: appServices,
                buttonStyle: buttonStyle,
              ),
              const SizedBox(width: denseSpacing),
              ListSamplesWidget(buttonStyle: buttonStyle),
              const SizedBox(width: defaultSpacing),
              // title widget
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
        ),
        actions: [
          // install sdk
          TextButton(
            onPressed: () {
              url_launcher.launchUrl(
                Uri.parse('https://docs.flutter.dev/get-started/install'),
              );
            },
            style: buttonStyle,
            child: const Row(
              children: [
                Text('Install SDK'),
                SizedBox(width: denseSpacing),
                Icon(Icons.launch, size: smallIconSize),
              ],
            ),
          ),
          const SizedBox(width: denseSpacing),
          const OverflowMenu(),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SplitView(
                viewMode: SplitViewMode.Horizontal,
                gripColor: theme.scaffoldBackgroundColor,
                gripColorActive: theme.scaffoldBackgroundColor,
                gripSize: defaultGripSize,
                controller: mainSplitter,
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: SectionWidget(
                          child: Stack(
                            children: [
                              EditorWidget(
                                appModel: appModel,
                                appServices: appServices,
                              ),
                              Padding(
                                padding: const EdgeInsets.all(denseSpacing),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Format action
                                    ValueListenableBuilder<bool>(
                                      valueListenable: appModel.formattingBusy,
                                      builder: (context, bool value, _) {
                                        return PointerInterceptor(
                                          child: MiniIconButton(
                                            icon: Icons.format_align_left,
                                            tooltip: 'Format',
                                            onPressed: value
                                                ? null
                                                : _handleFormatting,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: defaultSpacing),
                                    // Run action
                                    ValueListenableBuilder<bool>(
                                      valueListenable: appModel.compilingBusy,
                                      builder: (context, bool value, _) {
                                        return PointerInterceptor(
                                          child: MiniIconButton(
                                            icon: Icons.play_arrow,
                                            tooltip: 'Run',
                                            onPressed: value
                                                ? null
                                                : _performCompileAndRun,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                alignment: Alignment.bottomRight,
                                padding: const EdgeInsets.all(denseSpacing),
                                child: ProgressWidget(
                                  status: appModel.editorStatus,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ValueListenableBuilder<List<AnalysisIssue>>(
                        valueListenable: appModel.analysisIssues,
                        builder: (context, issues, _) {
                          return ProblemsTableWidget(problems: issues);
                        },
                      ),
                    ],
                  ),
                  // ),
                  SplitView(
                    viewMode: SplitViewMode.Vertical,
                    gripColor: theme.scaffoldBackgroundColor,
                    gripColorActive: theme.scaffoldBackgroundColor,
                    gripSize: defaultGripSize,
                    controller: uiConsoleSplitter,
                    children: [
                      SectionWidget(
                        child: Stack(
                          children: [
                            ExecutionWidget(appServices: appServices),
                            Container(
                              alignment: Alignment.topRight,
                              padding: const EdgeInsets.all(denseSpacing),
                              child: SizedBox(
                                width: 40,
                                child: CompilingStatusWidget(
                                  status: appModel.compilingBusy,
                                ),
                              ),
                            ),
                            Container(
                              alignment: Alignment.topLeft,
                              padding: const EdgeInsets.all(denseSpacing),
                              child: ProgressWidget(
                                status: appModel.executionStatus,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SectionWidget(
                        child: ConsoleWidget(
                          consoleOutputController:
                              appModel.consoleOutputController,
                        ),
                      ),
                    ],
                  ),
                ],
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
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            keys.reloadKeyActivator: () {
              if (!appModel.compilingBusy.value) {
                _performCompileAndRun();
              }
            },
            keys.findKeyActivator: () {
              unimplemented(context, 'find');
            },
            keys.findNextKeyActivator: () {
              unimplemented(context, 'find next');
            },
            keys.codeCompletionKeyActivator: () {
              appServices.editorService?.showCompletions();
            },
          },
          child: Focus(
            autofocus: true,
            child: scaffold,
          ),
        ),
      ),
    );
  }

  Future<void> _handleFormatting() async {
    final value = appModel.sourceCodeController.text;

    // TODO: catch and handle exceptions
    var result = await appServices.format(SourceRequest()..source = value);

    if (result.hasError()) {
      appModel.editorStatus.showToast('Error formatting code');
      appModel.appendLineToConsole('Formatting issue: ${result.error.message}');
    } else if (result.newString == value) {
      appModel.editorStatus.showToast('No formatting changes');
    } else {
      appModel.editorStatus.showToast('Format successful');
      appModel.sourceCodeController.text = result.newString;
    }
  }

  Future<void> _performCompileAndRun() async {
    final value = appModel.sourceCodeController.text;
    final progress =
        appModel.executionStatus.showMessage(initialText: 'Compiling…');
    appModel.clearConsole();

    try {
      final response =
          await appServices.compile(CompileRequest()..source = value);

      appModel.executionStatus
          .showToast('Running…', duration: const Duration(seconds: 1));
      appServices.executeJavaScript(response.result);
    } catch (error) {
      appModel.executionStatus.showToast('Compilation failed');

      var message = error is ApiRequestError ? error.message : '$error';
      appModel.appendLineToConsole(message);
    } finally {
      progress.close();
    }
  }
}

class StatusLineWidget extends StatelessWidget {
  const StatusLineWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final darkTheme = colorScheme.darkMode;
    final textColor = colorScheme.onPrimaryContainer;

    final buttonStyle =
        TextButton.styleFrom(foregroundColor: colorScheme.onPrimary);

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
            message: 'Keyboard shortcuts',
            waitDuration: tooltipDelay,
            child: IconButton(
              icon: const Icon(Icons.keyboard),
              iconSize: smallIconSize,
              splashRadius: defaultIconSize,
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.all(2),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (context) {
                    return MediumDialog(
                      title: 'Keyboard shortcuts',
                      smaller: true,
                      child: KeyBindingsTable(bindings: keys.keyBindings),
                    );
                  },
                );
              },
              color: textColor,
            ),
          ),
          const SizedBox(width: defaultSpacing),
          const Hyperlink(
            displayText: 'Privacy notice',
            url: 'https://dart.dev/tools/dartpad/privacy',
          ),
          const SizedBox(width: defaultSpacing),
          const Hyperlink(
            displayText: 'Feedback',
            url: 'https://github.com/dart-lang/dart-pad/issues',
          ),
          const Expanded(child: SizedBox(width: defaultSpacing)),
          SizedBox(
            height: 26,
            child: SelectChannelWidget(buttonStyle: buttonStyle),
          ),
          const SizedBox(width: defaultSpacing),
          VersionInfoWidget(appModel.runtimeVersions),
        ],
      ),
    );
  }
}

class SectionWidget extends StatelessWidget {
  final Widget child;

  const SectionWidget({
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(denseSpacing),
        child: child,
      ),
    );
  }
}

class NewSnippetWidget extends StatelessWidget {
  final AppServices appServices;
  final ButtonStyle buttonStyle;

  const NewSnippetWidget({
    required this.appServices,
    required this.buttonStyle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: toolbarItemHeight,
      child: TextButton.icon(
        icon: const Icon(Icons.add_circle),
        label: const Text('New'),
        style: buttonStyle,
        onPressed: () async {
          final selection =
              await _showMenu(context, calculatePopupMenuPosition(context));
          if (selection != null) {
            _handleSelection(appServices, selection);
          }
        },
      ),
    );
  }

  Future<bool?> _showMenu(BuildContext context, RelativeRect position) {
    return showMenu<bool>(
      context: context,
      position: position,
      items: <PopupMenuEntry<bool>>[
        PopupMenuItem(
          value: true,
          child: PointerInterceptor(
            child: ListTile(
              leading: dartLogo(),
              title: const Text('New Dart snippet'),
            ),
          ),
        ),
        PopupMenuItem(
          value: false,
          child: PointerInterceptor(
            child: ListTile(
              leading: flutterLogo(),
              title: const Text('New Flutter snippet'),
            ),
          ),
        ),
      ],
    );
  }

  void _handleSelection(AppServices appServices, bool dartSample) {
    appServices.resetTo(type: dartSample ? 'dart' : 'flutter');
  }
}

class ListSamplesWidget extends StatelessWidget {
  final ButtonStyle buttonStyle;

  const ListSamplesWidget({
    required this.buttonStyle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: toolbarItemHeight,
      child: TextButton.icon(
        icon: const Icon(Icons.playlist_add_outlined),
        label: const Text('Samples'),
        style: buttonStyle,
        onPressed: () async {
          final selection =
              await _showMenu(context, calculatePopupMenuPosition(context));
          if (selection != null && context.mounted) {
            _handleSelection(context, selection);
          }
        },
      ),
    );
  }

  Future<String?> _showMenu(BuildContext context, RelativeRect position) {
    var categories = Samples.categories.keys;

    final menuItems = <PopupMenuEntry<String?>>[
      for (var category in categories) ...[
        const PopupMenuDivider(),
        PopupMenuItem(
          value: null,
          enabled: false,
          child: PointerInterceptor(
            child: ListTile(title: Text(category)),
          ),
        ),
        ...Samples.categories[category]!.map((sample) {
          return PopupMenuItem(
            value: sample.id,
            child: PointerInterceptor(
              child: ListTile(
                leading: sample.isDart ? dartLogo() : flutterLogo(),
                title: Text(sample.name),
              ),
            ),
          );
        }),
      ],
    ];

    return showMenu<String?>(
      context: context,
      position: position,
      items: menuItems.skip(1).toList(),
    );
  }

  void _handleSelection(BuildContext context, String sampleId) {
    final uri = Uri(path: '/', queryParameters: {'sample': sampleId});
    context.push(uri.toString());
  }
}

class SelectChannelWidget extends StatelessWidget {
  final ButtonStyle buttonStyle;

  const SelectChannelWidget({
    required this.buttonStyle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: toolbarItemHeight,
      child: TextButton.icon(
        icon: const Icon(Icons.keyboard_arrow_down),
        label: const Text('SDK Channel'), // todo: 'stable channel' / ...
        style: buttonStyle,
        onPressed: () async {
          final selection =
              await _showMenu(context, calculatePopupMenuPosition(context));
          if (selection != null && context.mounted) {
            _handleSelection(context, selection);
          }
        },
      ),
    );
  }

  Future<String?> _showMenu(BuildContext context, RelativeRect position) {
    var channels = ['stable', 'beta'];

    final menuItems = <PopupMenuEntry<String?>>[
      for (var channel in channels)
        PopupMenuItem(
          value: channel,
          child: PointerInterceptor(
            child: ListTile(
              title: Text(channel),
            ),
          ),
        )
    ];

    return showMenu<String?>(
      context: context,
      position: position,
      items: menuItems,
    );
  }

  void _handleSelection(BuildContext context, String channel) {
    // TODO: switch channel

    unimplemented(context, 'select channel: $channel');
  }
}

class OverflowMenu extends StatelessWidget {
  const OverflowMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.more_vert),
      splashRadius: defaultSplashRadius,
      onPressed: () async {
        final selection =
            await _showMenu(context, calculatePopupMenuPosition(context));
        if (selection != null) {
          url_launcher.launchUrl(Uri.parse(selection));
        }
      },
    );
  }

  Future<String?> _showMenu(BuildContext context, RelativeRect position) {
    return showMenu<String?>(
      context: context,
      position: position,
      items: <PopupMenuEntry<String?>>[
        PopupMenuItem(
          value: 'https://dart.dev',
          child: PointerInterceptor(
            child: const ListTile(
              title: Text('dart.dev'),
              trailing: Icon(Icons.launch),
            ),
          ),
        ),
        PopupMenuItem(
          value: 'https://flutter.dev',
          child: PointerInterceptor(
            child: const ListTile(
              title: Text('flutter.dev'),
              trailing: Icon(Icons.launch),
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'https://github.com/dart-lang/dart-pad/wiki/Sharing-Guide',
          child: PointerInterceptor(
            child: const ListTile(
              title: Text('DartPad on GitHub'),
              trailing: Icon(Icons.launch),
            ),
          ),
        ),
        PopupMenuItem(
          value: 'https://github.com/dart-lang/dart-pad',
          child: PointerInterceptor(
            child: const ListTile(
              title: Text('DartPad on GitHub'),
              trailing: Icon(Icons.launch),
            ),
          ),
        ),
      ],
    );
  }
}

class KeyBindingsTable extends StatelessWidget {
  final List<(String, ShortcutActivator)> bindings;

  const KeyBindingsTable({
    required this.bindings,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Expanded(
          child: VTable<(String, ShortcutActivator)>(
            showToolbar: false,
            showHeaders: false,
            startsSorted: true,
            items: bindings,
            columns: [
              VTableColumn(
                label: 'Command',
                width: 100,
                grow: 0.5,
                transformFunction: (binding) => binding.$1,
              ),
              VTableColumn(
                label: 'Keyboard shortcut',
                width: 100,
                grow: 0.5,
                alignment: Alignment.centerRight,
                transformFunction: (binding) =>
                    (binding.$2 as SingleActivator).describe,
                styleFunction: (binding) => subtleText,
                renderFunction: (context, binding, _) {
                  return (binding.$2 as SingleActivator)
                      .renderToWidget(context);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class VersionInfoWidget extends StatefulWidget {
  final ValueListenable<VersionResponse> runtimeVersions;

  const VersionInfoWidget(
    this.runtimeVersions, {
    Key? key,
  }) : super(key: key);

  @override
  State<VersionInfoWidget> createState() => _VersionInfoWidgetState();
}

class _VersionInfoWidgetState extends State<VersionInfoWidget> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VersionResponse>(
      valueListenable: widget.runtimeVersions,
      builder: (content, versions, _) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            child: Text(
              'Dart ${versions.sdkVersion} • Flutter ${versions.flutterVersion}',
            ),
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (context) {
                  return MediumDialog(
                    title: 'Runtime Versions',
                    child: VersionTable(versions: versions),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class VersionTable extends StatelessWidget {
  final VersionResponse versions;

  const VersionTable({
    required this.versions,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final packages = versions.packageInfo.where((p) => p.supported).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text(
          'Based on Dart SDK ${versions.sdkVersion} '
          'and Flutter SDK ${versions.flutterVersion}.',
        ),
        const Divider(),
        const SizedBox(height: defaultSpacing),
        Expanded(
          child: VTable<PackageInfo>(
            showToolbar: false,
            items: packages,
            columns: [
              VTableColumn(
                label: 'Package',
                width: 250,
                grow: 0.7,
                transformFunction: (p) => 'package:${p.name}',
              ),
              VTableColumn(
                label: 'Version',
                width: 70,
                grow: 0.3,
                transformFunction: (p) => p.version,
                styleFunction: (p) => subtleText,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

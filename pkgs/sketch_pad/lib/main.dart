// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import 'src/dart_services.dart';
import 'theme.dart';
import 'utils.dart';
import 'widgets.dart';

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
              final colorScheme = ColorScheme.fromSwatch(
                brightness: darkMode ? Brightness.dark : Brightness.light,
              );

              return Theme(
                data: ThemeData(
                  colorScheme: colorScheme,
                  // TODO: We should switch to using material 3.
                  useMaterial3: false,
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onPrimary,
                    ),
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
      SplitViewController(weights: [0.58, 0.42]);

  late AppModel appModel;
  late AppServices appServices;

  @override
  void initState() {
    super.initState();

    appModel = AppModel();
    appServices = AppServices(
      appModel,
      Channel.stable, // Channel.localhost
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
              NewSnippetWidget(appServices: appServices),
              const SizedBox(width: denseSpacing),
              const ListSamplesWidget(),
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
                        title: 'App',
                        actions: CompilingStatusWidget(
                          size: defaultIconSize,
                          status: appModel.compilingBusy,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ExecutionWidget(
                              appServices: appServices,
                            ),
                            ValueListenableBuilder<bool>(
                              valueListenable: appModel.compilingBusy,
                              builder:
                                  (BuildContext context, bool compiling, _) {
                                final isFlutter = appModel.appIsFlutter.value;

                                return AnimatedContainer(
                                  duration: animationDelay,
                                  curve: animationCurve,
                                  color: compiling
                                      ? const Color.fromARGB(100, 158, 158, 158)
                                      : const Color.fromARGB(0, 158, 158, 158),
                                  child: Center(
                                    child: Text(
                                      (isFlutter == false) && !compiling
                                          ? 'Dart only snippet'
                                          : '',
                                      style: subtleText,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      SectionWidget(
                        title: 'Console output',
                        actions: Tooltip(
                          message: 'Clear',
                          waitDuration: tooltipDelay,
                          child: ValueListenableBuilder<bool>(
                            valueListenable: appModel.consoleHasOutput,
                            builder: (BuildContext context, bool value, _) {
                              return IconButton(
                                icon: const Icon(Icons.playlist_remove),
                                iconSize: smallIconSize,
                                splashRadius: defaultIconSize,
                                constraints: const BoxConstraints(
                                    minWidth: 20, minHeight: 20),
                                padding: const EdgeInsets.all(2),
                                visualDensity: VisualDensity.compact,
                                onPressed: value ? _clearConsole : null,
                              );
                            },
                          ),
                        ),
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

    FormatResponse result;

    try {
      result = await appServices.format(SourceRequest()..source = value);
    } catch (error) {
      appModel.editorStatus.showToast('Error formatting code');
      appModel.appendLineToConsole('Formatting issue: $error');
      return;
    }

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

  void _clearConsole() {
    appModel.clearConsole();

    appModel.editorStatus.showToast('Console cleared');
  }

  Future<void> _performCompileAndRun() async {
    final value = appModel.sourceCodeController.text;
    final progress =
        appModel.editorStatus.showMessage(initialText: 'Compiling…');
    appModel.clearConsole();

    try {
      final response =
          await appServices.build(FlutterBuildRequest()..source = value);

      final artifacts = response.artifacts;
      appServices.executeJavaScript(artifacts['main.dart.js']!);
    } catch (error) {
      appModel.editorStatus.showToast('Compilation failed');

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
          TextButton(
            onPressed: () {
              const url = 'https://dart.dev/tools/dartpad/privacy';
              url_launcher.launchUrl(Uri.parse(url));
            },
            child: const Text('Privacy notice'),
          ),
          const SizedBox(width: defaultSpacing),
          TextButton(
            onPressed: () {
              const url = 'https://github.com/dart-lang/dart-pad/issues';
              url_launcher.launchUrl(Uri.parse(url));
            },
            child: const Text('Feedback'),
          ),
          const Expanded(child: SizedBox(width: defaultSpacing)),
          VersionInfoWidget(appModel.runtimeVersions),
          const SizedBox(width: defaultSpacing),
          const SizedBox(
            height: 26,
            child: SelectChannelWidget(),
          ),
        ],
      ),
    );
  }
}

class SectionWidget extends StatelessWidget {
  final String? title;
  final Widget? actions;
  final Widget child;

  const SectionWidget({
    this.title,
    this.actions,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var c = child;

    if (title != null || actions != null) {
      c = Column(
        children: [
          Row(
            children: [
              if (title != null) Text(title!, style: subtleText),
              const Expanded(child: SizedBox(width: defaultSpacing)),
              if (actions != null) actions!,
            ],
          ),
          const Divider(),
          Expanded(child: child),
        ],
      );
    }

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(denseSpacing),
        child: c,
      ),
    );
  }
}

class NewSnippetWidget extends StatelessWidget {
  final AppServices appServices;

  const NewSnippetWidget({
    required this.appServices,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: toolbarItemHeight,
      child: TextButton.icon(
        icon: const Icon(Icons.add_circle),
        label: const Text('New'),
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
  const ListSamplesWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: toolbarItemHeight,
      child: TextButton.icon(
        icon: const Icon(Icons.playlist_add_outlined),
        label: const Text('Samples'),
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
  const SelectChannelWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: Update this control when the channel changes.
    final appServices = Provider.of<AppServices>(context);

    return SizedBox(
      height: toolbarItemHeight,
      child: TextButton.icon(
        icon: const Icon(Icons.tune, size: smallIconSize),
        label: Text('${appServices.channel.displayName} channel'),
        onPressed: () async {
          final selection = await _showMenu(
            context,
            calculatePopupMenuPosition(context, growUpwards: true),
            appServices.channel,
          );
          if (selection != null && context.mounted) {
            _handleSelection(context, selection);
          }
        },
      ),
    );
  }

  Future<Channel?> _showMenu(
      BuildContext context, RelativeRect position, Channel current) {
    const itemHeight = 46.0;

    final menuItems = <PopupMenuEntry<Channel>>[
      for (var channel in Channel.valuesWithoutLocalhost)
        PopupMenuItem<Channel>(
          value: channel,
          child: PointerInterceptor(
            child: ListTile(
              title: Text(channel.displayName),
            ),
          ),
        )
    ];

    return showMenu<Channel>(
      context: context,
      position: position.shift(Offset(0, -1 * menuItems.length * itemHeight)),
      items: menuItems,
    );
  }

  void _handleSelection(BuildContext context, Channel channel) {
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
              title: Text('Sharing Guide'),
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
        return TextButton(
          onPressed: () {
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
          child: Text(
            'Dart ${versions.sdkVersion} • Flutter ${versions.flutterVersion}',
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

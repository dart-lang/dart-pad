// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/services.dart';
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
import 'extensions.dart';
import 'keys.dart' as keys;
import 'model.dart';
import 'problems.dart';
import 'samples.g.dart';
import 'theme.dart';
import 'utils.dart';
import 'versions.dart';
import 'widgets.dart';

// TODO: explore using the monaco editor

// TODO: have a theme toggle

// TODO: show documentation on hover

// TODO: implement find / find next

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
  ThemeMode themeMode = ThemeMode.dark;
  late final GoRouter router;

  @override
  void initState() {
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: _homePageBuilder,
        ),
      ],
    );
    super.initState();
  }

  void handleBrightnessChanged(BuildContext context, bool isLightMode) {
    if (isLightMode) {
      setState(() {
        themeMode = ThemeMode.light;
      });
      GoRouter.of(context).replaceQueryParam('theme', 'light');
    } else {
      setState(() {
        themeMode = ThemeMode.dark;
      });
      GoRouter.of(context).replaceQueryParam('theme', 'dark');
    }
  }

  Widget _homePageBuilder(BuildContext context, GoRouterState state) {
    final idParam = state.uri.queryParameters['id'];
    final sampleParam = state.uri.queryParameters['sample'];
    final themeParam = state.uri.queryParameters['theme'];
    final channelParam = state.uri.queryParameters['channel'];
    final embedMode = state.uri.queryParameters['embed'] == 'true';

    final ThemeMode newThemeMode = switch (themeParam) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };

    if (newThemeMode != themeMode) {
      themeMode = newThemeMode;
    }

    return DartPadMainPage(
      title: appName,
      initialChannel: channelParam,
      embedMode: embedMode,
      sampleId: sampleParam,
      gistId: idParam,
      themeMode: themeMode,
      handleBrightnessChanged: handleBrightnessChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSwatch(
      cardColor: Color(0xFF1c2834),
      brightness: switch (themeMode) {
        ThemeMode.dark => Brightness.dark,
        _ => Brightness.light,
      },
    );

    return MaterialApp.router(
      title: appName,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xff1967D2),
        brightness: Brightness.light,
        dividerColor: Color(0xFFF5F5F7),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFF5F5F7),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1c2834),
        brightness: Brightness.dark,
        // TODO: delete...
        // textButtonTheme: TextButtonThemeData(
        //   style: TextButton.styleFrom(
        //     foregroundColor: colorScheme.onPrimary,
        //   ),
        // ),
        dividerColor: Color(0xFF1c2834),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF1c2834),
        ),
      ),
    );
  }
}

class DartPadMainPage extends StatefulWidget {
  final String title;
  final String? initialChannel;
  final String? sampleId;
  final String? gistId;
  final bool embedMode;
  final ThemeMode themeMode;
  final void Function(BuildContext, bool) handleBrightnessChanged;

  DartPadMainPage({
    required this.title,
    required this.initialChannel,
    required this.themeMode,
    required this.embedMode,
    required this.handleBrightnessChanged,
    this.sampleId,
    this.gistId,
  }) : super(key: ValueKey('sample:$sampleId gist:$gistId'));

  @override
  State<DartPadMainPage> createState() => _DartPadMainPageState();
}

class _DartPadMainPageState extends State<DartPadMainPage> {
  late final SplitViewController mainSplitter;

  late AppModel appModel;
  late AppServices appServices;

  @override
  void initState() {
    super.initState();

    final leftPanelSize = widget.embedMode ? 0.62 : 0.50;
    mainSplitter =
        SplitViewController(weights: [leftPanelSize, 1.0 - leftPanelSize]);

    final channel = widget.initialChannel != null
        ? Channel.channelForName(widget.initialChannel!)
        : null;

    appModel = AppModel();
    appServices = AppServices(
      appModel,
      channel ?? Channel.defaultChannel,
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
    appModel.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final scaffold = Scaffold(
      appBar: widget.embedMode
          ? null
          : AppBar(
              backgroundColor: theme.dividerColor,
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
                        child: ValueBuilder(
                          appModel.title,
                          (String value) => Text(value),
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
                _BrightnessButton(
                  handleBrightnessChange: widget.handleBrightnessChanged,
                ),
              ],
            ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SplitView(
                viewMode: SplitViewMode.Horizontal,
                gripColor: theme.dividerTheme.color!,
                gripColorActive: theme.dividerTheme.color!,
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
                                themeMode: widget.themeMode,
                              ),
                              Padding(
                                padding: const EdgeInsets.all(denseSpacing),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Format action
                                    ValueBuilder(
                                      appModel.formattingBusy,
                                      (bool value) {
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
                                    ValueBuilder<bool>(
                                      appModel.compilingBusy,
                                      (bool value) {
                                        return PointerInterceptor(
                                          child: RunButton(
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
                  Stack(
                    children: [
                      ValueListenableBuilder(
                        valueListenable: appModel.layoutMode,
                        builder: (context, LayoutMode mode, _) {
                          return LayoutBuilder(builder: (BuildContext context,
                              BoxConstraints constraints) {
                            final domHeight =
                                mode.calcDomHeight(constraints.maxHeight);
                            final consoleHeight =
                                mode.calcConsoleHeight(constraints.maxHeight);

                            return Column(
                              children: [
                                SizedBox(
                                  height: domHeight,
                                  child: ExecutionWidget(
                                    // useMinHeight: mode.domIsVisible ? false : true,
                                    appServices: appServices,
                                  ),
                                ),
                                SizedBox(
                                  height: consoleHeight,
                                  child: ConsoleWidget(
                                    showDivider: mode == LayoutMode.both,
                                    textController:
                                        appModel.consoleOutputController,
                                  ),
                                ),
                              ],
                            );
                          });
                        },
                      ),
                      ValueBuilder(
                        appModel.compilingBusy,
                        (compiling) {
                          final color = theme.colorScheme.backgroundColor;

                          return AnimatedContainer(
                            color: compiling
                                ? color.withOpacity(0.8)
                                : color.withOpacity(0.0),
                            duration: animationDelay,
                            curve: animationCurve,
                            child: compiling
                                ? const GoldenRatioCenter(
                                    child: CircularProgressIndicator(),
                                  )
                                : const SizedBox(width: 1),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!widget.embedMode) const StatusLineWidget(),
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
              // TODO:
              unimplemented(context, 'find');
            },
            keys.findNextKeyActivator: () {
              // TODO:
              unimplemented(context, 'find next');
            },
            keys.codeCompletionKeyActivator: () {
              appServices.editorService?.showCompletions();
            },
            keys.quickFixKeyActivator: () {
              appServices.editorService?.showQuickFixes();
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
    try {
      final value = appModel.sourceCodeController.text;
      final result = await appServices.format(SourceRequest(source: value));

      if (result.source == value) {
        appModel.editorStatus.showToast('No formatting changes');
      } else {
        appModel.editorStatus.showToast('Format successful');
        appModel.sourceCodeController.text = result.source;
      }
    } catch (error) {
      appModel.editorStatus.showToast('Error formatting code');
      appModel.appendLineToConsole('Formatting issue: $error');
      return;
    }
  }

  Future<void> _performCompileAndRun() async {
    final source = appModel.sourceCodeController.text;
    final progress =
        appModel.editorStatus.showMessage(initialText: 'Compiling…');

    try {
      final response =
          await appServices.compileDDC(CompileRequest(source: source));
      appModel.clearConsole();
      appServices.executeJavaScript(
        response.result,
        modulesBaseUrl: response.modulesBaseUrl,
        engineVersion: appModel.runtimeVersions.value?.engineVersion,
      );
    } catch (error) {
      appModel.clearConsole();

      appModel.editorStatus.showToast('Compilation failed');

      if (error is ApiRequestError) {
        appModel.appendLineToConsole(error.message);
        appModel.appendLineToConsole(error.body);
      } else {
        appModel.appendLineToConsole('$error');
      }
    } finally {
      progress.close();
    }
  }
}

class StatusLineWidget extends StatelessWidget {
  const StatusLineWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final darkTheme = colorScheme.darkMode;
    final textColor = colorScheme.onPrimaryContainer;

    final appModel = Provider.of<AppModel>(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.dividerColor,
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

    return Padding(
      padding: const EdgeInsets.all(denseSpacing),
      child: c,
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
    final categories = Samples.categories.keys;

    final menuItems = <PopupMenuEntry<String?>>[
      for (final category in categories) ...[
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
    context.go(
      Uri(path: '/', queryParameters: {'sample': sampleId}).toString(),
    );
  }
}

class SelectChannelWidget extends StatelessWidget {
  const SelectChannelWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final appServices = Provider.of<AppServices>(context);

    return ValueListenableBuilder<Channel>(
      valueListenable: appServices.channel,
      builder: (context, Channel value, _) {
        return SizedBox(
          height: toolbarItemHeight,
          child: TextButton.icon(
            icon: const Icon(Icons.tune, size: smallIconSize),
            label: Container(
              constraints: const BoxConstraints(minWidth: 95),
              child: Text('${value.displayName} channel'),
            ),
            onPressed: () async {
              final selection = await _showMenu(
                context,
                calculatePopupMenuPosition(context, growUpwards: true),
                value,
              );
              if (selection != null && context.mounted) {
                _handleSelection(context, selection);
              }
            },
          ),
        );
      },
    );
  }

  Future<Channel?> _showMenu(
      BuildContext context, RelativeRect position, Channel current) {
    const itemHeight = 46.0;

    final menuItems = <PopupMenuEntry<Channel>>[
      for (final channel in Channel.valuesWithoutLocalhost)
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
    final appServices = Provider.of<AppServices>(context, listen: false);

    appServices.setChannel(channel);

    // update the url
    // TODO: preserve id? sample? theme?
    context.go(
      Uri(path: '/', queryParameters: {'channel': channel.name}).toString(),
    );
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
  final ValueListenable<VersionResponse?> versions;

  const VersionInfoWidget(
    this.versions, {
    super.key,
  });

  @override
  State<VersionInfoWidget> createState() => _VersionInfoWidgetState();
}

class _VersionInfoWidgetState extends State<VersionInfoWidget> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VersionResponse?>(
      valueListenable: widget.versions,
      builder: (content, versions, _) {
        if (versions == null) {
          return const SizedBox();
        }

        return TextButton(
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (context) {
                return MediumDialog(
                  title: 'Runtime Versions',
                  child: VersionTable(version: versions),
                );
              },
            );
          },
          child: Text(versions.label),
        );
      },
    );
  }
}

class _BrightnessButton extends StatelessWidget {
  const _BrightnessButton({
    required this.handleBrightnessChange,
    this.showTooltipBelow = true,
  });

  final void Function(BuildContext, bool) handleBrightnessChange;
  final bool showTooltipBelow;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      preferBelow: showTooltipBelow,
      message: 'Toggle brightness',
      child: IconButton(
        icon: Theme.of(context).brightness == Brightness.light
            ? const Icon(Icons.dark_mode_outlined)
            : const Icon(Icons.light_mode_outlined),
        onPressed: () {
          final isBright = Theme.of(context).brightness == Brightness.light;
          handleBrightnessChange(context, !isBright);
        },
      ),
    );
  }
}

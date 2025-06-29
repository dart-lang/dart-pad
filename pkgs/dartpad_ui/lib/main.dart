// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_shared/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart' show usePathUrlStrategy;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:split_view/split_view.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:vtable/vtable.dart';

import 'app/console.dart';
import 'app/embed/embed.dart';
import 'app/execution/execution.dart';
import 'app/genai_dialogs.dart';
import 'app/genai_editing.dart';
import 'app/simple_widgets.dart';
import 'model/keys.dart' as keys;
import 'model/model.dart';
import 'primitives/enable_gen_ai.dart';
import 'primitives/extensions.dart';
import 'primitives/local_storage/local_storage.dart';
import 'primitives/samples.g.dart';
import 'primitives/theme.dart';
import 'primitives/versions.dart';

const appName = 'DartPad';

// Smallest screen width when the screen is considered to be a large screen.
const minLargeScreenWidth = 866.0;

void main() async {
  usePathUrlStrategy();

  // Make sure that the google fonts don't load from http.
  GoogleFonts.config.allowRuntimeFetching = false;

  runApp(const DartPadApp());
}

class DartPadApp extends StatefulWidget {
  const DartPadApp({super.key, this.channel});

  /// If initialized, will override URL parameter for channel.
  @visibleForTesting
  final String? channel;

  @override
  State<DartPadApp> createState() => _DartPadAppState();
}

class _DartPadAppState extends State<DartPadApp> {
  late final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: _homePageBuilder),
      GoRoute(
        path: '/:gistId',
        builder: (context, state) => _homePageBuilder(
          context,
          state,
          gist: state.pathParameters['gistId'],
        ),
      ),
    ],
  );

  ThemeMode themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();

    router.routeInformationProvider.addListener(_setTheme);
    _setTheme();
  }

  @override
  void dispose() {
    router.routeInformationProvider.removeListener(_setTheme);

    super.dispose();
  }

  // Changes the `themeMode` from the system default to either light or dark.
  // Also changes the `theme` query parameter in the URL.
  void handleBrightnessChanged(BuildContext context, bool isLightMode) {
    if (isLightMode) {
      GoRouter.of(context).replaceQueryParam('theme', 'light');
    } else {
      GoRouter.of(context).replaceQueryParam('theme', 'dark');
    }
    _setTheme();
  }

  void _setTheme() {
    final params = router.routeInformationProvider.value.uri.queryParameters;
    final themeParam = params.containsKey('theme') ? params['theme'] : null;

    setState(() {
      switch (themeParam) {
        case 'dark':
          setState(() {
            themeMode = ThemeMode.dark;
          });
        case 'light':
          setState(() {
            themeMode = ThemeMode.light;
          });
        case _:
          setState(() {
            themeMode = ThemeMode.dark;
          });
      }
    });
  }

  Widget _homePageBuilder(
    BuildContext context,
    GoRouterState state, {
    String? gist,
  }) {
    final gistId = gist ?? state.uri.queryParameters['id'];
    final builtinSampleId = state.uri.queryParameters['sample'];
    final flutterSampleId = state.uri.queryParameters['sample_id'];
    final channelParam = widget.channel ?? state.uri.queryParameters['channel'];
    final embedMode = state.uri.queryParameters['embed'] == 'true';
    final runOnLoad = state.uri.queryParameters['run'] == 'true';

    return DartPadMainPage(
      initialChannel: channelParam,
      embedMode: embedMode,
      runOnLoad: runOnLoad,
      gistId: gistId,
      builtinSampleId: builtinSampleId,
      flutterSampleId: flutterSampleId,
      handleBrightnessChanged: handleBrightnessChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: appName,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: lightPrimaryColor,
          surface: lightSurfaceColor,
          onSurface: Colors.black,
          surfaceContainerHighest: lightSurfaceVariantColor,
          onPrimary: lightLinkButtonColor,
        ),
        brightness: Brightness.light,
        dividerColor: lightDividerColor,
        dividerTheme: const DividerThemeData(color: lightDividerColor),
        scaffoldBackgroundColor: Colors.white,
        menuButtonTheme: MenuButtonThemeData(
          style: MenuItemButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
        ),
        hintColor: Colors.black.withAlpha(128),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: darkPrimaryColor,
          brightness: Brightness.dark,
          surface: darkSurfaceColor,
          onSurface: Colors.white,
          surfaceContainerHighest: darkSurfaceVariantColor,
          onSurfaceVariant: Colors.white,
          onPrimary: darkLinkButtonColor,
        ),
        brightness: Brightness.dark,
        dividerColor: darkDividerColor,
        dividerTheme: const DividerThemeData(color: darkDividerColor),
        textButtonTheme: const TextButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(darkLinkButtonColor),
          ),
        ),
        iconButtonTheme: const IconButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(darkLinkButtonColor),
          ),
        ),
        scaffoldBackgroundColor: darkScaffoldColor,
        menuButtonTheme: MenuButtonThemeData(
          style: MenuItemButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
        ),
        hintColor: Colors.white.withAlpha(128),
      ),
    );
  }
}

class DartPadMainPage extends StatefulWidget {
  final String? initialChannel;
  final bool embedMode;
  final bool runOnLoad;
  final void Function(BuildContext, bool) handleBrightnessChanged;
  final String? gistId;
  final String? builtinSampleId;
  final String? flutterSampleId;

  DartPadMainPage({
    required this.initialChannel,
    required this.embedMode,
    required this.runOnLoad,
    required this.handleBrightnessChanged,
    this.gistId,
    this.builtinSampleId,
    this.flutterSampleId,
  }) : super(
         key: ValueKey(
           'sample:$builtinSampleId gist:$gistId flutter:$flutterSampleId',
         ),
       );

  @override
  State<DartPadMainPage> createState() => DartPadMainPageState();
}

@visibleForTesting
class DartPadMainPageState extends State<DartPadMainPage>
    with SingleTickerProviderStateMixin {
  late final AppModel appModel;
  late final AppServices appServices;
  late final SplitViewController mainSplitter;
  late final SplitViewController consoleSplitter;
  late final TabController tabController;
  final initialized = Completer<void>();

  final GlobalKey _executionWidgetKey = GlobalKey(
    debugLabel: 'execution-widget',
  );
  final ValueKey<String> _loadingOverlayKey = const ValueKey(
    'loading-overlay-widget',
  );
  final ValueKey<String> _editorKey = const ValueKey('editor');
  final ValueKey<String> _consoleKey = const ValueKey('console');
  final ValueKey<String> _tabBarKey = const ValueKey('tab-bar');
  final ValueKey<String> _executionStackKey = const ValueKey('execution-stack');
  final ValueKey<String> _scaffoldKey = const ValueKey('scaffold');

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        // Rebuild when the user changes tabs so that the IndexedStack updates
        // its active child view.
        setState(() {});
      });

    final leftPanelSize = widget.embedMode ? 0.62 : 0.50;
    mainSplitter =
        SplitViewController(weights: [leftPanelSize, 1.0 - leftPanelSize])
          ..addListener(() {
            appModel.splitDragStateManager.handleSplitChanged();
          });

    consoleSplitter =
        SplitViewController(
          weights: [0.7, 0.3],
          limits: [WeightLimit(max: 0.9), WeightLimit(min: 0.1)],
        )..addListener(() {
          appModel.splitDragStateManager.handleSplitChanged();
        });

    final channel = widget.initialChannel != null
        ? Channel.forName(widget.initialChannel!)
        : null;

    appModel = AppModel();
    appServices = AppServices(appModel, channel ?? Channel.defaultChannel);

    appModel.compilingState.addListener(_handleRunStarted);

    tabController.addListener(() {
      // Refresh the editor if switching to the code editor tab,
      // to allow CodeMirror to update its custom rendering.
      if (tabController.index == 0) {
        appServices.editorService?.refreshViewAfterWait();
      }
    });

    await Future.wait([
      appServices.populateVersions(),
      appServices
          .performInitialLoad(
            gistId: widget.gistId,
            sampleId: widget.builtinSampleId,
            flutterSampleId: widget.flutterSampleId,
            channel: widget.initialChannel,
            keybinding: DartPadLocalStorage.instance.getUserKeybinding(),
            getFallback: () =>
                DartPadLocalStorage.instance.getUserCode() ??
                Samples.defaultSnippet(),
          )
          .then((value) {
            // Start listening for inject code messages.
            handleEmbedMessage(appServices, runOnInject: widget.runOnLoad);
            if (widget.runOnLoad) {
              appServices.performCompileAndRun();
            }
          }),
    ]);

    initialized.complete();
  }

  @override
  void dispose() {
    appModel.compilingState.removeListener(_handleRunStarted);

    appServices.dispose();
    appModel.dispose();

    tabController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final executionWidget = ExecutionWidget(
      appServices: appServices,
      appModel: appModel,
      key: _executionWidgetKey,
    );

    final loadingOverlay = LoadingOverlay(
      appModel: appModel,
      key: _loadingOverlayKey,
    );

    final editor = EditorWithButtons(
      appModel: appModel,
      appServices: appServices,
      onFormat: _handleFormatting,
      onCompileAndRun: appServices.performCompileAndRun,
      onCompileAndReload: appServices.performCompileAndReload,
      key: _editorKey,
    );

    final tabBar = TabBar(
      controller: tabController,
      tabs: const [
        Tab(text: 'Code'),
        Tab(text: 'Output'),
      ],
      // Remove the divider line at the bottom of the tab bar.
      dividerHeight: 0,
      key: _tabBarKey,
    );

    final executionStack = Stack(
      key: _executionStackKey,
      children: [
        ValueListenableBuilder(
          valueListenable: appModel.layoutMode,
          builder: (context, LayoutMode mode, _) {
            return switch (mode) {
              LayoutMode.both => SplitView(
                viewMode: SplitViewMode.Vertical,
                gripColor: theme.colorScheme.surface,
                gripColorActive: theme.colorScheme.surface,
                gripSize: defaultGripSize,
                controller: consoleSplitter,
                children: [
                  executionWidget,
                  ConsoleWidget(
                    key: _consoleKey,
                    output: appModel.consoleNotifier,
                  ),
                ],
              ),
              LayoutMode.justDom => executionWidget,
              LayoutMode.justConsole => Column(
                children: [
                  SizedBox(height: 0, width: 0, child: executionWidget),
                  Expanded(
                    child: ConsoleWidget(
                      key: _consoleKey,
                      output: appModel.consoleNotifier,
                    ),
                  ),
                ],
              ),
            };
          },
        ),
        loadingOverlay,
      ],
    );

    final scaffold = LayoutBuilder(
      builder: (context, constraints) {
        // Use the mobile UI layout for small screen widths.
        if (constraints.maxWidth < minLargeScreenWidth) {
          return Scaffold(
            key: _scaffoldKey,
            appBar: widget.embedMode
                ? tabBar
                : DartPadAppBar(
                    theme: theme,
                    appServices: appServices,
                    appModel: appModel,
                    widget: widget,
                    bottom: tabBar,
                  ),
            body: Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: tabController.index,
                    children: [editor, executionStack],
                  ),
                ),
                if (!widget.embedMode)
                  const StatusLineWidget(mobileVersion: true),
              ],
            ),
          );
        } else {
          // Return the desktop UI.
          return Scaffold(
            key: _scaffoldKey,
            appBar: widget.embedMode
                ? null
                : DartPadAppBar(
                    theme: theme,
                    appServices: appServices,
                    appModel: appModel,
                    widget: widget,
                  ),
            body: Column(
              children: [
                Expanded(
                  child: SplitView(
                    viewMode: SplitViewMode.Horizontal,
                    gripColor: theme.colorScheme.surface,
                    gripColorActive: theme.colorScheme.surface,
                    gripSize: defaultGripSize,
                    controller: mainSplitter,
                    children: [editor, executionStack],
                  ),
                ),
                if (!widget.embedMode) const StatusLineWidget(),
              ],
            ),
          );
        }
      },
    );

    return Provider<AppServices>.value(
      value: appServices,
      child: Provider<AppModel>.value(
        value: appModel,
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            keys.runKeyActivator1: () {
              if (!appModel.compilingState.value.busy) {
                appServices.performCompileAndRun();
              }
            },
            keys.runKeyActivator2: () {
              if (!appModel.compilingState.value.busy) {
                appServices.performCompileAndRun();
              }
            },
            // keys.findKeyActivator: () {
            //   // TODO:
            //   unimplemented(context, 'find');
            // },
            // keys.findNextKeyActivator: () {
            //   // TODO:
            //   unimplemented(context, 'find next');
            // },
            keys.formatKeyActivator1: () {
              if (!appModel.formattingBusy.value) _handleFormatting();
            },
            keys.formatKeyActivator2: () {
              if (!appModel.formattingBusy.value) _handleFormatting();
            },
            keys.codeCompletionKeyActivator: () {
              appServices.editorService?.showCompletions(autoInvoked: false);
            },
            keys.quickFixKeyActivator1: () {
              appServices.editorService?.showQuickFixes();
            },
            keys.quickFixKeyActivator2: () {
              appServices.editorService?.showQuickFixes();
            },
          },
          child: Focus(autofocus: true, child: scaffold),
        ),
      ),
    );
  }

  Future<void> _handleFormatting() async {
    try {
      final source = appModel.sourceCodeController.text;
      final offset = appServices.editorService?.cursorOffset;
      final result = await appServices.format(
        SourceRequest(source: source, offset: offset),
      );

      if (result.source == source) {
        appModel.editorStatus.showToast('No formatting changes');
      } else {
        appModel.editorStatus.showToast('Format successful');
        appModel.sourceCodeController.value = TextEditingValue(
          text: result.source,
          selection: TextSelection.collapsed(offset: result.offset ?? 0),
        );
      }

      appServices.editorService!.focus();
    } catch (error) {
      appModel.editorStatus.showToast('Error formatting code');
      appModel.appendError('Formatting issue: $error');
      return;
    }
  }

  void _handleRunStarted() {
    setState(() {
      // Switch to the application output tab.]
      if (appModel.compilingState.value != CompilingState.none) {
        tabController.animateTo(1);
      }
    });
  }
}

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key, required this.appModel});

  final AppModel appModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<GenAiActivity?>(
      valueListenable: appModel.genAiManager.activity,
      builder:
          (BuildContext context, GenAiActivity? genAiActivity, Widget? child) {
            return ValueListenableBuilder<CompilingState>(
              valueListenable: appModel.compilingState,
              builder: (_, compilingState, _) {
                final color = theme.colorScheme.surface;
                final loading =
                    compilingState == CompilingState.restarting ||
                    genAiActivity == GenAiActivity.generating;

                // If reloading, show a progress spinner. If restarting,
                // also display a semi-opaque overlay.
                return AnimatedContainer(
                  color: color.withValues(alpha: loading ? 0.8 : 0),
                  duration: animationDelay,
                  curve: animationCurve,
                  child: loading
                      ? const GoldenRatioCenter(
                          child: CircularProgressIndicator(),
                        )
                      : const SizedBox(width: 1),
                );
              },
            );
          },
    );
  }
}

class DartPadAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DartPadAppBar({
    super.key,
    required this.theme,
    required this.appServices,
    required this.appModel,
    required this.widget,
    this.bottom,
  });

  final ThemeData theme;
  final AppServices appServices;
  final AppModel appModel;
  final DartPadMainPage widget;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wideLayout = constraints.maxWidth >= minLargeScreenWidth;

        List<Widget> geminiMenuWidgets(
          double spacing, {
          bool hideLabel = false,
        }) {
          if (!genAiEnabled) return <Widget>[];
          return [
            SizedBox(width: spacing),
            GeminiMenu(
              generateNewDartCode: () => openCodeGenerationDialog(
                context,
                appType: AppType.dart,
                reuseLastPrompt: false,
              ),
              generateNewFlutterCode: () => openCodeGenerationDialog(
                context,
                appType: AppType.flutter,
                reuseLastPrompt: false,
              ),
              hideLabel: hideLabel, // !wideLayout,
            ),
          ];
        }

        return AppBar(
          backgroundColor: theme.colorScheme.surface,
          title: SizedBox(
            height: toolbarItemHeight,
            child: Row(
              children: [
                const Logo(width: 32, type: 'dart'),
                const SizedBox(width: denseSpacing),
                Text(
                  appName,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                // Hide new snippet buttons when the screen width is too small.
                if (wideLayout) ...[
                  const SizedBox(width: defaultSpacing * 4),
                  NewSnippetWidget(appServices: appServices),
                  ...geminiMenuWidgets(denseSpacing),
                  const SizedBox(width: denseSpacing),
                  const ListSamplesWidget(),
                ] else ...[
                  const SizedBox(width: defaultSpacing),
                  NewSnippetWidget(appServices: appServices, hideLabel: true),
                  ...geminiMenuWidgets(defaultSpacing, hideLabel: true),
                  const SizedBox(width: denseSpacing),
                  const ListSamplesWidget(hideLabel: true),
                ],

                const SizedBox(width: defaultSpacing),
                // Hide the snippet title when the screen width is too small.
                if (wideLayout)
                  Expanded(
                    child: Center(
                      child: ValueListenableBuilder<String>(
                        valueListenable: appModel.title,
                        builder: (_, String value, _) => Text(value),
                      ),
                    ),
                  ),
                const SizedBox(width: defaultSpacing),
              ],
            ),
          ),
          bottom: bottom,
          actions: [
            // Hide the Install SDK button when the screen width is too small.
            if (constraints.maxWidth >= minLargeScreenWidth)
              ContinueInMenu(openInFirebaseStudio: _openInFirebaseStudio),
            const SizedBox(width: denseSpacing),
            _BrightnessButton(
              handleBrightnessChange: widget.handleBrightnessChanged,
            ),
            const OverflowMenu(),
          ],
        );
      },
    );
  }

  @override
  // kToolbarHeight is set to 56.0 in the framework.
  Size get preferredSize => bottom == null
      ? const Size(double.infinity, 56.0)
      : const Size(double.infinity, 112.0);

  Future<void> _openInFirebaseStudio() async {
    final code = appModel.sourceCodeController.text;
    final request = OpenInFirebaseStudioRequest(code: code);
    final response = await appServices.services.openInFirebaseStudio(request);
    url_launcher.launchUrl(Uri.parse(response.firebaseStudioUrl));
  }
}

class StatusLineWidget extends StatelessWidget {
  final bool mobileVersion;

  const StatusLineWidget({this.mobileVersion = false, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final appModel = Provider.of<AppModel>(context);

    return Container(
      decoration: BoxDecoration(color: theme.colorScheme.surface),
      padding: const EdgeInsets.symmetric(
        vertical: denseSpacing,
        horizontal: defaultSpacing,
      ),
      child: Row(
        children: [
          Tooltip(
            message: 'Keyboard shortcuts',
            waitDuration: tooltipDelay,
            child: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => MediumDialog(
                  title: 'Keyboard shortcuts',
                  smaller: true,
                  child: KeyBindingsTable(
                    bindings: keys.keyBindings,
                    appModel: appModel,
                  ),
                ),
              ),
              child: Icon(
                Icons.keyboard,
                color: Theme.of(context).colorScheme.onPrimary,
                size: iconSizeMedium,
              ),
            ),
          ),
          const SizedBox(width: defaultSpacing),
          if (!mobileVersion)
            TextButton(
              onPressed: () {
                const url = 'https://dart.dev/tools/dartpad/privacy';
                url_launcher.launchUrl(Uri.parse(url));
              },
              child: const Row(
                children: [
                  Text('Privacy notice'),
                  SizedBox(width: denseSpacing),
                  Icon(Icons.launch, size: iconSizeSmall),
                ],
              ),
            ),
          const SizedBox(width: defaultSpacing),
          if (!mobileVersion)
            TextButton(
              onPressed: () {
                const url = 'https://github.com/dart-lang/dart-pad/issues';
                url_launcher.launchUrl(Uri.parse(url));
              },
              child: const Row(
                children: [
                  Text('Feedback'),
                  SizedBox(width: denseSpacing),
                  Icon(Icons.launch, size: iconSizeSmall),
                ],
              ),
            ),
          const Expanded(child: SizedBox(width: defaultSpacing)),
          VersionInfoWidget(appModel.runtimeVersions),
          const SizedBox(width: denseSpacing),
          SelectChannelWidget(hideLabel: mobileVersion),
        ],
      ),
    );
  }
}

class NewSnippetWidget extends StatelessWidget {
  final AppServices appServices;
  final bool hideLabel;

  static const _menuItems = [
    (label: 'Dart snippet', icon: Logo(type: 'dart'), kind: 'dart'),
    (label: 'Flutter snippet', icon: Logo(type: 'flutter'), kind: 'flutter'),
  ];

  const NewSnippetWidget({
    required this.appServices,
    this.hideLabel = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (_, MenuController controller, _) => CollapsibleIconToggleButton(
        icon: const Icon(Icons.add_circle),
        label: const Text('Create'),
        tooltip: 'Create a new snippet',
        hideLabel: hideLabel,
        onToggle: controller.toggle,
      ),
      menuChildren: [
        for (final item in _menuItems)
          PointerInterceptor(
            child: MenuItemButton(
              leadingIcon: item.icon,
              child: Padding(
                padding: const EdgeInsets.only(right: 32),
                child: Text(item.label),
              ),
              onPressed: () => appServices.resetTo(type: item.kind),
            ),
          ),
      ],
    );
  }
}

class ListSamplesWidget extends StatelessWidget {
  final bool hideLabel;
  const ListSamplesWidget({this.hideLabel = false, super.key});

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (_, MenuController controller, _) => CollapsibleIconToggleButton(
        icon: const Icon(Icons.playlist_add_outlined),
        label: const Text('Samples'),
        tooltip: 'Try out a sample',
        hideLabel: hideLabel,
        onToggle: controller.toggle,
      ),
      menuChildren: _buildMenuItems(context),
    );
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    final menuItems = [
      for (final MapEntry(key: category, value: samples)
          in Samples.categories.entries) ...[
        MenuItemButton(
          onPressed: null,
          child: Text(category, style: Theme.of(context).textTheme.bodyLarge),
        ),
        for (final sample in samples)
          MenuItemButton(
            leadingIcon: Logo(type: sample.icon),
            onPressed: () =>
                GoRouter.of(context).replaceQueryParam('sample', sample.id),
            child: Padding(
              padding: const EdgeInsets.only(right: 32),
              child: Text(sample.name),
            ),
          ),
      ],
    ];

    return menuItems.map((e) => PointerInterceptor(child: e)).toList();
  }
}

class SelectChannelWidget extends StatelessWidget {
  const SelectChannelWidget({super.key, this.hideLabel = false});

  final bool hideLabel;

  @override
  Widget build(BuildContext context) {
    final appServices = Provider.of<AppServices>(context);
    final channels = Channel.valuesWithoutLocalhost;

    return ValueListenableBuilder<Channel>(
      valueListenable: appServices.channel,
      builder: (context, Channel value, _) => MenuAnchor(
        builder: (_, controller, _) => CollapsibleIconToggleButton(
          icon: const Icon(Icons.tune, size: smallIconSize),
          label: Text('${value.displayName} channel'),
          tooltip: 'Switch channels',
          hideLabel: hideLabel,
          compact: true,
          onToggle: controller.toggle,
        ),
        menuChildren: [
          for (final channel in channels)
            PointerInterceptor(
              child: MenuItemButton(
                onPressed: () => _onTap(context, channel),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 32, 0),
                  child: Text('${channel.displayName} channel'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onTap(BuildContext context, Channel channel) async {
    final appServices = Provider.of<AppServices>(context, listen: false);

    // update the url
    GoRouter.of(context).replaceQueryParam('channel', channel.name);

    final version = await appServices.setChannel(channel);

    appServices.appModel.editorStatus.showToast(
      'Switched to Dart ${version.dartVersion} '
      'and Flutter ${version.flutterVersion}',
    );
  }
}

class OverflowMenu extends StatelessWidget {
  const OverflowMenu({super.key});

  static const _menuItems = [
    (label: 'Install SDK', uri: 'https://flutter.dev/get-started'),
    (
      label: 'Sharing guide',
      uri: 'https://github.com/dart-lang/dart-pad/wiki/Sharing-Guide',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, MenuController controller, Widget? child) {
        return IconButton(
          onPressed: () => controller.toggle(),
          icon: const Icon(Icons.more_vert),
        );
      },
      menuChildren: [
        for (final item in _menuItems)
          PointerInterceptor(
            child: MenuItemButton(
              trailingIcon: const Icon(Icons.launch),
              onPressed: () => _onSelected(context, item.uri),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 32, 0),
                child: Text(item.label),
              ),
            ),
          ),
      ],
    );
  }

  void _onSelected(BuildContext context, String uri) {
    url_launcher.launchUrl(Uri.parse(uri));
  }
}

class ContinueInMenu extends StatelessWidget {
  final VoidCallback openInFirebaseStudio;

  const ContinueInMenu({super.key, required this.openInFirebaseStudio});

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, MenuController controller, Widget? child) {
        return TextButton.icon(
          onPressed: () => controller.toggle(),
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('Open in'),
        );
      },
      menuChildren: [
        PointerInterceptor(
          child: MenuItemButton(
            trailingIcon: const Logo(type: 'firebase_studio'),
            onPressed: openInFirebaseStudio,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(0, 0, 32, 0),
              child: Text('Firebase Studio'),
            ),
          ),
        ),
      ],
    );
  }
}

class GeminiMenu extends StatelessWidget {
  const GeminiMenu({
    required this.generateNewDartCode,
    required this.generateNewFlutterCode,
    required this.hideLabel,
    super.key,
  });

  final bool hideLabel;
  final VoidCallback generateNewDartCode;
  final VoidCallback generateNewFlutterCode;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/gemini_sparkle_192.png',
      width: iconSizeLarge,
      height: iconSizeLarge,
    );

    Widget menu(String text) {
      return Padding(padding: EdgeInsets.only(right: 32), child: Text(text));
    }

    return MenuAnchor(
      builder: (_, MenuController controller, _) => CollapsibleIconToggleButton(
        icon: image,
        label: const Text('Create with Gemini'),
        tooltip: 'Generate code with Gemini',
        hideLabel: hideLabel,
        onToggle: controller.toggle,
      ),
      menuChildren: [
        ...[
          MenuItemButton(
            leadingIcon: image,
            onPressed: generateNewDartCode,
            child: menu('Dart Snippet'),
          ),
          MenuItemButton(
            leadingIcon: image,
            onPressed: generateNewFlutterCode,
            child: menu('Flutter Snippet'),
          ),
        ].map((widget) => PointerInterceptor(child: widget)),
      ],
    );
  }
}

class KeyBindingsTable extends StatelessWidget {
  final List<(String, List<ShortcutActivator>)> bindings;
  final AppModel appModel;

  const KeyBindingsTable({
    required this.bindings,
    required this.appModel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Expanded(
          child: VTable<(String, List<ShortcutActivator>)>(
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
                styleFunction: (binding) => subtleText,
                renderFunction: (context, binding, _) {
                  final children = <Widget>[];
                  var first = true;
                  for (final shortcut in binding.$2) {
                    if (!first) {
                      children.add(
                        const Padding(
                          padding: EdgeInsets.only(left: 4, right: 8),
                          child: Text(','),
                        ),
                      );
                    }
                    first = false;
                    children.add(
                      (shortcut as SingleActivator).renderToWidget(context),
                    );
                  }
                  return Row(children: children);
                },
              ),
            ],
          ),
        ),
        const Divider(),
        _VimModeSwitch(appModel: appModel),
      ],
    );
  }
}

class VersionInfoWidget extends StatefulWidget {
  final ValueListenable<VersionResponse?> versions;

  const VersionInfoWidget(this.versions, {super.key});

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
                  title: 'Runtime versions',
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
  const _BrightnessButton({required this.handleBrightnessChange});

  final void Function(BuildContext, bool) handleBrightnessChange;

  @override
  Widget build(BuildContext context) {
    final isBright = Theme.of(context).brightness == Brightness.light;
    return Tooltip(
      preferBelow: true,
      message: 'Toggle brightness',
      child: IconButton(
        icon: Theme.of(context).brightness == Brightness.light
            ? const Icon(Icons.dark_mode_outlined)
            : const Icon(Icons.light_mode_outlined),
        onPressed: () {
          handleBrightnessChange(context, !isBright);
        },
      ),
    );
  }
}

class _VimModeSwitch extends StatelessWidget {
  final AppModel appModel;

  const _VimModeSwitch({required this.appModel});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: appModel.vimKeymapsEnabled,
      builder: (BuildContext context, bool value, Widget? child) {
        return SwitchListTile(
          value: value,
          title: const Text('Use Vim key bindings'),
          onChanged: _handleToggle,
        );
      },
    );
  }

  void _handleToggle(bool value) {
    appModel.vimKeymapsEnabled.value = value;
  }
}

// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../../startup/example.dart';
import '../../startup/examples.g.dart';
import '../icons.dart';
import 'dropdown_menu.dart';
import 'icon_button.dart' as dp;
import 'theme_toggle.dart';

/// The main application bar with the DartPad logo, title, theme toggle, and
/// overflow menu.
class AppBar extends StatefulComponent {
  const AppBar({
    this.onCreateNewSnippet,
    this.onLoadSample,
    this.isMobile = false,
    this.isEmbedMode = false,
    this.selectedTab = 0,
    this.onTabSelected,
    super.key,
  });

  /// Called when the user selects a snippet from the Create menu.
  final void Function(Example example)? onCreateNewSnippet;

  /// Called when the user selects a sample from the sample menu.
  final void Function(Example example)? onLoadSample;

  /// Whether the app bar is being rendered in mobile (compact) layout mode.
  final bool isMobile;

  /// Whether the application is running in embed mode.
  final bool isEmbedMode;

  /// The active mobile tab index (0 = Code, 1 = Output).
  final int selectedTab;

  /// Called when the active mobile tab is switched.
  final void Function(int tab)? onTabSelected;

  @override
  State<AppBar> createState() => _AppBarState();

  @css
  static List<StyleRule> get styles => _AppBarState.styles;
}

class _AppBarState extends State<AppBar> {
  void _openLink(String uri) {
    web.window.open(uri, '_blank');
  }

  List<DropdownMenuEntry> _buildExampleItems() {
    final entries = <DropdownMenuEntry>[];
    String? lastSubcategory;

    for (final example in Examples.samples) {
      if (example.subcategory != null && example.subcategory != lastSubcategory) {
        entries.add(DropdownMenuDivider(label: example.subcategory!));
        lastSubcategory = example.subcategory;
      }
      entries.add(
        DropdownMenuItem(
          label: example.name,
          leadingImage: example.icon,
          onPressed: () => component.onLoadSample?.call(example),
        ),
      );
    }

    return entries;
  }

  @override
  Component build(BuildContext context) {
    final isCreateDisabled = component.onCreateNewSnippet == null;
    final isSamplesDisabled = component.onLoadSample == null;
    final isMobile = component.isMobile;

    if (component.isEmbedMode && !isMobile) {
      return const Component.fragment([]);
    }

    final tabBar = div(classes: 'app-bar-tab-bar', [
      button(
        classes: 'app-bar-tab ${component.selectedTab == 0 ? 'active' : ''}',
        events: {'click': (_) => component.onTabSelected?.call(0)},
        attributes: const {'type': 'button'},
        const [
          span(classes: 'app-bar-tab-label', [Component.text('Code')]),
        ],
      ),
      button(
        classes: 'app-bar-tab ${component.selectedTab == 1 ? 'active' : ''}',
        events: {'click': (_) => component.onTabSelected?.call(1)},
        attributes: const {'type': 'button'},
        const [
          span(classes: 'app-bar-tab-label', [Component.text('Output')]),
        ],
      ),
    ]);

    if (component.isEmbedMode) {
      return tabBar;
    }

    return div(classes: 'app-bar-container', [
      div(classes: 'app-bar', [
        // Left section: logo + title + create + samples.
        div(classes: 'app-bar-left', [
          const img(
            src: 'images/dart_logo_192.png',
            alt: 'Dart',
            classes: 'app-bar-logo',
          ),
          const span(classes: 'app-bar-title', [.text('DartPad')]),
          const div(classes: 'app-bar-divider', []),
          DropdownMenu(
            alignLeft: true,
            disabled: isCreateDisabled,
            trigger: button(
              classes: 'app-bar-text-button',
              disabled: isCreateDisabled,
              attributes: {
                'aria-label': 'Create a new snippet',
                'title': 'Create a new snippet',
              },
              [
                const Icon('add_circle', size: 18),
                if (!isMobile) const span(classes: 'app-bar-button-label', [.text('Create')]),
              ],
            ),
            items: [
              for (final example in Examples.snippets)
                DropdownMenuItem(
                  label: example.name,
                  leadingImage: example.icon,
                  onPressed: () => component.onCreateNewSnippet?.call(example),
                ),
            ],
          ),
          DropdownMenu(
            alignLeft: true,
            disabled: isSamplesDisabled,
            trigger: button(
              classes: 'app-bar-text-button',
              disabled: isSamplesDisabled,
              attributes: {
                'aria-label': 'Samples',
                'title': 'Try a sample',
              },
              [
                const Icon('playlist_add', size: 18),
                if (!isMobile) const span(classes: 'app-bar-button-label', [.text('Samples')]),
              ],
            ),
            items: _buildExampleItems(),
          ),
        ]),
        // Spacer.
        const div(classes: 'app-bar-spacer', []),
        // Right section: theme toggle + overflow menu.
        div(classes: 'app-bar-right', [
          const ThemeToggle(),
          DropdownMenu(
            trigger: const dp.IconButton(
              icon: 'more_vert',
              tooltip: 'More options',
              label: 'More options',
            ),
            items: [
              DropdownMenuItem(
                label: 'Install SDK',
                trailingIcon: 'launch',
                onPressed: () => _openLink('https://flutter.dev/get-started'),
              ),
              DropdownMenuItem(
                label: 'Sharing guide',
                trailingIcon: 'launch',
                onPressed: () => _openLink(
                  'https://github.com/dart-lang/dart-pad/wiki/Sharing-Guide',
                ),
              ),
            ],
          ),
        ]),
      ]),
    ]);
  }

  static List<StyleRule> get styles => [
    css('.app-bar-container').styles(
      display: .flex,
      position: const .relative(),
      zIndex: const ZIndex(200),
      flexDirection: .column,
      flex: const .shrink(0),
    ),
    css('.app-bar').styles(
      display: .flex,
      position: const .relative(),
      zIndex: const ZIndex(200),
      height: 48.px,
      minHeight: 48.px,
      padding: .symmetric(horizontal: 12.px),
      border: .only(
        bottom: .solid(color: colorBorder, width: 1.px),
      ),
      alignItems: .center,
      gap: Gap.all(8.px),
      flex: const .shrink(0),
      backgroundColor: colorSurface,
    ),
    css('.app-bar-left').styles(
      display: .flex,
      position: const .relative(),
      zIndex: const ZIndex(99),
      alignItems: .center,
      gap: Gap.all(8.px),
    ),
    css('.app-bar-spacer').styles(
      flex: const Flex(grow: 1),
    ),
    css('.app-bar-tab-bar').styles(
      display: .flex,
      height: 40.px,
      minHeight: 40.px,
      border: .only(
        bottom: .solid(color: colorBorder, width: 2.px),
      ),
      alignItems: .center,
      backgroundColor: colorSurface,
    ),
    css('.app-bar-tab').styles(
      display: .flex,
      position: const .relative(),
      height: 100.percent,
      padding: .zero,
      border: .none,
      cursor: .pointer,
      justifyContent: .center,
      alignItems: .center,
      flex: const Flex(grow: 1, basis: .zero),
      color: colorOnSurface,
      fontSize: 14.px,
      fontWeight: .w500,
      backgroundColor: Colors.transparent,
    ),
    css('.app-bar-tab:hover').styles(
      backgroundColor: colorSurface.highlight(colorOnSurface, 0.04),
    ),
    css('.app-bar-tab.active').styles(
      color: colorPrimary,
      fontWeight: .w600,
    ),
    css('.app-bar-tab.active::after').styles(
      content: '',
      position: .absolute(bottom: 0.px, left: 50.percent),
      width: 48.px,
      height: 3.px,
      radius: .circular(2.px),
      backgroundColor: colorPrimary,
      raw: {'transform': 'translateX(-50%)'},
    ),
    css('.app-bar-tab-label').styles(
      whiteSpace: .noWrap,
    ),
    css('.app-bar-right').styles(
      display: .flex,
      position: const .relative(),
      zIndex: const ZIndex(99),
      alignItems: .center,
      gap: Gap.all(4.px),
    ),
    css('.app-bar-logo').styles(
      width: 24.px,
      height: 24.px,
    ),
    css('.app-bar-title').styles(
      fontSize: 16.px,
      fontWeight: .w600,
      letterSpacing: const .em(0.02),
    ),
    css('.app-bar-divider').styles(
      width: 1.px,
      height: 24.px,
      margin: .symmetric(horizontal: 4.px),
      backgroundColor: colorBorder,
    ),

    // -- Text button (Create / Samples) --
    css('.app-bar-text-button').styles(
      display: .flex,
      padding: .symmetric(horizontal: 10.px, vertical: 6.px),
      border: .none,
      radius: .circular(6.px),
      cursor: .pointer,
      alignItems: .center,
      gap: Gap.all(6.px),
      color: colorOnSurface,
      fontSize: 13.px,
      fontWeight: .w500,
      backgroundColor: Colors.transparent,
    ),
    css('.app-bar-text-button:hover').styles(
      backgroundColor: colorBorder,
    ),
    css('.app-bar-text-button:disabled').styles(
      opacity: 0.5,
      cursor: .defaultCursor,
      raw: {'pointer-events': 'none'},
    ),
    css('.app-bar-button-label').styles(
      whiteSpace: .noWrap,
    ),
  ];
}

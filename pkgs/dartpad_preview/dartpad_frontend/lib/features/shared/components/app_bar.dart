// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../../editor/components/small_screen_tab_bar.dart';
import '../../startup/examples.g.dart';
import '../icons.dart';
import 'dropdown_menu.dart';
import 'icon_button.dart' as dp;
import 'theme_toggle.dart';

/// The main [AppBar] with the DartPad logo, title, theme toggle, and
/// overflow menu.
final class AppBar extends StatelessComponent {
  const AppBar({
    this.onSelectExample,
    this.restoreAction,
    this.isEmbedMode = false,
    this.isSmallScreen = false,
    this.smallScreenTabBar,
    super.key,
  });

  /// Called when the user selects an example from the New menu.
  final void Function(Example example)? onSelectExample;

  /// Temporary action beside New for restoring the last matching project.
  final Component? restoreAction;

  /// Whether the application is running in embed mode.
  final bool isEmbedMode;

  /// Code / Output [SmallScreenTabBar] displayed in small-screen layouts.
  final SmallScreenTabBar? smallScreenTabBar;

  /// Whether this [AppBar] is being rendered in a small-screen layout.
  final bool isSmallScreen;

  void _openLink(String uri) {
    web.window.open(uri, '_blank');
  }

  List<DropdownMenuEntry> _buildExampleItems() {
    final entries = <DropdownMenuEntry>[];
    String? lastSubcategory;

    for (final example in Examples.all) {
      if (example.subcategory != null && example.subcategory != lastSubcategory) {
        entries.add(DropdownMenuDivider(label: example.subcategory!));
        lastSubcategory = example.subcategory;
      }
      entries.add(
        DropdownMenuItem(
          label: example.name,
          leadingImage: example.icon,
          onPressed: () => onSelectExample?.call(example),
        ),
      );
    }

    return entries;
  }

  @override
  Component build(BuildContext context) {
    return switch ((isEmbedMode, isSmallScreen)) {
      // Large embedded layouts show neither AppBar nor SmallScreenTabBar.
      (true, false) => const Component.fragment([]),
      // Small embedded layouts show only SmallScreenTabBar.
      (true, true) => smallScreenTabBar ?? const Component.fragment([]),
      // Large standalone layouts show AppBar.
      (false, false) => _buildAppBar(),
      // Small standalone layouts show AppBar and SmallScreenTabBar.
      (false, true) => _buildAppBar(smallScreenTabBar),
    };
  }

  Component _buildAppBar([SmallScreenTabBar? smallScreenTabBar]) {
    final isNewDisabled = onSelectExample == null;

    final appBar = div(classes: 'app-bar${restoreAction != null ? ' app-bar-with-restore' : ''}', [
      // Left section: logo + title + new menu.
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
          disabled: isNewDisabled,
          trigger: button(
            classes: 'app-bar-text-button',
            disabled: isNewDisabled,
            attributes: {
              'aria-label': 'New',
              'title': 'New',
            },
            [
              const Icon('add_circle', size: 18),
              if (!isSmallScreen) const span(classes: 'app-bar-button-label', [.text('New')]),
            ],
          ),
          items: _buildExampleItems(),
        ),
        ?restoreAction,
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
    ]);

    return div(classes: 'app-bar-container', [
      appBar,
      ?smallScreenTabBar,
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css.media(MediaQuery.screen(maxWidth: 500.px), [
      // Keep the restore action and overflow menu visible on narrow screens.
      css(
        '.app-bar-with-restore .app-bar-title, '
        '.app-bar-with-restore .app-bar-divider, '
        '.app-bar-with-restore .app-bar-button-label',
      ).styles(display: .none),
    ]),
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
      height: 52.px,
      minHeight: 52.px,
      padding: .symmetric(horizontal: 16.px),
      border: .only(
        bottom: .solid(color: colorBorder, width: 1.px),
      ),
      alignItems: .center,
      gap: Gap.all(8.px),
      flex: const .shrink(0),
      backgroundColor: colorSurface,
    ),
    // Dark theme styles matching dart.dev chrome.
    css('html[data-theme="dark"] .app-bar').styles(
      backgroundColor: const Color('#1c2834'),
      border: .only(
        bottom: .solid(color: const Color('#394c60'), width: 1.px),
      ),
    ),
    css('html[data-theme="dark"] .app-bar .app-bar-title').styles(
      color: const Color('#f3f4f6'),
    ),
    css('html[data-theme="dark"] .app-bar .app-bar-divider').styles(
      backgroundColor: const Color('#394c60'),
    ),
    css('html[data-theme="dark"] .app-bar .app-bar-text-button').styles(
      color: const Color('#f3f4f6'),
    ),
    css('html[data-theme="dark"] .app-bar .app-bar-text-button:hover').styles(
      backgroundColor: const Color('#253446'),
    ),
    css('html[data-theme="dark"] .app-bar .icon-button').styles(
      color: const Color('#a8acad'),
    ),
    css('html[data-theme="dark"] .app-bar .icon-button:hover').styles(
      color: const Color('#40c4ff'),
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
    css('.app-bar-right').styles(
      display: .flex,
      position: const .relative(),
      zIndex: const ZIndex(99),
      alignItems: .center,
      gap: Gap.all(4.px),
    ),
    css('.app-bar-logo').styles(
      width: 32.px,
      height: 32.px,
    ),
    css('.app-bar-title').styles(
      color: colorOnContainer,
      fontSize: 22.px,
      fontWeight: .w400,
    ),
    css('.app-bar-divider').styles(
      width: 1.px,
      height: 24.px,
      margin: .symmetric(horizontal: 4.px),
      backgroundColor: colorBorder,
    ),

    // -- Text button (New) --
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

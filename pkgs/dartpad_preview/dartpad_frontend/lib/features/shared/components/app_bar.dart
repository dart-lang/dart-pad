// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../../startup/samples.g.dart';
import '../icons.dart';
import 'dropdown_menu.dart';
import 'icon_button.dart' as dp;
import 'theme_toggle.dart';

/// The main application bar with the DartPad logo, title, theme toggle, and
/// overflow menu.
class AppBar extends StatefulComponent {
  const AppBar({
    this.onCreateSample,
    this.onSelectExample,
    super.key,
  });

  /// Called when the user selects a snippet from the Create menu.
  final void Function(Sample sample)? onCreateSample;

  /// Called when the user selects an example.
  final void Function(Sample sample)? onSelectExample;

  @override
  State<AppBar> createState() => _AppBarState();

  @css
  static List<StyleRule> get styles => _AppBarState.styles;
}

class _AppBarState extends State<AppBar> {
  void _openLink(String uri) {
    web.window.open(uri, '_blank');
  }

  @override
  Component build(BuildContext context) {
    final isCreateDisabled = component.onCreateSample == null;
    final isExamplesDisabled = component.onSelectExample == null;

    return div(classes: 'app-bar', [
      // Left section: logo + title + create + examples.
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
              const span(classes: 'app-bar-button-label', [.text('Create')]),
            ],
          ),
          items: [
            for (final sample in Samples.create)
              DropdownMenuItem(
                label: sample.name,
                leadingImage: sample.id == 'flutter' ? 'images/flutter_logo_192.png' : 'images/dart_logo_192.png',
                onPressed: () => component.onCreateSample?.call(sample),
              ),
          ],
        ),
        DropdownMenu(
          alignLeft: true,
          disabled: isExamplesDisabled,
          trigger: button(
            classes: 'app-bar-text-button',
            disabled: isExamplesDisabled,
            attributes: {
              'aria-label': 'Examples',
              'title': 'Try an example',
            },
            [
              const Icon('playlist_add', size: 18),
              const span(classes: 'app-bar-button-label', [.text('Examples')]),
            ],
          ),
          items: [
            for (final sample in Samples.examples)
              DropdownMenuItem(
                label: sample.name,
                onPressed: () => component.onSelectExample?.call(sample),
              ),
          ],
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
    ]);
  }

  static List<StyleRule> get styles => [
    css('.app-bar').styles(
      display: .flex,
      position: const .relative(),
      // File-tree folder rows are sticky and use z-indices up to 100. Keep
      // the whole app bar above that stacking context so dropdowns are never
      // painted behind the workspace.
      zIndex: const ZIndex(200),
      height: 48.px,
      minHeight: 48.px,
      padding: .symmetric(horizontal: 12.px),
      border: .only(
        bottom: .solid(color: colorBorder, width: 2.px),
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

    // -- Text button (Create / Examples) --
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

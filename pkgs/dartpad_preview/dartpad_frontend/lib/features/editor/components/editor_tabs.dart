// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../../shared/icons.dart';

/// Renders a tab bar for switching between and closing open editor files.
final class EditorTabs extends StatelessComponent {
  /// Creates a tab strip for [openTabs].
  ///
  /// [confirmDiscard] can override the browser confirmation dialog, for
  /// example in tests.
  const EditorTabs({
    required this.openTabs,
    required this.activeFile,
    required this.onSwitchFile,
    required this.onCloseFile,
    this.confirmDiscard,
    super.key,
  });

  /// The tabs displayed in the tab strip.
  final List<EditorTab<Component>> openTabs;

  /// The path of the active editor tab.
  final String activeFile;

  /// Switches to the editor tab at the provided path.
  final void Function(String path) onSwitchFile;

  /// Closes the editor tab at the provided path.
  final bool Function(String path, {bool discardChanges}) onCloseFile;

  /// Requests confirmation before discarding changes in the file at [path].
  final bool Function(String path)? confirmDiscard;

  @override
  Component build(BuildContext context) {
    return div(classes: 'editor-tabs', [
      for (final tab in openTabs)
        div(
          key: ValueKey('tab-${tab.path}'),
          classes: [
            'editor-tab',
            if (tab.path == activeFile) 'active',
            if (tab.hasUnsavedChanges) 'dirty',
          ].join(' '),
          attributes: {
            'title': tab.path,
            'tabindex': '0',
            'role': 'tab',
            'aria-selected': tab.path == activeFile ? 'true' : 'false',
          },
          events: {
            'click': (_) => onSwitchFile(tab.path),
            'keydown': (event) {
              final keyboardEvent = event as web.KeyboardEvent;
              if (keyboardEvent.key == 'Enter' || keyboardEvent.key == ' ') {
                onSwitchFile(tab.path);
              }
            },
          },
          [
            span(classes: 'editor-tab-name', [.text(tab.name)]),
            if (tab.hasUnsavedChanges) const span(classes: 'editor-tab-dirty-dot', []),
            button(
              classes: 'editor-tab-action close',
              attributes: {
                'title': 'Close tab',
                'aria-label': 'Close ${tab.name}',
              },
              events: {
                'click': (event) {
                  event.stopPropagation();
                  final discardChanges =
                      tab.hasUnsavedChanges &&
                      (confirmDiscard?.call(tab.path) ??
                          web.window.confirm(
                            'Discard unsaved changes in ${tab.name}?',
                          ));
                  if (!tab.hasUnsavedChanges || discardChanges) {
                    onCloseFile(
                      tab.path,
                      discardChanges: discardChanges,
                    );
                  }
                },
              },
              [const Icon('close', size: 12)],
            ),
          ],
        ),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.editor-tabs', [
      css('&').styles(
        display: .flex,
        minHeight: 38.px,
        overflow: const .only(x: .auto, y: .hidden),
        flex: const .shrink(0),
        backgroundColor: colorSurface,
      ),
      css('.editor-tab', [
        css('&').styles(
          display: .flex,
          minWidth: 96.px,
          maxWidth: 180.px,
          padding: .only(left: 12.px, right: 8.px),
          border: .only(
            top: .solid(color: Colors.transparent, width: 2.px),
          ),
          cursor: .pointer,
          userSelect: .none,
          alignItems: .center,
          gap: .all(6.px),
          color: colorOnContainer,
          backgroundColor: colorContainer.highlight(colorOnContainer, 0.1),
        ),
        css('&:hover').styles(
          backgroundColor: colorContainer.highlight(colorOnContainer, 0.15),
        ),
        css('&.active').styles(
          border: .only(
            top: .solid(color: colorPrimary, width: 2.px),
          ),
          color: colorOnContainer,
          backgroundColor: colorContainer,
        ),
        css('&.active:hover').styles(
          backgroundColor: colorContainer.highlight(colorOnContainer, 0.05),
        ),
        css('.editor-tab-name').styles(
          minWidth: .zero,
          overflow: .hidden,
          flex: const Flex(grow: 1, basis: .zero),
          fontFamily: const .list([FontFamily('Consolas'), FontFamilies.monospace]),
          fontSize: 12.px,
          textOverflow: .ellipsis,
          whiteSpace: .noWrap,
        ),
        css('.editor-tab-dirty-dot').styles(
          width: 7.px,
          height: 7.px,
          radius: .circular(4.px),
          flex: const .shrink(0),
          backgroundColor: colorPrimary,
        ),
        css('.editor-tab-action', [
          css('&').styles(
            display: .flex,
            width: 18.px,
            height: 18.px,
            padding: .zero,
            border: .none,
            radius: .circular(4.px),
            cursor: .pointer,
            justifyContent: .center,
            alignItems: .center,
            color: colorOnSurface,
            fontSize: 11.px,
            backgroundColor: Colors.transparent,
          ),
          css('&:hover').styles(
            color: const Color('#ffffff'),
            backgroundColor: const Color('#3a3a3a'),
          ),
          css('&.close:hover').styles(
            color: colorError,
            backgroundColor: colorSurface,
          ),
        ]),
      ]),
    ]),
  ];
}

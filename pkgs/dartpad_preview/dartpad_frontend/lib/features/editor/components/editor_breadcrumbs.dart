// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/components/file_icon.dart';

import '../../../app_styles.dart';
import '../../shared/icons.dart';

/// Displays the path of the currently active file as a breadcrumb trail above the editor.
final class EditorBreadcrumbs extends StatelessComponent {
  /// Creates an [EditorBreadcrumbs] component for the given [path].
  const EditorBreadcrumbs({
    required this.path,
    super.key,
  });

  /// The virtual workspace path to display.
  final String path;

  @override
  Component build(BuildContext context) {
    final segments = path.split('/').where((segment) => segment.isNotEmpty).toList();
    if (segments.isEmpty) {
      return const Component.fragment([]);
    }

    return div(
      classes: 'editor-breadcrumbs',
      attributes: {
        'title': path,
        'aria-label': 'Current file: $path',
      },
      [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0)
            const span(
              classes: 'editor-breadcrumb-separator',
              [Icon('chevron_right', size: 14)],
            ),
          if (i < segments.length - 1)
            span(
              classes: 'editor-breadcrumb-item editor-breadcrumb-folder',
              [.text(segments[i])],
            )
          else
            span(
              classes: 'editor-breadcrumb-item editor-breadcrumb-file',
              [
                _fileIcon(segments[i]),
                span(
                  classes: 'editor-breadcrumb-name',
                  [.text(segments[i])],
                ),
              ],
            ),
        ],
      ],
    );
  }

  Component _fileIcon(String fileName) {
    final lowerName = fileName.toLowerCase();
    final colorClass = switch (lowerName) {
      final path when path.endsWith('.dart') => 'file-icon-dart',
      final path when path.endsWith('.yaml') || path.endsWith('.yml') => 'file-icon-yaml',
      _ => 'file-icon',
    };
    return FileIcon.forFile(
      fileName,
      classes: 'editor-breadcrumb-icon $colorClass',
      attributes: const {'aria-hidden': 'true', 'width': '14', 'height': '14'},
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.editor-breadcrumbs', [
      css('&').styles(
        display: .flex,
        height: 24.px,
        minHeight: 24.px,
        padding: .symmetric(horizontal: 12.px),
        border: .only(
          bottom: .solid(color: colorBorder, width: 1.px),
        ),
        overflow: const .only(x: .auto, y: .hidden),
        userSelect: .none,
        alignItems: .center,
        gap: .all(4.px),
        flex: const .shrink(0),
        color: colorOnSurface,
        fontFamily: const .list([FontFamily('Consolas'), FontFamilies.monospace]),
        fontSize: 11.px,
        backgroundColor: colorSurface,
      ),
      css('.editor-breadcrumb-item').styles(
        display: .inlineFlex,
        alignItems: .center,
        gap: .all(4.px),
        whiteSpace: .noWrap,
      ),
      css('.editor-breadcrumb-folder').styles(
        color: colorOnSurface.highlight(colorSurface, 0.2),
      ),
      css('.editor-breadcrumb-file').styles(
        color: colorOnContainer,
      ),
      css('.editor-breadcrumb-name').styles(
        whiteSpace: .noWrap,
      ),
      css('.editor-breadcrumb-separator').styles(
        display: .inlineFlex,
        alignItems: .center,
        color: colorOnSurface.highlight(colorSurface, 0.4),
      ),
      css('.editor-breadcrumb-icon').styles(
        flex: const .shrink(0),
      ),
    ]),
  ];
}

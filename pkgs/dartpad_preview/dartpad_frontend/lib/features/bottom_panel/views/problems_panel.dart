// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';

class ProblemsPanel extends StatelessComponent {
  const ProblemsPanel({
    required this.diagnostics,
    required this.hasMoreDiagnostics,
    required this.activeFile,
    required this.onOpenDiagnostic,
    super.key,
  });

  final List<DiagnosticEntry> diagnostics;

  /// Whether diagnostics are omitted from the problems panel.
  final bool hasMoreDiagnostics;
  final String activeFile;
  final FutureOr<void> Function(String fileName, Diagnostic diagnostic) onOpenDiagnostic;

  @override
  Component build(BuildContext context) {
    return div(classes: 'problems-panel', [
      if (hasMoreDiagnostics)
        const div(classes: 'diagnostics-limit-notice', [
          .text('Only the first 1,000 problems are shown.'),
        ]),
      div(classes: 'problems-list', [
        if (diagnostics.isEmpty)
          const div(classes: 'problems-empty', [.text('No problems')])
        else
          for (final entry in diagnostics)
            _ProblemRow(
              fileName: entry.fileName,
              diagnostic: entry.diagnostic,
              activeFile: activeFile,
              onOpenDiagnostic: onOpenDiagnostic,
            ),
      ]),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.problems-panel', [
      css('&').styles(
        display: .flex,
        position: const .relative(),
        minHeight: 120.px,
        maxHeight: 180.px,
        margin: .only(bottom: 15.px),
        overflow: .hidden,
        flexDirection: .column,
        flex: const .shrink(0),
        backgroundColor: colorContainerLow,
      ),
      css('& .problems-list').styles(
        minHeight: .zero,
        overflow: const .only(y: .auto),
        flex: const Flex(grow: 1, basis: .zero),
      ),
      css('& .diagnostics-limit-notice').styles(
        position: .absolute(top: 8.px, right: 12.px),
        zIndex: const ZIndex(1),
        padding: .symmetric(horizontal: 10.px, vertical: 5.px),
        radius: .circular(999.px),
        color: colorOnSurface,
        backgroundColor: colorWarning.withOpacity(0.2),
        fontSize: 12.px,
      ),
      css('& .problems-empty').styles(
        display: .flex,
        minHeight: 48.px,
        padding: .symmetric(horizontal: 12.px),
        alignItems: .center,
        color: colorOnSurfaceVariant,
        fontSize: 12.px,
      ),
      css('& .problem-row').styles(
        display: .grid,
        minHeight: 28.px,
        padding: .symmetric(horizontal: 12.px),
        border: .only(
          left: .solid(color: Colors.transparent, width: 2.px),
        ),
        cursor: .pointer,
        alignItems: .center,
        gridTemplate: GridTemplate(
          columns: GridTracks([
            GridTrack(TrackSize(22.px)),
            GridTrack(.minmax(TrackSize(0.px), const TrackSize.fr(1))),
            const GridTrack(TrackSize(Unit.auto)),
          ]),
        ),
        gap: .all(8.px),
        fontSize: 12.px,
      ),
      css('& .problem-row:hover, & .problem-row:focus').styles(
        outline: const Outline(style: .none),
        backgroundColor: colorContainerHigh,
      ),
      css('& .problem-row.error').styles(
        border: .only(
          left: .solid(color: colorError, width: 2.px),
        ),
      ),
      css('& .problem-row.warning').styles(
        border: .only(
          left: .solid(color: colorWarning, width: 2.px),
        ),
      ),
      css('& .problem-row.info, & .problem-row.hint').styles(
        border: .only(
          left: .solid(color: colorInfo, width: 2.px),
        ),
      ),
      css('& .problem-row.active-file').styles(
        backgroundColor: colorContainerHigh.withOpacity(0.5),
      ),
      css('& .problem-severity-badge').styles(
        display: .inlineFlex,
        width: 18.px,
        height: 18.px,
        radius: .circular(999.px),
        justifyContent: .center,
        alignItems: .center,
        fontSize: 11.px,
        fontWeight: .w700,
      ),
      css('& .problem-severity-badge.error').styles(
        color: colorOnSurface,
        backgroundColor: colorError.withOpacity(0.2),
      ),
      css('& .problem-severity-badge.warning').styles(
        color: colorOnSurface,
        backgroundColor: colorWarning.withOpacity(0.2),
      ),
      css('& .problem-severity-badge.info, & .problem-severity-badge.hint').styles(
        color: colorOnSurface,
        backgroundColor: colorInfo.withOpacity(0.2),
      ),
      css('& .problem-message').styles(
        minWidth: .zero,
        overflow: .hidden,
        textOverflow: .ellipsis,
        whiteSpace: .noWrap,
      ),
      css('& .problem-actions').styles(
        display: .flex,
        justifyContent: .end,
        alignItems: .center,
      ),
      css('& .problem-location').styles(
        display: .inlineBlock,
        color: colorOnSurfaceVariant,
        fontFamily: const .list([
          FontFamilies.courierNew,
          FontFamilies.monospace,
        ]),
        fontSize: 11.px,
      ),
      css(
        '& .problem-row:hover .problem-location, & .problem-row:focus-within .problem-location',
      ).styles(display: .none),
    ]),
  ];
}

class _ProblemRow extends StatelessComponent {
  const _ProblemRow({
    required this.fileName,
    required this.diagnostic,
    required this.activeFile,
    required this.onOpenDiagnostic,
  });

  final String fileName;
  final Diagnostic diagnostic;
  final String activeFile;
  final FutureOr<void> Function(String fileName, Diagnostic diagnostic) onOpenDiagnostic;

  @override
  Component build(BuildContext context) {
    final severityClass = diagnostic.severity.cssClass;
    final severityLabel = diagnostic.severity.label;
    final line = diagnostic.line + 1;
    final character = diagnostic.character + 1;
    final location = '$fileName:$line:$character';
    final activeClass = fileName == activeFile ? ' active-file' : '';

    return div(
      key: ValueKey('problem-$location-${diagnostic.message}'),
      classes: 'problem-row $severityClass$activeClass',
      attributes: {
        'title': '$severityLabel: ${diagnostic.message} ($location)',
        'tabindex': '0',
      },
      events: {
        'click': (_) {
          onOpenDiagnostic(fileName, diagnostic);
        },
        'keydown': (e) {
          final ke = e as web.KeyboardEvent;
          if (ke.key == 'Enter' || ke.key == ' ') {
            onOpenDiagnostic(fileName, diagnostic);
          }
        },
      },
      [
        span(
          classes: 'problem-severity-badge $severityClass',
          [.text(diagnostic.severity.icon)],
        ),
        span(classes: 'problem-message', [.text(diagnostic.message)]),
        span(classes: 'problem-actions', [
          span(classes: 'problem-location', [.text(location)]),
        ]),
      ],
    );
  }
}

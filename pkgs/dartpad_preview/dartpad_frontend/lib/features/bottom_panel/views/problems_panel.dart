import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

class ProblemsPanel extends StatelessComponent {
  const ProblemsPanel({
    required this.diagnostics,
    required this.activeFile,
    required this.onOpenDiagnostic,
    super.key,
  });

  final List<DiagnosticEntry> diagnostics;
  final String activeFile;
  final FutureOr<void> Function(String fileName, Diagnostic diagnostic) onOpenDiagnostic;

  @override
  Component build(BuildContext context) {
    return div(classes: 'problems-panel', [
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

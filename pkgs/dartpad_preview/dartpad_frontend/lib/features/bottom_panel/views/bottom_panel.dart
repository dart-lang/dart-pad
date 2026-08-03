import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'problems_panel.dart';

/// The bottom panel showing a "Problems" tab with diagnostics.
class BottomPanel extends StatelessComponent {
  const BottomPanel({
    required this.diagnostics,
    required this.activeFile,
    required this.onOpenDiagnostic,
    required this.showProblems,
    required this.onShowProblems,
    super.key,
  });

  /// All current diagnostics from the language server.
  final List<DiagnosticEntry> diagnostics;

  /// The currently active editor file path, used to highlight matching rows.
  final String activeFile;

  /// Called when the user clicks a diagnostic row.
  final void Function(String fileName, Diagnostic diagnostic) onOpenDiagnostic;

  /// Whether the problems panel content is visible.
  final bool showProblems;

  /// Shows the problems panel.
  final void Function() onShowProblems;

  @override
  Component build(BuildContext context) {
    return div(classes: 'bottom-panel', [
      _buildTabs(),
      if (showProblems) _buildContent(),
    ]);
  }

  Component _buildTabs() {
    return div(classes: 'bottom-panel-tabs', [
      _BottomPanelTabButton(
        label: 'Problems',
        countLabel: diagnostics.length.toString(),
        active: showProblems,
        onClick: onShowProblems,
      ),
    ]);
  }

  Component _buildContent() {
    return div(
      classes: 'bottom-panel-content',
      [
        ProblemsPanel(
          diagnostics: diagnostics,
          activeFile: activeFile,
          onOpenDiagnostic: onOpenDiagnostic,
        ),
      ],
    );
  }
}

class _BottomPanelTabButton extends StatelessComponent {
  const _BottomPanelTabButton({
    required this.label,
    this.countLabel,
    required this.active,
    this.onClick,
  });

  final String label;
  final String? countLabel;
  final bool active;
  final void Function()? onClick;

  @override
  Component build(BuildContext context) {
    final classes = active ? 'bottom-panel-tab active' : 'bottom-panel-tab';

    return button(
      classes: classes,
      onClick: onClick,
      [
        span(classes: 'bottom-panel-tab-label', [.text(label)]),
        if (countLabel case final countLabel?) span(classes: 'bottom-panel-tab-count', [.text(countLabel)]),
      ],
    );
  }
}

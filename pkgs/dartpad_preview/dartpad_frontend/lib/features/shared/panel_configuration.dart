// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Independently configurable groups of workspace UI. The editor is always available.
enum WorkspacePanel {
  bottomPanels('bottom_panels', 'bottom panels'),
  preview('preview', 'preview'),
  tabs('tabs', 'editor tabs'),
  fileTree('file_tree', 'file tree'),
  statusBar('status_bar', 'status bar'),
  appBar('app_bar', 'app bar');

  const WorkspacePanel(this.queryName, this.label);

  final String queryName;
  final String label;
}

enum PanelPresentation { expanded, collapsed, hidden }

/// Resolves URL panel list entries into contextual initial presentation states.
final class PanelConfiguration {
  const PanelConfiguration._(this.isEmbedMode, this._states);

  factory PanelConfiguration.fromUri(Uri uri) {
    final embedValues = uri.queryParametersAll['embed'];
    final isEmbedMode = embedValues?.contains('true') ?? false;

    final files = uri.queryParametersAll['file'] ?? const <String>[];
    final multipleFiles = files.toSet().length > 1;

    final states = <WorkspacePanel, PanelPresentation>{
      for (final panel in WorkspacePanel.values)
        panel: switch (panel) {
          _ when !isEmbedMode => PanelPresentation.expanded,
          WorkspacePanel.preview => PanelPresentation.expanded,
          WorkspacePanel.tabs when multipleFiles => PanelPresentation.expanded,
          WorkspacePanel.bottomPanels => PanelPresentation.collapsed,
          _ => PanelPresentation.hidden,
        },
    };

    // Decode percent escapes without treating literal '+' as a form-encoded space.
    // Both panels=+tabs and panels=%2Btabs express the same panel entry.
    for (final parameter in uri.query.split('&')) {
      final equals = parameter.indexOf('=');
      if (equals < 0 || Uri.decodeQueryComponent(parameter.substring(0, equals)) != 'panels') {
        continue;
      }
      for (final value in Uri.decodeComponent(parameter.substring(equals + 1)).split(',')) {
        final panelEntry = value.trim();
        if (panelEntry.length < 2 || (panelEntry[0] != '+' && panelEntry[0] != '-')) {
          continue;
        }
        for (final panel in WorkspacePanel.values) {
          if (panel.queryName == panelEntry.substring(1)) {
            states[panel] = switch (panel) {
              // Tabs have no collapsed presentation: standalone keeps them visible,
              // while embeds can hide or show them through the URL.
              WorkspacePanel.tabs =>
                panelEntry[0] == '-' && isEmbedMode ? PanelPresentation.hidden : PanelPresentation.expanded,
              _ =>
                panelEntry[0] == '+'
                    ? PanelPresentation.expanded
                    : isEmbedMode && panel != WorkspacePanel.bottomPanels
                    ? PanelPresentation.hidden
                    : PanelPresentation.collapsed,
            };
          }
        }
      }
    }

    return PanelConfiguration._(isEmbedMode, states);
  }

  final bool isEmbedMode;
  final Map<WorkspacePanel, PanelPresentation> _states;

  PanelPresentation operator [](WorkspacePanel panel) => _states[panel]!;
}

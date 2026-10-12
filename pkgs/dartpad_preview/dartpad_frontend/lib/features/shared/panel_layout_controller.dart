// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/jaspr.dart';

import 'components/split_panel.dart';
import 'panel_configuration.dart';

export 'panel_configuration.dart';

/// Owns panel presentation and remembers split sizes across layout changes.
final class PanelLayoutController extends ChangeNotifier {
  PanelLayoutController(PanelConfiguration configuration)
    : _isEmbedMode = configuration.isEmbedMode,
      _states = {for (final panel in WorkspacePanel.values) panel: configuration[panel]};

  final bool _isEmbedMode;
  final Map<WorkspacePanel, PanelPresentation> _states;
  final Map<WorkspacePanel, double> _sizes = {};

  PanelPresentation operator [](WorkspacePanel panel) => _states[panel]!;

  void setPresentation(WorkspacePanel panel, PanelPresentation presentation) {
    presentation = _normalize(panel, presentation);
    if (_states[panel] != presentation) {
      _states[panel] = presentation;
      notifyListeners();
    }
  }

  PanelPresentation _normalize(WorkspacePanel panel, PanelPresentation presentation) => switch (panel) {
    // Tabs are a visibility-only group. Standalone always shows them; embeds
    // can hide them but don't have a collapsed rail state.
    WorkspacePanel.tabs =>
      _isEmbedMode && presentation == PanelPresentation.hidden ? PanelPresentation.hidden : PanelPresentation.expanded,
    _ => presentation,
  };

  /// Toggles between expanded and collapsed presentation.
  void toggle(WorkspacePanel panel) => setPresentation(
    panel,
    this[panel] == PanelPresentation.expanded ? PanelPresentation.collapsed : PanelPresentation.expanded,
  );

  SplitState splitState(WorkspacePanel panel, {required double initialValue, bool isLeft = false}) {
    final value = _sizes[panel] ?? initialValue;
    return switch (this[panel]) {
      PanelPresentation.expanded => Split(value),
      PanelPresentation.collapsed => isLeft ? LeftCollapsed(value) : RightCollapsed(value),
      PanelPresentation.hidden => isLeft ? LeftHidden(value) : RightHidden(value),
    };
  }

  void updateSplit(WorkspacePanel panel, SplitState state) {
    final presentation = state.isHidden
        ? PanelPresentation.hidden
        : state.isCollapsed
        ? PanelPresentation.collapsed
        : PanelPresentation.expanded;
    final normalizedPresentation = _normalize(panel, presentation);
    if (_sizes[panel] != state.value || this[panel] != normalizedPresentation) {
      _sizes[panel] = state.value;
      _states[panel] = normalizedPresentation;
      notifyListeners();
    }
  }
}

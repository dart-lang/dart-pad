// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/jaspr.dart';

import '../bottom_panel/bottom_panel_state.dart';
import 'components/split_panel.dart';
import 'panel_defaults.dart' as panel_defaults;
import 'panel_hints.dart';
import 'panel_presentation_state.dart';
import 'workspace_mode.dart';

/// Owns panel presentation, workspace splits, and bottom-tab selection independently of mounted views.
final class PanelLayoutController {
  PanelLayoutController({required this.mode, bool? showEditorNavigation}) {
    final defaults = panel_defaults.resolveInitialPanelLayout(
      mode: mode,
      showEditorNavigation: showEditorNavigation,
    );
    _preview = ValueNotifier(defaults.preview);
    _fileTree = ValueNotifier(defaults.fileTree);
    _bottom = ValueNotifier(defaults.bottom);
    _bottomSplit = _BottomSplitListenable(_bottom);
    _appBar = ValueNotifier(defaults.appBar);
    _statusBar = ValueNotifier(defaults.statusBar);
    _editorNavigation = ValueNotifier(defaults.editorNavigation);
  }

  final WorkspaceMode mode;
  late final ValueNotifier<SplitState> _preview;
  late final ValueNotifier<SplitState> _fileTree;
  late final ValueNotifier<BottomPanelState> _bottom;
  late final ValueListenable<SplitState> _bottomSplit;
  late final ValueNotifier<PanelPresentationState> _appBar;
  late final ValueNotifier<PanelPresentationState> _statusBar;
  late final ValueNotifier<PanelPresentationState> _editorNavigation;

  SplitState get preview => _preview.value;
  SplitState get fileTree => _fileTree.value;
  BottomPanelState get bottom => _bottom.value;
  PanelPresentationState get appBar => _appBar.value;
  PanelPresentationState get statusBar => _statusBar.value;
  bool get showEditorTabs => _editorNavigation.value == PanelPresentationState.expanded;
  bool get showBreadcrumbs => _editorNavigation.value == PanelPresentationState.expanded;

  /// Changes to the preview split only.
  ValueListenable<SplitState> get previewListenable => _preview;

  /// Changes to the file-tree split only.
  ValueListenable<SplitState> get fileTreeListenable => _fileTree;

  /// Changes to bottom-tab selection, expansion, or size only.
  ValueListenable<BottomPanelState> get bottomListenable => _bottom;

  /// The bottom split derived from the shared bottom-panel state.
  ValueListenable<SplitState> get bottomSplitListenable => _bottomSplit;

  /// Changes to the app-bar presentation only.
  ValueListenable<PanelPresentationState> get appBarListenable => _appBar;

  /// Changes to the status-bar presentation only.
  ValueListenable<PanelPresentationState> get statusBarListenable => _statusBar;

  /// Changes to the visibility of editor tabs and breadcrumbs only.
  ValueListenable<PanelPresentationState> get editorNavigationListenable => _editorNavigation;

  /// Apply at the start of a project load, before the user can change its layout.
  void applyInitialDefaults({
    double? previewRatio,
    bool? showEditorNavigation,
    PanelHints hints = const PanelHints.none(),
  }) {
    final defaults = hints.resolve(
      mode: mode,
      showEditorNavigation: showEditorNavigation,
      previewRatio: previewRatio,
    );
    _preview.value = defaults.preview;
    _fileTree.value = defaults.fileTree;
    _bottom.value = defaults.bottom;
    _appBar.value = defaults.appBar;
    _statusBar.value = defaults.statusBar;
    _editorNavigation.value = defaults.editorNavigation;
  }

  void updatePreview(SplitState state) => _preview.value = state;

  void updateFileTree(SplitState state) => _fileTree.value = state;

  /// Applies splitter changes while preserving the selected bottom tab.
  void updateBottomSplit(SplitState state) {
    _setBottom(switch (state) {
      Split(:final value) => BottomPanelExpanded(bottom.selectedTab, editorFraction: value),
      RightCollapsed(:final lastSplitValue) => BottomPanelCollapsed(
        bottom.selectedTab,
        editorFraction: lastSplitValue,
      ),
      RightHidden(:final lastSplitValue) => BottomPanelHidden(bottom.selectedTab, editorFraction: lastSplitValue),
      _ => throw ArgumentError.value(state, 'state', 'Only the bottom side of the split can collapse or hide.'),
    });
  }

  void openBottomPanel(BottomPanelTab tab) =>
      _setBottom(BottomPanelExpanded(tab, editorFraction: bottom.editorFraction));

  void collapseBottomPanel() =>
      _setBottom(BottomPanelCollapsed(bottom.selectedTab, editorFraction: bottom.editorFraction));

  void expandPreview() => updatePreview(Split(preview.value));

  void _setBottom(BottomPanelState state) => _bottom.value = state;

  void dispose() {
    _preview.dispose();
    _fileTree.dispose();
    _bottom.dispose();
    _appBar.dispose();
    _statusBar.dispose();
    _editorNavigation.dispose();
  }
}

/// Exposes bottom-panel expansion and editor height as a split listenable.
final class _BottomSplitListenable implements ValueListenable<SplitState> {
  const _BottomSplitListenable(this._bottom);

  final ValueListenable<BottomPanelState> _bottom;

  @override
  SplitState get value => switch (_bottom.value) {
    BottomPanelExpanded(:final editorFraction) => Split(editorFraction),
    BottomPanelCollapsed(:final editorFraction) => RightCollapsed(editorFraction),
    BottomPanelHidden(:final editorFraction) => RightHidden(editorFraction),
  };

  @override
  void addListener(VoidCallback listener) => _bottom.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _bottom.removeListener(listener);
}

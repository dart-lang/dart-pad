// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/jaspr.dart';

import '../bottom_panel/bottom_panel_state.dart';
import 'components/split_panel.dart';
import 'panel_defaults.dart' as panel_defaults;
import 'panel_hints.dart';
import 'panel_layout_state.dart';
import 'panel_presentation_state.dart';
import 'workspace_mode.dart';

/// Owns panel presentation, workspace splits, and bottom-tab selection independently of mounted views.
final class PanelLayoutController {
  PanelLayoutController({required this.mode, bool isSmallScreen = false, bool? showEditorNavigation}) {
    final defaults = panel_defaults.resolveInitialPanelLayout(
      mode: mode,
      isSmallScreen: isSmallScreen,
      showEditorNavigation: showEditorNavigation,
    );
    _preview = ValueNotifier(defaults.preview);
    _layout = ValueNotifier(defaults.layout);
    _largeScreenFileTree = panel_defaults.resolveInitialPanelLayout(mode: mode).fileTree;
    _fileTree = ValueNotifier(defaults.fileTree);
    _bottom = ValueNotifier(defaults.bottom);
    _bottomSplit = _BottomSplitListenable(_bottom);
    _appBar = ValueNotifier(defaults.appBar);
    _statusBar = ValueNotifier(defaults.statusBar);
    _editorNavigation = ValueNotifier(defaults.editorNavigation);
  }

  final WorkspaceMode mode;
  late final ValueNotifier<PanelLayout> _layout;
  late SplitState _largeScreenFileTree;
  late final ValueNotifier<SplitState> _preview;
  late final ValueNotifier<SplitState> _fileTree;
  late final ValueNotifier<BottomPanelState> _bottom;
  late final ValueListenable<SplitState> _bottomSplit;
  late final ValueNotifier<PanelPresentationState> _appBar;
  late final ValueNotifier<PanelPresentationState> _statusBar;
  late final ValueNotifier<PanelPresentationState> _editorNavigation;

  SplitState get preview => _preview.value;
  PanelLayout get layout => _layout.value;
  bool get isSmallScreen => layout == PanelLayout.smallScreen;
  SplitState get fileTree => _fileTree.value;
  BottomPanelState get bottom => _bottom.value;
  PanelPresentationState get appBar => _appBar.value;
  PanelPresentationState get statusBar => _statusBar.value;
  bool get showEditorTabs => _editorNavigation.value == PanelPresentationState.expanded;
  bool get showBreadcrumbs => _editorNavigation.value == PanelPresentationState.expanded;

  /// Changes to the preview split only.
  ValueListenable<SplitState> get previewListenable => _preview;

  /// Changes to the responsive panel arrangement only.
  ValueListenable<PanelLayout> get layoutListenable => _layout;

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
      isSmallScreen: isSmallScreen,
      showEditorNavigation: showEditorNavigation,
      previewRatio: previewRatio,
    );
    _preview.value = defaults.preview;
    _fileTree.value = defaults.fileTree;
    _largeScreenFileTree = hints.resolve(mode: mode).fileTree;
    _bottom.value = defaults.bottom;
    _appBar.value = defaults.appBar;
    _statusBar.value = defaults.statusBar;
    _editorNavigation.value = defaults.editorNavigation;
  }

  void updatePreview(SplitState state) => _preview.value = state;

  void updateFileTree(SplitState state) {
    // Small-screen navigation closes completely instead of leaving a collapsed rail.
    _fileTree.value = isSmallScreen && state is LeftCollapsed ? LeftHidden(state.value) : state;
  }

  /// Switches file navigation without resetting the other panel choices.
  void updateScreenSize({required bool isSmallScreen}) {
    if (this.isSmallScreen == isSmallScreen) {
      return;
    }
    if (isSmallScreen) {
      _largeScreenFileTree = fileTree;
      _fileTree.value = LeftHidden(fileTree.value);
    } else {
      _fileTree.value = _largeScreenFileTree;
    }
    _layout.value = isSmallScreen
        ? PanelLayout.smallScreen
        : (mode == WorkspaceMode.embed ? PanelLayout.embed : PanelLayout.standalone);
  }

  void toggleFileTree() => updateFileTree(fileTree.isSplit ? LeftHidden(fileTree.value) : Split(fileTree.value));

  /// Closes small-screen file navigation while keeping desktop navigation open.
  void closeSmallScreenFileTree() {
    if (isSmallScreen) {
      updateFileTree(LeftHidden(fileTree.value));
    }
  }

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
    _layout.dispose();
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

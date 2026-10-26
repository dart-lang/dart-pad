// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/jaspr.dart';

import '../bottom_panel/bottom_panel_state.dart';
import 'components/split_panel.dart';
import 'panel_defaults.dart' as panel_defaults;
import 'panel_presentation_state.dart';

/// Owns panel presentation, workspace splits, and bottom-tab selection independently of mounted views.
final class PanelLayoutController {
  PanelLayoutController({required this.isEmbedMode}) {
    final defaults = isEmbedMode ? panel_defaults.embed : panel_defaults.standalone;
    _preview = ValueNotifier(defaults.preview);
    _fileTree = ValueNotifier(defaults.fileTree);
    _bottom = ValueNotifier(defaults.bottom);
    _bottomSplit = _BottomSplitListenable(_bottom);
    _appBar = ValueNotifier(defaults.appBar);
    _statusBar = ValueNotifier(defaults.statusBar);
  }

  final bool isEmbedMode;
  late final ValueNotifier<SplitState> _preview;
  late final ValueNotifier<SplitState> _fileTree;
  late final ValueNotifier<BottomPanelState> _bottom;
  late final ValueListenable<SplitState> _bottomSplit;
  late final ValueNotifier<PanelPresentationState> _appBar;
  late final ValueNotifier<PanelPresentationState> _statusBar;

  SplitState get preview => _preview.value;
  SplitState get fileTree => _fileTree.value;
  BottomPanelState get bottom => _bottom.value;
  PanelPresentationState get appBar => _appBar.value;
  PanelPresentationState get statusBar => _statusBar.value;

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

  /// A new workspace starts with the same defaults as a newly mounted layout.
  void reset({required double previewRatio}) {
    final defaults = isEmbedMode ? panel_defaults.embed : panel_defaults.standalone;
    _preview.value = Split(previewRatio);
    _fileTree.value = defaults.fileTree;
    _bottom.value = defaults.bottom;
    _appBar.value = defaults.appBar;
    _statusBar.value = defaults.statusBar;
  }

  void updateAppBar(PanelPresentationState state) => _appBar.value = state;

  void updateStatusBar(PanelPresentationState state) => _statusBar.value = state;

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
      _ => throw ArgumentError.value(state, 'state', 'The bottom panel can only expand or collapse.'),
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
  };

  @override
  void addListener(VoidCallback listener) => _bottom.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _bottom.removeListener(listener);
}

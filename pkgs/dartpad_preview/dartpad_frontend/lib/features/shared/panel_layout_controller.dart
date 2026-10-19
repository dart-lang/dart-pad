// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/jaspr.dart';

import '../bottom_panel/bottom_panel_state.dart';
import 'components/split_panel.dart';
import 'panel_defaults.dart';
import 'panel_presentation.dart';

/// Owns panel presentation, workspace splits, and bottom-tab selection independently of mounted views.
final class PanelLayoutController extends ChangeNotifier {
  PanelLayoutController({required this.isEmbedMode, Iterable<String> files = const []}) {
    _applyDefaults(files: files);
  }

  final bool isEmbedMode;
  late SplitState _preview;
  late SplitState _fileTree;
  late BottomPanelState _bottom;
  late PanelPresentation _appBar;
  late PanelPresentation _statusBar;
  late bool _showEditorTabs;
  late bool _showBreadcrumbs;

  SplitState get preview => _preview;
  SplitState get fileTree => _fileTree;
  BottomPanelState get bottom => _bottom;
  PanelPresentation get appBar => _appBar;
  PanelPresentation get statusBar => _statusBar;
  bool get showEditorTabs => _showEditorTabs;
  bool get showBreadcrumbs => _showBreadcrumbs;

  SplitState get bottomSplit => switch (_bottom) {
    BottomPanelExpanded(:final editorFraction) => Split(editorFraction),
    BottomPanelCollapsed(:final editorFraction) => RightCollapsed(editorFraction),
  };

  /// Apply at the start of a project load, before the user can change its layout.
  void applyInitialDefaults({required double previewRatio, Iterable<String> files = const []}) {
    _applyDefaults(previewRatio: previewRatio, files: files);
    notifyListeners();
  }

  void _applyDefaults({double? previewRatio, required Iterable<String> files}) {
    final defaults = PanelDefaults.resolve(isEmbedMode: isEmbedMode, files: files, previewRatio: previewRatio);
    _preview = defaults.preview;
    _fileTree = defaults.fileTree;
    _bottom = defaults.bottom;
    _appBar = defaults.appBar;
    _statusBar = defaults.statusBar;
    _showEditorTabs = defaults.showEditorTabs;
    _showBreadcrumbs = defaults.showBreadcrumbs;
  }

  void updateAppBar(PanelPresentation state) {
    if (_appBar == state) {
      return;
    }
    _appBar = state;
    notifyListeners();
  }

  void updateStatusBar(PanelPresentation state) {
    if (_statusBar == state) {
      return;
    }
    _statusBar = state;
    notifyListeners();
  }

  void updatePreview(SplitState state) {
    if (_preview == state) {
      return;
    }
    _preview = state;
    notifyListeners();
  }

  void updateFileTree(SplitState state) {
    if (_fileTree == state) {
      return;
    }
    _fileTree = state;
    notifyListeners();
  }

  /// Adapts splitter interactions without introducing a second bottom state.
  void updateBottomSplit(SplitState state) {
    _setBottom(switch (state) {
      Split(:final value) => BottomPanelExpanded(_bottom.selectedTab, editorFraction: value),
      RightCollapsed(:final lastSplitValue) => BottomPanelCollapsed(
        _bottom.selectedTab,
        editorFraction: lastSplitValue,
      ),
      _ => throw ArgumentError.value(state, 'state', 'The bottom panel can only expand or collapse.'),
    });
  }

  void openBottomPanel(BottomPanelTab tab) =>
      _setBottom(BottomPanelExpanded(tab, editorFraction: _bottom.editorFraction));

  void collapseBottomPanel() =>
      _setBottom(BottomPanelCollapsed(_bottom.selectedTab, editorFraction: _bottom.editorFraction));

  void expandPreview() => updatePreview(Split(_preview.value));

  void _setBottom(BottomPanelState state) {
    if (_bottom == state) {
      return;
    }
    _bottom = state;
    notifyListeners();
  }
}

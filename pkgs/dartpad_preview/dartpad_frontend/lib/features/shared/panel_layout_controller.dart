// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/jaspr.dart';

import '../bottom_panel/bottom_panel_state.dart';
import 'components/split_panel.dart';
import 'panel_defaults.dart';

/// Owns workspace splits and bottom-tab selection independently of mounted views.
final class PanelLayoutController extends ChangeNotifier {
  PanelLayoutController({required this.isEmbedMode}) {
    _applyDefaults();
  }

  final bool isEmbedMode;
  late SplitState _preview;
  late SplitState _fileTree;
  late BottomPanelState _bottom;

  SplitState get preview => _preview;
  SplitState get fileTree => _fileTree;
  BottomPanelState get bottom => _bottom;

  SplitState get bottomSplit => switch (_bottom) {
    BottomPanelExpanded(:final editorFraction) => Split(editorFraction),
    BottomPanelCollapsed(:final editorFraction) => RightCollapsed(editorFraction),
  };

  /// A new workspace starts with the same defaults as a newly mounted layout.
  void reset({required double previewRatio}) {
    _applyDefaults(previewRatio);
    notifyListeners();
  }

  void _applyDefaults([double? previewRatio]) {
    final defaults = isEmbedMode ? PanelDefaults.embed : PanelDefaults.standalone;
    _preview = previewRatio == null ? defaults.preview : Split(previewRatio);
    _fileTree = defaults.fileTree;
    _bottom = defaults.bottom;
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

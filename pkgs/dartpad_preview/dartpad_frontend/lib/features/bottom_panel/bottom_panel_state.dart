// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:meta/meta.dart';

/// The contents available in the shared bottom panel.
enum BottomPanelTab {
  /// The problems tab showing diagnostics.
  problems,

  /// The debug console tab showing application logs.
  console,
}

/// Selection and size survive collapsing or hiding the panel.
@immutable
sealed class BottomPanelState {
  const BottomPanelState(this.selectedTab, {required this.editorFraction});

  final BottomPanelTab selectedTab;

  /// Fraction of the combined height occupied by the editor when expanded.
  /// For example, 0.7 gives the editor 70% and the bottom panel 30%.
  /// Retained while collapsed so reopening restores the same heights.
  final double editorFraction;

  bool get isExpanded => this is BottomPanelExpanded;

  @override
  bool operator ==(Object other) =>
      other is BottomPanelState &&
      runtimeType == other.runtimeType &&
      selectedTab == other.selectedTab &&
      editorFraction == other.editorFraction;

  @override
  int get hashCode => Object.hash(runtimeType, selectedTab, editorFraction);
}

final class BottomPanelExpanded extends BottomPanelState {
  const BottomPanelExpanded(super.selectedTab, {required super.editorFraction});
}

final class BottomPanelCollapsed extends BottomPanelState {
  const BottomPanelCollapsed(super.selectedTab, {required super.editorFraction});
}

/// Hides the entire bottom area, including both tab buttons.
final class BottomPanelHidden extends BottomPanelState {
  const BottomPanelHidden(super.selectedTab, {required super.editorFraction});
}

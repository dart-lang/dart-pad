// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';

/// The collapse, hidden, and split state of a split panel.
@immutable
sealed class SplitState {
  const SplitState();

  /// Whether either panel is collapsed to its intrinsic/rail size.
  bool get isCollapsed => this is LeftCollapsed || this is RightCollapsed;

  /// Whether the left panel is collapsed.
  bool get isLeftCollapsed => this is LeftCollapsed;

  /// Whether the right panel is collapsed.
  bool get isRightCollapsed => this is RightCollapsed;

  /// Whether neither panel is collapsed or hidden.
  bool get isSplit => this is Split;

  /// Whether either panel is hidden completely.
  bool get isHidden => this is LeftHidden || this is RightHidden;

  /// Whether the left panel is hidden.
  bool get isLeftHidden => this is LeftHidden;

  /// Whether the right panel is hidden.
  bool get isRightHidden => this is RightHidden;

  /// The active split value or the last split value when collapsed or hidden.
  double get value => switch (this) {
    Split(:final value) => value,
    LeftCollapsed(:final lastSplitValue) => lastSplitValue,
    RightCollapsed(:final lastSplitValue) => lastSplitValue,
    LeftHidden(:final lastSplitValue) => lastSplitValue,
    RightHidden(:final lastSplitValue) => lastSplitValue,
  };
}

/// The left (or top) panel is completely hidden (`display: none`) and the drag handle is hidden.
final class LeftHidden extends SplitState {
  const LeftHidden(this.lastSplitValue);
  final double lastSplitValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is LeftHidden && other.lastSplitValue == lastSplitValue);

  @override
  int get hashCode => Object.hash(LeftHidden, lastSplitValue);
}

/// The left (or top) panel is collapsed to its intrinsic size with the drag handle visible.
final class LeftCollapsed extends SplitState {
  const LeftCollapsed(this.lastSplitValue);
  final double lastSplitValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is LeftCollapsed && other.lastSplitValue == lastSplitValue);

  @override
  int get hashCode => Object.hash(LeftCollapsed, lastSplitValue);
}

/// Both panels are active and sized according to [value], with the drag handle visible.
final class Split extends SplitState {
  const Split(this.value);

  @override
  final double value;

  @override
  bool operator ==(Object other) => identical(this, other) || (other is Split && other.value == value);

  @override
  int get hashCode => Object.hash(Split, value);
}

/// The right (or bottom) panel is collapsed to its intrinsic size with the drag handle visible.
final class RightCollapsed extends SplitState {
  const RightCollapsed(this.lastSplitValue);
  final double lastSplitValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is RightCollapsed && other.lastSplitValue == lastSplitValue);

  @override
  int get hashCode => Object.hash(RightCollapsed, lastSplitValue);
}

/// The right (or bottom) panel is completely hidden (`display: none`) and the drag handle is hidden.
final class RightHidden extends SplitState {
  const RightHidden(this.lastSplitValue);
  final double lastSplitValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is RightHidden && other.lastSplitValue == lastSplitValue);

  @override
  int get hashCode => Object.hash(RightHidden, lastSplitValue);
}

///// An inherited component that exposes [SplitPanelData] to descendants of a [SplitPanel].
class _InheritedSplitPanel extends InheritedComponent {
  _InheritedSplitPanel({required this.data, required super.child});

  final SplitPanelData data;

  @override
  bool updateShouldNotify(covariant _InheritedSplitPanel oldComponent) {
    return data != oldComponent.data;
  }
}

@immutable
class SplitPanelData {
  SplitPanelData({
    required this._splitPanelState,
    required this._isLeft,
    required this.state,
  });

  /// The state of the enclosing [SplitPanel].
  final SplitPanelState _splitPanelState;

  /// Whether this inherited scope is for the left (or top) child panel.
  final bool _isLeft;

  /// The state of the split panel when this component was created.
  final SplitState state;

  /// Whether the panel on this side of the split can be collapsed.
  bool get canCollapse => _isLeft ? _splitPanelState.canCollapseLeft : _splitPanelState.canCollapseRight;

  /// Whether the panel on this side of the split is collapsed.
  bool get isPanelCollapsed => _isLeft ? _splitPanelState.isLeftCollapsed : _splitPanelState.isRightCollapsed;

  /// Whether the panel on this side of the split is hidden.
  bool get isPanelHidden => _isLeft ? _splitPanelState.isLeftHidden : _splitPanelState.isRightHidden;

  void expand([double? targetValue]) {
    _splitPanelState.split(targetValue);
  }

  void collapse() {
    if (_isLeft) {
      _splitPanelState.collapseLeft();
    } else {
      _splitPanelState.collapseRight();
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SplitPanelData &&
          other._splitPanelState == _splitPanelState &&
          other._isLeft == _isLeft &&
          other.state == state);

  @override
  int get hashCode => Object.hash(_splitPanelState, _isLeft, state);
}

/// A component that divides its layout space between two sub-components,
/// allowing the user to resize the boundary between them by dragging a splitter handle.
class SplitPanel extends StatefulComponent {
  const SplitPanel({
    required this.left,
    required this.right,
    this.canCollapseLeft,
    this.canCollapseRight,
    this.initialState,
    this.initialValue = 0.5,
    this.useRatio = true,
    this.isVertical = false,
    this.absoluteFirst = true,
    this.minValue,
    this.maxValue,
    super.key,
  });

  /// The left or top component in the split panel.
  final Component left;

  /// The right or bottom component in the split panel.
  final Component right;

  /// Whether the left (or top) panel can be collapsed.
  final bool? canCollapseLeft;

  /// Whether the right (or bottom) panel can be collapsed.
  final bool? canCollapseRight;

  /// The initial collapse or split state. If null, defaults to [Split] with [initialValue].
  final SplitState? initialState;

  /// The initial split value (either ratio or absolute pixels).
  final double initialValue;

  /// Whether the split value represents a ratio (0.0 to 1.0) rather than absolute pixels.
  final bool useRatio;

  /// Whether to orient the split layout vertically (top/bottom) instead of horizontally (left/right).
  final bool isVertical;

  /// When using absolute sizes, whether the absolute value applies to the first (left/top) panel.
  /// If false, it applies to the second (right/bottom) panel.
  final bool absoluteFirst;

  /// The minimum allowable split value (ratio or pixel limit).
  final double? minValue;

  /// The maximum allowable split value (ratio or pixel limit).
  final double? maxValue;

  /// Returns the [SplitPanelData] from the nearest ancestor.
  static SplitPanelData? of(BuildContext context, {bool listen = true}) {
    if (listen) {
      return context.dependOnInheritedComponentOfExactType<_InheritedSplitPanel>()?.data;
    }
    return (context.getElementForInheritedComponentOfExactType<_InheritedSplitPanel>()?.component
            as _InheritedSplitPanel?)
        ?.data;
  }

  @override
  State<SplitPanel> createState() => SplitPanelState();
}

class SplitPanelState extends State<SplitPanel> {
  late SplitState _state;

  /// The current collapse, hidden, or split state.
  SplitState get state => _state;

  /// The current split value (ratio 0.0 to 1.0, or absolute pixels).
  double get value => _state.value;

  /// Whether the left (or top) panel can be collapsed.
  bool get canCollapseLeft => component.canCollapseLeft ?? (_state is LeftCollapsed);

  /// Whether the right (or bottom) panel can be collapsed.
  bool get canCollapseRight => component.canCollapseRight ?? (_state is RightCollapsed);

  /// Whether either panel is currently collapsed.
  bool get isCollapsed => _state.isCollapsed;

  /// Whether the left (or top) panel is collapsed.
  bool get isLeftCollapsed => _state.isLeftCollapsed;

  /// Whether the right (or bottom) panel is collapsed.
  bool get isRightCollapsed => _state.isRightCollapsed;

  /// Whether neither panel is collapsed or hidden.
  bool get isSplit => _state.isSplit;

  /// Backwards-compatible alias for [isSplit].
  bool get isUncollapsed => _state.isSplit;

  /// Whether either panel is hidden completely.
  bool get isHidden => _state.isHidden;

  /// Whether the left (or top) panel is hidden.
  bool get isLeftHidden => _state.isLeftHidden;

  /// Whether the right (or bottom) panel is hidden.
  bool get isRightHidden => _state.isRightHidden;

  /// Collapses the left (or top) panel.
  void collapseLeft() {
    setState(() => _state = LeftCollapsed(_state.value));
  }

  /// Collapses the right (or bottom) panel.
  void collapseRight() {
    setState(() => _state = RightCollapsed(_state.value));
  }

  /// Hides the left (or top) panel completely.
  void hideLeft() {
    setState(() => _state = LeftHidden(_state.value));
  }

  /// Hides the right (or bottom) panel completely.
  void hideRight() {
    setState(() => _state = RightHidden(_state.value));
  }

  /// Splits the panel to [targetValue] or restores the previous split size.
  void split([double? targetValue]) {
    setState(() => _state = Split(targetValue ?? _state.value));
  }

  void _updateFromDrag(SplitState newState) {
    if (_state != newState) {
      setState(() {
        _state = newState;
      });
    }
  }

  bool isDragging = false;
  bool _dragStartedWhileCollapsed = false;
  double _dragStartPos = 0;
  StreamSubscription<web.MouseEvent>? _mouseMoveSubscription;
  StreamSubscription<web.MouseEvent>? _mouseUpSubscription;

  @override
  void initState() {
    super.initState();
    _state = component.initialState ?? Split(component.initialValue);
  }

  @override
  void didUpdateComponent(SplitPanel oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (component.initialState != null && component.initialState != oldComponent.initialState) {
      _state = component.initialState!;
    } else if (oldComponent.initialValue != component.initialValue) {
      _state = Split(component.initialValue);
    }
  }

  void _startResizing(web.MouseEvent event) {
    event.preventDefault();

    final dragHandle = event.currentTarget as web.HTMLElement?;
    final container = dragHandle?.parentElement;
    if (container == null) {
      return;
    }

    setState(() {
      isDragging = true;
    });

    final startPos = component.isVertical ? event.clientY.toDouble() : event.clientX.toDouble();
    _dragStartPos = startPos;
    _dragStartedWhileCollapsed = (canCollapseRight && isRightCollapsed) || (canCollapseLeft && isLeftCollapsed);

    _mouseMoveSubscription?.cancel();
    _mouseMoveSubscription = web.EventStreamProviders.mouseMoveEvent.forTarget(web.window).listen((web.MouseEvent e) {
      final rect = container.getBoundingClientRect();
      final totalSize = component.isVertical ? rect.height : rect.width;
      final startOffset = component.isVertical ? rect.top : rect.left;
      if (totalSize <= 0) {
        return;
      }

      final clientPos = (component.isVertical ? e.clientY : e.clientX).toDouble();

      if (canCollapseRight) {
        final currentSecondPos = startOffset + totalSize - clientPos;

        final double minSecond;
        final double maxSecond;
        if (component.useRatio) {
          final minRatio = component.minValue ?? 0.15;
          final maxRatio = component.maxValue ?? 0.85;
          minSecond = totalSize * (1.0 - maxRatio);
          maxSecond = totalSize * (1.0 - minRatio);
        } else if (component.absoluteFirst) {
          final minFirst = component.minValue ?? 100.0;
          final maxFirst = component.maxValue ?? (totalSize - 100.0);
          minSecond = totalSize - maxFirst;
          maxSecond = totalSize - minFirst;
        } else {
          minSecond = component.minValue ?? 100.0;
          maxSecond = component.maxValue ?? (totalSize - 100.0);
        }

        final effectiveMin = max(0.0, min(minSecond, totalSize * 0.5));
        final effectiveMax = max(effectiveMin, maxSecond);

        // Auto-collapse threshold when dragging smaller than effectiveMin
        final collapseThreshold = effectiveMin - 30;

        if (_dragStartedWhileCollapsed) {
          // Drag started while collapsed: delta is how much the user dragged up/towards open
          final delta = _dragStartPos - clientPos;
          if (isRightCollapsed) {
            if (delta > 10) {
              final targetSize = max(effectiveMin, currentSecondPos).clamp(effectiveMin, effectiveMax);
              final newValue = _valueFromSecondSize(targetSize, totalSize);
              _updateFromDrag(Split(newValue));
              if (currentSecondPos > collapseThreshold + 15) {
                _dragStartedWhileCollapsed = false;
              }
            }
          } else {
            // Already auto-expanded during this drag gesture
            if (delta < 5) {
              _updateFromDrag(RightCollapsed(value));
            } else {
              final targetSize = max(effectiveMin, currentSecondPos).clamp(effectiveMin, effectiveMax);
              final newValue = _valueFromSecondSize(targetSize, totalSize);
              _updateFromDrag(Split(newValue));
              if (currentSecondPos > collapseThreshold + 15) {
                _dragStartedWhileCollapsed = false;
              }
            }
          }
          return;
        }

        // Drag started while already expanded
        if (isRightCollapsed) {
          // If it auto-collapsed during this drag, can auto-expand if dragged back up
          if (currentSecondPos > collapseThreshold + 15) {
            final targetSize = currentSecondPos.clamp(effectiveMin, effectiveMax);
            final newValue = _valueFromSecondSize(targetSize, totalSize);
            _updateFromDrag(Split(newValue));
          }
        } else {
          // Expanded: if dragged too small (below collapseThreshold), auto-collapse
          if (currentSecondPos < collapseThreshold) {
            _updateFromDrag(RightCollapsed(value));
          } else {
            final targetSize = currentSecondPos.clamp(effectiveMin, effectiveMax);
            final newValue = _valueFromSecondSize(targetSize, totalSize);
            _updateFromDrag(Split(newValue));
          }
        }
        return;
      }

      if (canCollapseLeft) {
        final currentFirstPos = clientPos - startOffset;

        final double minFirst;
        final double maxFirst;
        if (component.useRatio) {
          final minRatio = component.minValue ?? 0.15;
          final maxRatio = component.maxValue ?? 0.85;
          minFirst = totalSize * minRatio;
          maxFirst = totalSize * maxRatio;
        } else if (component.absoluteFirst) {
          minFirst = component.minValue ?? 100.0;
          maxFirst = component.maxValue ?? (totalSize - 100.0);
        } else {
          final minSecond = component.minValue ?? 100.0;
          final maxSecond = component.maxValue ?? (totalSize - 100.0);
          minFirst = totalSize - maxSecond;
          maxFirst = totalSize - minSecond;
        }

        final effectiveMin = max(0.0, min(minFirst, totalSize * 0.5));
        final effectiveMax = max(effectiveMin, maxFirst);

        // Auto-collapse threshold when dragging smaller than effectiveMin
        final collapseThreshold = effectiveMin - 30;

        if (_dragStartedWhileCollapsed) {
          // Drag started while collapsed: delta is how much the user dragged right/down towards open
          final delta = clientPos - _dragStartPos;
          if (isLeftCollapsed) {
            if (delta > 10) {
              final targetSize = max(effectiveMin, currentFirstPos).clamp(effectiveMin, effectiveMax);
              final newValue = _valueFromFirstSize(targetSize, totalSize);
              _updateFromDrag(Split(newValue));
              if (currentFirstPos > collapseThreshold + 15) {
                _dragStartedWhileCollapsed = false;
              }
            }
          } else {
            // Already auto-expanded during this drag gesture
            if (delta < 5) {
              _updateFromDrag(LeftCollapsed(value));
            } else {
              final targetSize = max(effectiveMin, currentFirstPos).clamp(effectiveMin, effectiveMax);
              final newValue = _valueFromFirstSize(targetSize, totalSize);
              _updateFromDrag(Split(newValue));
              if (currentFirstPos > collapseThreshold + 15) {
                _dragStartedWhileCollapsed = false;
              }
            }
          }
          return;
        }

        // Drag started while already expanded
        if (isLeftCollapsed) {
          // If it auto-collapsed during this drag, can auto-expand if dragged back right
          if (currentFirstPos > collapseThreshold + 15) {
            final targetSize = currentFirstPos.clamp(effectiveMin, effectiveMax);
            final newValue = _valueFromFirstSize(targetSize, totalSize);
            _updateFromDrag(Split(newValue));
          }
        } else {
          // Expanded: if dragged too small (below collapseThreshold), auto-collapse
          if (currentFirstPos < collapseThreshold) {
            _updateFromDrag(LeftCollapsed(value));
          } else {
            final targetSize = currentFirstPos.clamp(effectiveMin, effectiveMax);
            final newValue = _valueFromFirstSize(targetSize, totalSize);
            _updateFromDrag(Split(newValue));
          }
        }
        return;
      }

      if (component.useRatio) {
        var newRatio = (clientPos - startOffset) / totalSize;

        final minR = component.minValue ?? 0.15;
        final maxR = component.maxValue ?? 0.85;
        if (newRatio < minR) {
          newRatio = minR;
        }
        if (newRatio > maxR) {
          newRatio = maxR;
        }
        _updateFromDrag(Split(newRatio));
      } else {
        var newValue = component.absoluteFirst ? (clientPos - startOffset) : (startOffset + totalSize - clientPos);

        final minV = component.minValue ?? 100.0;
        final maxV = component.maxValue ?? (totalSize - 100.0);
        if (newValue < minV) {
          newValue = minV;
        }
        if (newValue > maxV) {
          newValue = maxV;
        }
        _updateFromDrag(Split(newValue));
      }
    });

    _mouseUpSubscription?.cancel();
    _mouseUpSubscription = web.EventStreamProviders.mouseUpEvent.forTarget(web.window).listen((web.MouseEvent e) {
      _stopResizing();
    });
  }

  void _stopResizing() {
    _mouseMoveSubscription?.cancel();
    _mouseMoveSubscription = null;
    _mouseUpSubscription?.cancel();
    _mouseUpSubscription = null;
    _dragStartedWhileCollapsed = false;
    setState(() {
      isDragging = false;
    });
  }

  double _valueFromFirstSize(double firstSize, double totalSize) {
    if (component.useRatio) {
      final ratio = firstSize / totalSize;
      return ratio.clamp(component.minValue ?? 0.15, component.maxValue ?? 0.85);
    } else if (component.absoluteFirst) {
      return firstSize.clamp(component.minValue ?? 100.0, component.maxValue ?? (totalSize - 100.0));
    } else {
      final secondVal = totalSize - firstSize;
      return secondVal.clamp(component.minValue ?? 100.0, component.maxValue ?? (totalSize - 100.0));
    }
  }

  double _valueFromSecondSize(double secondSize, double totalSize) {
    if (component.useRatio) {
      final ratio = 1.0 - (secondSize / totalSize);
      return ratio.clamp(component.minValue ?? 0.15, component.maxValue ?? 0.85);
    } else if (component.absoluteFirst) {
      final firstVal = totalSize - secondSize;
      return firstVal.clamp(component.minValue ?? 100.0, component.maxValue ?? (totalSize - 100.0));
    } else {
      return secondSize.clamp(component.minValue ?? 100.0, component.maxValue ?? (totalSize - 100.0));
    }
  }

  @override
  void dispose() {
    _mouseMoveSubscription?.cancel();
    _mouseUpSubscription?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final leftChild = component.left;
    final rightChild = component.right;
    final state = _state;

    final Flex leftFlex;
    final Flex rightFlex;
    final Display? leftDisplay;
    final Display? rightDisplay;
    final bool showDragHandle;

    switch (state) {
      case LeftHidden():
        leftFlex = const Flex.shrink(0);
        rightFlex = const Flex(grow: 1, basis: .zero);
        leftDisplay = .none;
        rightDisplay = null;
        showDragHandle = false;
      case RightHidden():
        leftFlex = const Flex(grow: 1, basis: .zero);
        rightFlex = const Flex.shrink(0);
        leftDisplay = null;
        rightDisplay = .none;
        showDragHandle = false;
      case LeftCollapsed():
        leftFlex = const Flex.shrink(0);
        rightFlex = const Flex(grow: 1, basis: .zero);
        leftDisplay = null;
        rightDisplay = null;
        showDragHandle = true;
      case RightCollapsed():
        leftFlex = const Flex(grow: 1, basis: .zero);
        rightFlex = const Flex.shrink(0);
        leftDisplay = null;
        rightDisplay = null;
        showDragHandle = true;
      case Split(:final value):
        leftFlex = component.useRatio
            ? Flex(grow: value, basis: .zero)
            : (component.absoluteFirst ? Flex(grow: 0, basis: value.px) : const Flex(grow: 1, basis: .zero));
        rightFlex = component.useRatio
            ? Flex(grow: 1 - value, basis: .zero)
            : (component.absoluteFirst ? const Flex(grow: 1, basis: .zero) : Flex(grow: 0, basis: value.px));
        leftDisplay = null;
        rightDisplay = null;
        showDragHandle = true;
    }

    return Component.fragment([
      _InheritedSplitPanel(
        data: SplitPanelData(splitPanelState: this, isLeft: true, state: state),
        child: Component.apply(
          styles: Styles(
            display: leftDisplay,
            pointerEvents: isDragging ? .none : null,
            flex: leftFlex,
          ),
          child: leftChild,
        ),
      ),
      if (showDragHandle)
        div(
          classes: 'drag-handle ${component.isVertical ? 'vertical' : 'horizontal'}${isDragging ? ' dragging' : ''}',
          events: {
            'mousedown': (e) => _startResizing(e as web.MouseEvent),
          },
          [],
        ),
      _InheritedSplitPanel(
        data: SplitPanelData(splitPanelState: this, isLeft: false, state: state),
        child: Component.apply(
          styles: Styles(
            display: rightDisplay,
            pointerEvents: isDragging ? .none : null,
            flex: rightFlex,
          ),
          child: rightChild,
        ),
      ),
    ]);
  }

  static const width = 8;

  @css
  static List<StyleRule> get styles => [
    css('.drag-handle').styles(
      position: const .relative(),
      zIndex: const ZIndex(10),
      userSelect: .none,
      flex: const .shrink(0),
      backgroundColor: Colors.transparent,
    ),
    // Horizontal Specific Styles
    css('.drag-handle.horizontal').styles(
      width: width.px,
      margin: Margin.symmetric(horizontal: (-2).px),
      cursor: .colResize,
    ),
    css('.drag-handle.horizontal::after').styles(
      content: '',
      position: .absolute(top: 0.px, bottom: 0.px, left: 2.px),
      width: (width - 4).px,
      backgroundColor: colorBorder,
    ),
    css('.drag-handle.horizontal:hover::after, .drag-handle.horizontal.dragging::after').styles(
      transition: Transition('background-color', duration: 150.ms, curve: .ease),
      backgroundColor: colorPrimary,
    ),
    // Vertical Specific Styles
    css('.drag-handle.vertical').styles(
      height: width.px,
      margin: Margin.symmetric(vertical: (-2).px),
      cursor: .rowResize,
    ),
    css('.drag-handle.vertical::after').styles(
      content: '',
      position: .absolute(left: 0.px, right: 0.px, top: 2.px),
      height: (width - 4).px,
      backgroundColor: colorBorder,
    ),
    css('.drag-handle.vertical:hover::after, .drag-handle.vertical.dragging::after').styles(
      transition: Transition('background-color', duration: 150.ms, curve: .ease),
      backgroundColor: colorPrimary,
    ),
  ];
}

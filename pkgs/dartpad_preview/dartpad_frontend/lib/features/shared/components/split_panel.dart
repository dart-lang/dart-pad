import 'dart:async';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

class SplitPanel extends StatefulComponent {
  const SplitPanel({
    required this.left,
    required this.right,
    this.showLeft = true,
    this.showRight = true,
    this.initialValue = 0.5,
    this.useRatio = true,
    this.isVertical = false,
    this.absoluteFirst = true,
    this.minValue,
    this.maxValue,
    super.key,
  });

  final Component left;
  final Component right;
  final double initialValue;
  final bool showLeft;
  final bool showRight;
  final bool useRatio;
  final bool isVertical;
  final bool absoluteFirst;
  final double? minValue;
  final double? maxValue;

  @override
  State<SplitPanel> createState() => _SplitPanelState();
}

class _SplitPanelState extends State<SplitPanel> {
  late double value;
  bool isDragging = false;
  StreamSubscription<web.MouseEvent>? _mouseMoveSubscription;
  StreamSubscription<web.MouseEvent>? _mouseUpSubscription;

  @override
  void initState() {
    super.initState();
    value = component.initialValue;
  }

  @override
  void didUpdateComponent(SplitPanel oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.initialValue != component.initialValue) {
      value = component.initialValue;
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

    _mouseMoveSubscription?.cancel();
    _mouseMoveSubscription = web.EventStreamProviders.mouseMoveEvent.forTarget(web.window).listen((web.MouseEvent e) {
      final rect = container.getBoundingClientRect();
      final totalSize = component.isVertical ? rect.height : rect.width;
      final startOffset = component.isVertical ? rect.top : rect.left;
      if (totalSize <= 0) {
        return;
      }

      if (component.useRatio) {
        final clientPos = component.isVertical ? e.clientY : e.clientX;
        var newRatio = (clientPos - startOffset) / totalSize;

        final minR = component.minValue ?? 0.15;
        final maxR = component.maxValue ?? 0.85;
        if (newRatio < minR) {
          newRatio = minR;
        }
        if (newRatio > maxR) {
          newRatio = maxR;
        }
        setState(() {
          value = newRatio;
        });
      } else {
        final clientPos = component.isVertical ? e.clientY : e.clientX;
        var newValue = component.absoluteFirst ? (clientPos - startOffset) : (startOffset + totalSize - clientPos);

        final minV = component.minValue ?? 100.0;
        final maxV = component.maxValue ?? (totalSize - 100.0);
        if (newValue < minV) {
          newValue = minV;
        }
        if (newValue > maxV) {
          newValue = maxV;
        }
        setState(() {
          value = newValue;
        });
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
    setState(() {
      isDragging = false;
    });
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

    final leftFlex = component.useRatio
        ? Flex(grow: component.showRight ? value : 1, basis: .zero)
        : (component.showRight
              ? (component.absoluteFirst ? Flex(grow: 0, basis: value.px) : const Flex(grow: 1, basis: .zero))
              : const Flex(grow: 1, basis: .zero));

    final rightFlex = component.useRatio
        ? Flex(grow: component.showLeft ? 1 - value : 1, basis: .zero)
        : (component.showLeft
              ? (component.absoluteFirst ? const Flex(grow: 1, basis: .zero) : Flex(grow: 0, basis: value.px))
              : const Flex(grow: 1, basis: .zero));

    return Component.fragment([
      Component.wrapElement(
        styles: Styles(
          display: !component.showLeft ? .none : null,
          pointerEvents: isDragging ? .none : null,
          flex: leftFlex,
        ),
        child: leftChild,
      ),
      if (component.showLeft && component.showRight)
        div(
          classes: 'drag-handle ${component.isVertical ? 'vertical' : 'horizontal'}${isDragging ? ' dragging' : ''}',
          events: {
            'mousedown': (e) => _startResizing(e as web.MouseEvent),
          },
          [],
        ),
      Component.wrapElement(
        styles: Styles(
          display: !component.showRight ? .none : null,
          pointerEvents: isDragging ? .none : null,
          flex: rightFlex,
        ),
        child: rightChild,
      ),
    ]);
  }
}

// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

/// Viewport coordinates used to position a file tree context menu.
typedef FileTreeCoordinates = ({double x, double y});

/// Reveals a row without scrolling any ancestor of the file-tree viewport.
void scrollFileTreeRowIntoView(web.HTMLElement node, {required int depth}) {
  final root = node.closest('.file-tree-list');
  if (root == null) {
    return;
  }

  // scrollIntoView also scrolls the page hosting DartPad's iframe. Compute the
  // offset inside the tree instead, leaving room for sticky parent folder rows.
  final offset = node.getBoundingClientRect().top - root.getBoundingClientRect().top - root.clientTop;
  root.scrollTo(
    web.ScrollToOptions(
      top: root.scrollTop + offset - 25 * depth,
      behavior: 'instant',
    ),
  );
}

/// A stateful wrapper component that applies CSS classes and indentation style
/// for a file tree row, and handles drag-and-drop state and events.
class FileTreeRow extends StatefulComponent {
  const FileTreeRow({
    required this.depth,
    this.classes = '',
    this.attributes = const {},
    this.events = const {},
    this.path,
    this.isDraggable = false,
    this.onContextMenu,
    this.onDrop,
    required this.children,
    super.key,
  });

  /// The indentation depth in the file tree.
  final int depth;

  /// The CSS classes for the row element.
  final String classes;

  /// HTML attributes for the row element.
  final Map<String, String> attributes;

  /// Event handlers for the row element.
  final Map<String, void Function(web.Event)> events;

  /// The path of the resource this row represents, required for drag/drop.
  final String? path;

  /// Whether the row can be dragged as a move operation source.
  final bool isDraggable;

  /// Opens the row's context menu at the given viewport coordinates.
  final void Function(FileTreeCoordinates coordinates)? onContextMenu;

  /// Callback when a resource path is dropped onto this row.
  /// If null, drop events are not handled.
  final void Function(String sourcePath)? onDrop;

  /// The children of this row.
  final List<Component> children;

  @override
  State<FileTreeRow> createState() => _FileTreeRowState();
}

class _FileTreeRowState extends State<FileTreeRow> {
  bool _isDragging = false;
  bool _isDropTarget = false;
  int _dragEnterCount = 0;
  late final _contextMenuGesture = _ContextMenuGesture((x, y) => component.onContextMenu?.call((x: x, y: y)));

  @override
  void dispose() {
    _contextMenuGesture.dispose();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    // Disable dragging for coarse pointers.
    final isDraggable =
        component.isDraggable && component.path != null && !web.window.matchMedia('(pointer: coarse)').matches;
    final isDropTarget = component.onDrop != null && component.path != null;

    final resolvedClasses = [
      component.classes,
      if (_isDragging) 'dragging',
      if (_isDropTarget) 'drop-target',
    ].where((c) => c.isNotEmpty).join(' ');

    return div(
      classes: resolvedClasses,
      styles: Styles(raw: {'--tree-depth': '${component.depth}'}),
      attributes: {
        ...component.attributes,
        if (isDraggable) 'draggable': 'true',
      },
      events: {
        ...component.events,
        if (component.onContextMenu != null) ..._contextMenuGesture.events,
        if (isDraggable) ...{
          'dragstart': (web.Event event) {
            final dragEvent = event as web.DragEvent;
            dragEvent.dataTransfer?.setData('text/plain', component.path!);
            dragEvent.dataTransfer?.effectAllowed = 'move';
            setState(() {
              _isDragging = true;
            });
          },
          'dragend': (web.Event event) => setState(() {
            _isDragging = false;
          }),
        },
        if (isDropTarget) ...{
          'dragover': (web.Event event) {
            event
              ..stopPropagation()
              ..preventDefault();
          },
          'dragenter': (web.Event event) {
            event
              ..stopPropagation()
              ..preventDefault();
            _dragEnterCount++;
            if (!_isDropTarget) {
              setState(() {
                _isDropTarget = true;
              });
            }
          },
          'dragleave': (web.Event event) {
            event.stopPropagation();
            _dragEnterCount--;
            if (_dragEnterCount <= 0) {
              _dragEnterCount = 0;
              if (_isDropTarget) {
                setState(() {
                  _isDropTarget = false;
                });
              }
            }
          },
          'drop': (web.Event event) {
            event
              ..stopPropagation()
              ..preventDefault();
            _dragEnterCount = 0;
            setState(() {
              _isDropTarget = false;
            });
            final dragEvent = event as web.DragEvent;
            final sourcePath = dragEvent.dataTransfer?.getData('text/plain');
            if (sourcePath != null && sourcePath != component.path) {
              component.onDrop!(sourcePath);
            }
          },
        },
      },
      component.children,
    );
  }
}

/// Handles context menu events and touch long presses on a file tree row.
///
/// Android browsers can emit `contextmenu` on long press, while iOS Safari
/// may not emit it for non-draggable rows. A timer opens the menu if the
/// browser event doesn't arrive first.
class _ContextMenuGesture {
  _ContextMenuGesture(this._onOpen);

  final void Function(double x, double y) _onOpen;

  static const _longPressDuration = Duration(milliseconds: 600);
  static const _touchSlop = 10;

  Timer? _longPressTimer;
  int? _touchPointer;
  double _touchX = 0;
  double _touchY = 0;
  bool _touchMenuOpened = false;

  Map<String, void Function(web.Event)> get events => {
    'pointerdown': _onPointerDown,
    'pointermove': _onPointerMove,
    'pointerup': _onPointerEnd,
    'pointercancel': _onPointerEnd,
    'contextmenu': _onContextMenu,
  };

  void _onPointerDown(web.Event event) {
    final pointer = event as web.PointerEvent;
    if (pointer.pointerType != 'touch') {
      return;
    }
    if (_touchPointer != null || !pointer.isPrimary) {
      _cancelTouch();
      return;
    }

    _touchPointer = pointer.pointerId;
    _touchX = _coordinate(pointer, 'clientX');
    _touchY = _coordinate(pointer, 'clientY');
    _touchMenuOpened = false;
    // Safari does not dispatch contextmenu for a long press on these rows.
    _longPressTimer = Timer(_longPressDuration, () {
      _touchMenuOpened = true;
      _onOpen(_touchX, _touchY);
    });
  }

  void _onPointerMove(web.Event event) {
    final pointer = event as web.PointerEvent;
    if (pointer.pointerId != _touchPointer) {
      return;
    }
    final dx = _coordinate(pointer, 'clientX') - _touchX;
    final dy = _coordinate(pointer, 'clientY') - _touchY;
    if (dx * dx + dy * dy > _touchSlop * _touchSlop) {
      _longPressTimer?.cancel();
    }
  }

  // Firefox on Android can report fractional CSS pixels, although package:web
  // declares MouseEvent.clientX/clientY as integers. Reading those getters
  // directly throws a type error for fractional values.
  double _coordinate(web.MouseEvent event, String property) => event.getProperty<JSNumber>(property.toJS).toDartDouble;

  void _onPointerEnd(web.Event event) {
    final pointer = event as web.PointerEvent;
    if (pointer.pointerId != _touchPointer) {
      return;
    }
    _cancelTouch();
  }

  void _cancelTouch() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _touchPointer = null;
  }

  void _onContextMenu(web.Event event) {
    event.preventDefault();
    event.stopPropagation();
    _longPressTimer?.cancel();
    if (_touchPointer != null && _touchMenuOpened) {
      return;
    }
    _touchMenuOpened = _touchPointer != null;
    final mouseEvent = event as web.MouseEvent;
    _onOpen(
      _coordinate(mouseEvent, 'clientX'),
      _coordinate(mouseEvent, 'clientY'),
    );
  }

  void dispose() => _cancelTouch();
}

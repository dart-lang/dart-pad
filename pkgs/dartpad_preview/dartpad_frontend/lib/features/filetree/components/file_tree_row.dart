// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

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

  @override
  Component build(BuildContext context) {
    final isDraggable = component.isDraggable && component.path != null;
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

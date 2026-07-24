// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/client.dart';
import 'package:web/web.dart' as web;

/// Inserts a DOM node managed by CodeMirror into Jaspr's render tree.
class NodeContainer extends Component {
  /// Creates a component that inserts [containerNode] into the render tree.
  const NodeContainer(
    this.containerNode, {
    this.onAttached,
  });

  /// The externally managed DOM node (e.g. CodeMirror's root element).
  final web.Node containerNode;

  /// Called after Jaspr has attached [containerNode] to the DOM.
  final void Function()? onAttached;

  @override
  Element createElement() => _NodeContainerElement(this);
}

class _NodeContainerElement extends LeafRenderObjectElement {
  _NodeContainerElement(NodeContainer super.component);

  @override
  RenderObject createRenderObject() {
    final parent = parentRenderObjectElement!.renderObject;
    final container = component as NodeContainer;
    return _NodeContainerRenderObject(
      container.containerNode,
      container.onAttached,
    )..parent = parent as DomRenderObject;
  }

  @override
  void updateRenderObject(RenderObject renderObject) {
    final container = component as NodeContainer;
    final nodeRenderObject = renderObject as _NodeContainerRenderObject;
    assert(identical(nodeRenderObject.node, container.containerNode));
    nodeRenderObject.onAttached = container.onAttached;
  }
}

class _NodeContainerRenderObject extends DomRenderObject {
  _NodeContainerRenderObject(this.node, this.onAttached);

  @override
  final web.Node node;

  void Function()? onAttached;

  @override
  void attach(covariant RenderObject child, {covariant RenderObject? after}) {
    throw UnsupportedError('NodeContainer cannot contain managed children.');
  }

  @override
  void remove(covariant RenderObject child) {
    throw UnsupportedError('NodeContainer cannot remove managed children.');
  }

  @override
  void finalize() {
    onAttached?.call();
  }

  @override
  web.Node? retakeNode(bool Function(web.Node node) visitNode) => null;
}

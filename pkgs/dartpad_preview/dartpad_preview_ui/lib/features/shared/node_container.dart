import 'package:jaspr/client.dart';
import 'package:web/web.dart' as web;

/// Inserts a DOM node managed by CodeMirror into Jaspr's render tree.
class NodeContainer extends Component {
  const NodeContainer(this.containerNode);

  final web.Node containerNode;

  @override
  Element createElement() => _NodeContainerElement(this);
}

class _NodeContainerElement extends LeafRenderObjectElement {
  _NodeContainerElement(NodeContainer super.component);

  @override
  RenderObject createRenderObject() {
    final parent = parentRenderObjectElement!.renderObject;
    return _NodeContainerRenderObject((component as NodeContainer).containerNode)..parent = parent as DomRenderObject;
  }

  @override
  void updateRenderObject(RenderObject renderObject) {}
}

class _NodeContainerRenderObject extends DomRenderObject {
  _NodeContainerRenderObject(this.node);

  @override
  final web.Node node;

  @override
  void attach(covariant RenderObject child, {covariant RenderObject? after}) {
    throw UnsupportedError('NodeContainer cannot contain managed children.');
  }

  @override
  void remove(covariant RenderObject child) {
    throw UnsupportedError('NodeContainer cannot remove managed children.');
  }

  @override
  void finalize() {}

  @override
  web.Node? retakeNode(bool Function(web.Node node) visitNode) => null;
}


library dartpad_ui.elements;

import 'dart:async';
import 'dart:html';

class DElement {
  final Element element;

  DElement(this.element);
  DElement.tag(String tag) : element = new Element.tag(tag);

  bool hasAttr(String name) => element.attributes.containsKey(name);

  void toggleAttr(String name, bool value) {
    value ? element.setAttribute(name, '') : element.attributes.remove(name);
  }

  String getAttr(String name) => element.getAttribute(name);

  void setAttr(String name, [String value = '']) => element.setAttribute(name, value);

  String clearAttr(String name) => element.attributes.remove(name);

  Stream<Event> get onClick => element.onClick;

  void dispose() {
    if (element.parent.children.contains(element)) {
      try {
        element.parent.children.remove(element);
      } catch (e) {
        print('foo');
      }
    }
  }

  String toString() => element.toString();
}

class DButton extends DElement {
  DButton(ButtonElement element) : super(element);

  ButtonElement get belement => element;

  bool get disabled => belement.disabled;
  set disabled(bool value) => belement.disabled = value;
}

class DSplitter extends DElement {
  DSplitter(Element element) : super(element) {
    _init();
  }

  DSplitter.createHorizontal() : super.tag('div') {
    horizontal = true;
    _init();
  }

  DSplitter.createVertical() : super.tag('div') {
    vertical = true;
    _init();
  }

  bool get horizontal => hasAttr('horizontal');
  set horizontal(bool value) {
    clearAttr(value ? 'vertical' : 'horizontal');
    setAttr(value ? 'horizontal' : 'vertical');
  }

  bool get vertical => hasAttr('vertical');
  set vertical(bool value) {
    clearAttr(value ? 'horizontal' : 'vertical');
    setAttr(value ? 'vertical' : 'horizontal');
  }

  void _init() {
    element.classes.toggle('splitter', true);
    if (!horizontal && !vertical) {
      horizontal = true;
    }

    // TODO:

  }
}

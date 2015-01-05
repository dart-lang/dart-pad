
library dartpad_ui.elements;

import 'dart:async';
import 'dart:html';

class DElement {
  final Element element;

  //DElement(String tag) : element = new Element.tag(tag);
  DElement(this.element);

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

class BButton extends DElement {
  BButton(ButtonElement element) : super(element);

  ButtonElement get belement => element;

  bool get disabled => belement.disabled;
  set disabled(bool value) => belement.disabled = value;
}


library liftoff.elements;

import 'dart:async';
import 'dart:html';

class BComponent {
  final Element element;

  BComponent(this.element);

  String get text => element.text;
  set text(String value) => element.text = value;

  Stream<MouseEvent> get onClick => element.onClick;

  void attr(String name, String value) {
    if (value == null) {
      element.attributes.remove(name);
    } else {
      element.attributes[name] = value;
    }
  }

  bool hasAttr(String name) => element.attributes.containsKey(name);
}

class BButton extends BComponent {
  BButton(ButtonElement element) : super(element);

  ButtonElement get belement => element;

  bool get disabled => belement.disabled;
  set disabled(bool value) => belement.disabled = value;
}

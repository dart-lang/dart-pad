// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library base;

import 'dart:async';
import 'dart:html';

/**
 * Finds the first descendant element of this document with the given id.
 */
Element queryId(String id) => querySelector('#${id}');

/**
 * Finds the first descendant element of this document that matches the specified group of selectors.
 */
Element $(String selectors) => querySelector(selectors);

class WebElement {
  final HtmlElement element;

  WebElement(String tag, {String text}) : element = new Element.tag(tag) {
    if (text != null) element.text = text;
  }

  WebElement.from(this.element);

  String get tagName => element.tagName;

  String get id => attribute('id');
  set id(String value) => setAttribute('id', value);

  bool hasAttribute(String name) => element.attributes.containsKey(name);

  void toggleAttribute(String name, [bool value]) {
    if (value == null) value = !element.attributes.containsKey(name);

    if (value) {
      element.setAttribute(name, '');
    } else {
      element.attributes.remove(name);
    }
  }

  void clickAction(Function f) {
    this.onClick.listen((e) {
      e.stopPropagation();
      e.stopImmediatePropagation();
      f();
    });
  }
  
  String attribute(String name) => element.getAttribute(name);

  void setAttribute(String name, [String value = '']) =>
      element.setAttribute(name, value);

  String clearAttribute(String name) => element.attributes.remove(name);

  void clazz(String _class) {
    if (_class.contains(' ')) {
      throw new ArgumentError('spaces not allowed in class names');
    }
    element.classes.add(_class);
  }

  set text(String value) {
    element.text = value;
  }

  /**
   * Add the given child to this element's list of children. [child] must be
   * either a `WebElement` or an `Element`.
   */
  void add(dynamic child) {
    if (child is WebElement) {
      element.children.add(child.element);
    } else if (child is Element) {
      element.children.add(child);
    } else {
      throw new ArgumentError('child must be a WebElement or an Element');
    }
  }

  Stream<Event> get onClick => element.onClick;

  void dispose() {
    if (element.parent.children.contains(element)) {
      try {
        element.parent.children.remove(element);
      } catch (e) {
        // TODO:
        print('foo');
      }
    }
  }

  String toString() => element.toString();
}

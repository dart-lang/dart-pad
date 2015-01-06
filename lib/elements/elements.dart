// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_ui.elements;

import 'dart:async';
import 'dart:html';
import 'dart:math' as math;

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
        // TODO:
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

// TODO: get the position
// TODO: set the position
// TODO: fire events for position change
class DSplitter extends DElement {
  Point _offset = new Point(0, 0);

  StreamSubscription _moveSub;
  StreamSubscription _upSub;

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
    if (!horizontal && !vertical) horizontal = true;

    element.onMouseDown.listen((e) {
      e.preventDefault();
      _offset = e.screen;
      num initialTargetSize = _targetSize;

      _moveSub = document.onMouseMove.listen(
          (e) => _handleDrag(e.screen - _offset, initialTargetSize));
      _upSub = document.onMouseUp.listen((e) {
        if (_moveSub != null) _moveSub.cancel();
        if (_upSub != null) _upSub.cancel();
      });
    });
  }

  void _handleDrag(Point point, num initialTargetSize) {
    if (horizontal) {
      _targetSize = initialTargetSize + point.y;
    } else {
      _targetSize = initialTargetSize + point.x;
    }
  }

  Element get _target {
    List children = element.parent.children;
    return children[children.indexOf(element) - 1];
  }

  num get _targetSize {
    CssStyleDeclaration style = _target.getComputedStyle();
    String str = vertical ? style.height : style.width;
    if (str.endsWith('px')) str = str.substring(0, str.length - 2);
    return num.parse(str);
  }

  num _minSize(Element e) {
    CssStyleDeclaration style = e.style;
    String str = vertical ? style.minWidth : style.minHeight;
    if (str.isEmpty) return 0;
    if (str.endsWith('px')) str = str.substring(0, str.length - 2);
    return num.parse(str);
  }

  set _targetSize(num size) {
    num min = _minSize(_target);
    print(min);
    size = math.max(size, _minSize(_target));

    if (horizontal) {
      _target.style.height = '${size}px';
    } else {
      _target.style.width = '${size}px';
    }
  }
}

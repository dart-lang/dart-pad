// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.elements;

import 'dart:async';
import 'dart:html';
import 'dart:math' as math;

import 'bind.dart';

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

  String get text => element.text;

  set text(String value) {
    element.text = value;
  }

  Property get textProperty => new _ElementTextProperty(element);

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

class DSplitter extends DElement {
  StreamController<num> _controller = new StreamController.broadcast();

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

  num get position => _targetSize;

  set position(num value) {
    _targetSize = value;
  }

  Stream<num> get onPositionChanged => _controller.stream;

  void _init() {
    element.classes.toggle('splitter', true);
    if (!horizontal && !vertical) horizontal = true;

    if (element.querySelector('div.inner') == null) {
      Element e = new DivElement();
      e.classes.add('inner');
      element.children.add(e);
    }

    var cancel = () {
      if (_moveSub != null) _moveSub.cancel();
      if (_upSub != null) _upSub.cancel();
    };

    element.onMouseDown.listen((e) {
      if (e.which != 1) return;

      e.preventDefault();
      _offset = e.offset;

      _moveSub = document.onMouseMove.listen((e) {
        if (e.which != 1) {
          cancel();
        } else {
          Point current = e.client - element.parent.client.topLeft - _offset;
          current -= _target.marginEdge.topLeft;
          _handleDrag(current);
        }
      });

      _upSub = document.onMouseUp.listen((e) {
        cancel();
      });
    });

    // TODO: implement touch events
    Point touchOffset;

    element.onTouchStart.listen((TouchEvent e) {
      if (e.targetTouches.isEmpty) return;
      // TODO:

      e.preventDefault();

//      touchOffset
//      Point current = e.targetTouches.first.client;
    });

    element.onTouchMove.listen((TouchEvent e) {
      if (e.targetTouches.isEmpty) return;

      e.preventDefault();

      if (touchOffset == null) touchOffset = new Point(0, 0);

      Point current = e.targetTouches.first.client;
      current -= _target.marginEdge.topLeft - touchOffset;
      _handleDrag(current - touchOffset);
    });
  }

  void _handleDrag(Point size) {
    _targetSize = vertical ? size.x : size.y;
  }

  Element get _target {
    List children = element.parent.children;
    return children[children.indexOf(element) - 1];
  }

  num _minSize(Element e) {
    CssStyleDeclaration style = e.getComputedStyle();
    String str = vertical ? style.minWidth : style.minHeight;
    if (str.isEmpty) return 0;
    if (str.endsWith('px')) str = str.substring(0, str.length - 2);
    return num.parse(str);
  }

  num get _targetSize {
    CssStyleDeclaration style = _target.getComputedStyle();
    String str = vertical ? style.width : style.height;
    if (str.endsWith('px')) str = str.substring(0, str.length - 2);
    return num.parse(str);
  }

  set _targetSize(num size) {
    final num currentPos = _controller.hasListener ? position : null;

    size = math.max(size, _minSize(_target));

    if (_target.attributes.containsKey('flex')) {
      _target.attributes.remove('flex');
    }

    if (vertical) {
      _target.style.width = '${size}px';
    } else {
      _target.style.height = '${size}px';
    }

    if (_controller.hasListener) {
      num newPos = position;
      if (currentPos != newPos) _controller.add(newPos);
    }
  }
}

class DSplash extends DElement {
  DSplash(Element element) : super(element);

  void hide({bool removeOnHide: true}) {
    if (removeOnHide) {
      element.onTransitionEnd.listen((_) => dispose());
    }
    element.classes.toggle('hide', true);
  }
}

/**
 * A simple element that can display a lightbulb, with fade in and out and a
 * built in counter.
 */
class DBusyLight extends DElement {
  static final Duration _delay = const Duration(milliseconds: 150);

  int _count = 0;

  DBusyLight(Element element) : super(element);

  void on() {
    _count++;
    _reconcile();
  }

  void off() {
    _count--;
    if (_count < 0) _count = 0;
    _reconcile();
  }

  void flash() {
    on();
    new Future.delayed(_delay, off);
  }

  void reset() {
    _count = 0;
    _reconcile();
  }

  _reconcile() => element.classes.toggle('on', _count > 0);
}

// TODO: The label needs an extremely rich tooltip.

class DLabel extends DElement {
  DLabel(Element element) : super(element) {
    element.classes.toggle('label', true);
  }

  String get message => element.text;

  set message(String value) {
    element.text = value;
  }

  void clearError() {
    element.classes.removeAll(['error', 'warning', 'info']);
  }

  set error(final String value) {
    element.classes.toggle('error', value == 'error');
    element.classes.toggle('warning', value == 'warning');
    element.classes.toggle('info', value == 'info');
  }
}

class DOverlay extends DElement {
  DOverlay(Element element) : super(element);

  bool get visible => element.classes.contains('visible');
  set visible(bool value) {
    element.classes.toggle('visible', value);
  }
}

class DContentEditable extends DElement {
  DContentEditable(Element element) : super(element) {
    setAttr('contenteditable', 'true');

    element.onKeyPress.listen((e) {
      if (e.keyCode == 13) {
        e.preventDefault();
        element.blur();
      }
    });
  }

  Stream<String> get onChanged => element.on['input'].map((_) => element.text);
}

class DToast extends DElement {
  static void showMessage(String message) {
    new DToast(message)..show()..hide();
  }

  final String message;

  DToast(this.message) : super.tag('div') {
    element.classes.toggle('toast', true);
    element.text = message;
  }

  void show() {
    // Add to the DOM, start a timer, make it visible.
    document.body.children.add(element);

    Timer.run(() {
      element.classes.toggle('showing', true);
    });
  }

  void hide([Duration delay = const Duration(seconds: 4)]) {
    // Start a timer, hide, remove from dom.
    new Timer(delay, () {
      element.classes.toggle('showing', false);
      element.onTransitionEnd.first.then((event) {
        dispose();
      });
    });
  }
}

class _ElementTextProperty implements Property {
  final Element element;

  _ElementTextProperty(this.element);

  get() => element.text;

  void set(value) {
    element.text = value == null ? '' : value.toString();
  }

  // TODO:
  Stream get onChanged => null;
}

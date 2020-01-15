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

  DElement.tag(String tag, {String classes}) : element = Element.tag(tag) {
    if (classes != null) {
      element.classes.add(classes);
    }
  }

  bool hasAttr(String name) => element.attributes.containsKey(name);

  void toggleAttr(String name, bool value) {
    value ? setAttr(name) : clearAttr(name);
  }

  String getAttr(String name) => element.getAttribute(name);

  void setAttr(String name, [String value = '']) =>
      element.setAttribute(name, value);

  String clearAttr(String name) => element.attributes.remove(name);

  void toggleClass(String name, bool value) {
    value ? element.classes.add(name) : element.classes.remove(name);
  }

  bool hasClass(String name) => element.classes.contains(name);

  String get text => element.text;

  set text(String value) {
    element.text = value;
  }

  Property get textProperty => _ElementTextProperty(element);

  void layoutHorizontal() {
    setAttr('layout');
    setAttr('horizontal');
  }

  void layoutVertical() {
    setAttr('layout');
    setAttr('vertical');
  }

  void flex() => setAttr('flex');

  T add<T>(T child) {
    if (child is DElement) {
      element.children.add(child.element);
    } else {
      element.children.add(child as Element);
    }

    return child;
  }

  void clearChildren() {
    element.children.clear();
  }

  Stream<Event> get onClick => element.onClick;

  void dispose() {
    if (element.parent == null) return;

    if (element.parent.children.contains(element)) {
      try {
        element.parent.children.remove(element);
      } catch (e) {
        print('foo');
      }
    }
  }

  @override
  String toString() => element.toString();
}

class DButton extends DElement {
  DButton(ButtonElement element) : super(element);

  DButton.button({String text, String classes})
      : super.tag('button', classes: classes) {
    element.classes.add('button');
    if (text != null) {
      element.text = text;
    }
  }

  DButton.close() : super.tag('button', classes: 'close');

  ButtonElement get belement => element as ButtonElement;

  bool get disabled => belement.disabled;

  set disabled(bool value) {
    belement.disabled = value;
  }
}

class DSplitter extends DElement {
  final _controller = StreamController<num>.broadcast();

  final Function onDragStart;
  final Function onDragEnd;

  Point _offset = Point(0, 0);

  StreamSubscription _moveSub;
  StreamSubscription _upSub;

  DSplitter(Element element, {this.onDragStart, this.onDragEnd})
      : super(element) {
    _init();
  }

  DSplitter.createHorizontal({this.onDragStart, this.onDragEnd})
      : super.tag('div') {
    horizontal = true;
    _init();
  }

  DSplitter.createVertical({this.onDragStart, this.onDragEnd})
      : super.tag('div') {
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
      Element e = DivElement();
      e.classes.add('inner');
      element.children.add(e);
    }

    var cancel = () {
      if (_moveSub != null) _moveSub.cancel();
      if (_upSub != null) _upSub.cancel();
      if (onDragEnd != null) onDragEnd();
    };

    element.onMouseDown.listen((MouseEvent e) {
      if (e.button != 0) return;

      e.preventDefault();
      _offset = e.offset;

      if (onDragStart != null) onDragStart();

      _moveSub = document.onMouseMove.listen((MouseEvent e) {
        if (e.button != 0) {
          cancel();
        } else {
          var current = e.client - element.parent.client.topLeft - _offset;
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

      touchOffset ??= Point(0, 0);

      var current = e.targetTouches.first.client;
      current -= _target.marginEdge.topLeft - touchOffset;
      _handleDrag(current - touchOffset);
    });
  }

  void _handleDrag(Point size) {
    _targetSize = vertical ? size.x : size.y;
  }

  Element get _target {
    var children = element.parent.children;
    return children[children.indexOf(element) - 1];
  }

  num _minSize(Element e) {
    var style = e.getComputedStyle();
    var str = vertical ? style.minWidth : style.minHeight;
    if (str.endsWith('px')) {
      str = str.substring(0, str.length - 2);
      return num.parse(str);
    } else {
      return 0;
    }
  }

  num get _targetSize {
    var style = _target.getComputedStyle();
    var str = vertical ? style.width : style.height;
    if (str.endsWith('px')) {
      str = str.substring(0, str.length - 2);
      return num.parse(str);
    } else {
      return 0;
    }
  }

  set _targetSize(num size) {
    final currentPos = _controller.hasListener ? position : null;

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
      var newPos = position;
      if (currentPos != newPos) _controller.add(newPos);
    }
  }
}

class DSplash extends DElement {
  DSplash(Element element) : super(element);

  void hide({bool removeOnHide = true}) {
    if (removeOnHide) {
      element.onTransitionEnd.listen((_) => dispose());
    }
    element.classes.toggle('hide', true);
  }
}

/// A simple element that can display a lightbulb, with fade in and out and a
/// built in counter.
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
    Future.delayed(_delay, off);
  }

  void reset() {
    _count = 0;
    _reconcile();
  }

  void _reconcile() {
    if (_count == 0 || _count == 1) {
      element.classes.toggle('on', _count > 0);
    }
  }
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
      if (e.keyCode == KeyCode.ENTER) {
        e.preventDefault();
        element.blur();
      }
    });
  }

  Stream<String> get onChanged => element.on['input'].map((_) => element.text);
}

class DInput extends DElement {
  DInput(InputElement element) : super(element);

  DInput.input({String type}) : super(InputElement(type: type));

  InputElement get inputElement => element as InputElement;

  void readonly() => setAttr('readonly');

  String get value => inputElement.value;

  set value(String v) {
    inputElement.value = v;
  }

  void selectAll() {
    inputElement.select();
  }
}

class DToast extends DElement {
  static void showMessage(String message) {
    DToast(message)
      ..show()
      ..hide();
  }

  final String message;

  DToast(this.message) : super.tag('div') {
    element.classes..toggle('toast', true)..toggle('dialog', true);
    element.text = message;
  }

  void show() {
    // Add to the DOM, start a timer, make it visible.
    document.body.children.add(element);

    Timer(Duration(milliseconds: 16), () {
      element.classes.toggle('showing', true);
    });
  }

  void hide([Duration delay = const Duration(seconds: 4)]) {
    // Start a timer, hide, remove from dom.
    Timer(delay, () {
      element.classes.toggle('showing', false);
      element.onTransitionEnd.first.then((event) {
        dispose();
      });
    });
  }
}

class GlassPane extends DElement {
  final _controller = StreamController.broadcast();

  GlassPane() : super.tag('div') {
    element.classes.toggle('glass-pane', true);

    document.onKeyDown.listen((KeyboardEvent e) {
      if (e.keyCode == KeyCode.ESC) {
        e.preventDefault();
        _controller.add(null);
      }
    });

    element.onMouseDown.listen((e) {
      e.preventDefault();
      _controller.add(null);
    });
  }

  void show() {
    document.body.children.add(element);
  }

  void hide() => dispose();

  bool get isShowing => document.body.children.contains(element);

  Stream get onCancel => _controller.stream;
}

abstract class DDialog extends DElement {
  GlassPane pane = GlassPane();

  DElement titleArea;
  DElement content;
  DElement buttonArea;

  DDialog({String title}) : super.tag('div') {
    element.classes.addAll(['dialog', 'dialog-position']);
    setAttr('layout');
    setAttr('vertical');
    pane.onCancel.listen((_) {
      if (isShowing) hide();
    });

    titleArea = add(DElement.tag('div', classes: 'title'));
    content = add(DElement.tag('div', classes: 'content'));

    // padding
    add(DElement.tag('div'))..flex();

    buttonArea = add(DElement.tag('div', classes: 'buttons')
      ..setAttr('layout')
      ..setAttr('horizontal'));

    if (title != null) {
      titleArea.add(DElement.tag('h1')..text = title);
      titleArea.add(DButton.close()..onClick.listen((e) => hide()));
    }
  }

  void show() {
    pane.show();

    // Add to the DOM, start a timer, make it visible.
    document.body.children.add(element);

    Timer(Duration(milliseconds: 16), () {
      element.classes.toggle('showing', true);
    });
  }

  void hide() {
    if (!isShowing) return;

    pane.hide();

    // Start a timer, hide, remove from dom.
    Timer(Duration(milliseconds: 16), () {
      element.classes.toggle('showing', false);
      element.onTransitionEnd.first.then((event) {
        dispose();
      });
    });
  }

  void toggleShowing() {
    isShowing ? hide() : show();
  }

  bool get isShowing => document.body.children.contains(element);
}

class _ElementTextProperty implements Property {
  final Element element;

  _ElementTextProperty(this.element);

  @override
  String get() => element.text;

  @override
  void set(value) {
    element.text = value == null ? '' : value.toString();
  }

  // TODO:
  @override
  Stream get onChanged => null;
}

class TabController {
  final _selectedTabController = StreamController<TabElement>.broadcast();

  final tabs = <TabElement>[];

  void registerTab(TabElement tab) {
    tabs.add(tab);

    try {
      tab.onClick.listen((_) => selectTab(tab.name));
    } catch (e, st) {
      print('Error from registerTab: $e\n$st');
    }
  }

  TabElement get selectedTab =>
      tabs.firstWhere((tab) => tab.hasAttr('selected'));

  /// This method will throw if the tabName is not the name of a current tab.
  void selectTab(String tabName) {
    var tab = tabs.firstWhere((t) => t.name == tabName);

    for (var t in tabs) {
      t.toggleAttr('selected', t == tab);
    }

    tab.handleSelected();

    _selectedTabController.add(tab);
  }

  Stream<TabElement> get onTabSelect => _selectedTabController.stream;
}

class TabElement extends DElement {
  final String name;
  final Function onSelect;

  TabElement(Element element, {this.name, this.onSelect}) : super(element);

  void handleSelected() {
    if (onSelect != null) onSelect();
  }

  @override
  String toString() => name;
}

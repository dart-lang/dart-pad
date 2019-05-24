// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library iron;

import 'dart:async';
import 'dart:html';
import 'dart:js';

import 'base.dart';

class IronPages extends IronSelectableBehavior {
  IronPages() : super('iron-pages');

  IronPages.from(HtmlElement element) : super.from(element);
}

class IronIcon extends PolymerElement {
  IronIcon({String icon, String src}) : super('iron-icon') {
    if (icon != null) this.icon = icon;
    if (src != null) this.src = src;
  }

  IronIcon.from(HtmlElement element) : super.from(element);

  String get src => attribute('src');

  set src(String value) => setAttribute('src', value);
}

class IronOverlayBehavior extends PolymerElement {
  IronOverlayBehavior([String tag]) : super(tag == null ? 'core-overlay' : tag);

  IronOverlayBehavior.from(HtmlElement element) : super.from(element);

  /// Toggle the opened state of the overlay.
  void toggle() => call('toggle');

  /// Open the overlay. This is equivalent to setting the opened property to
  /// true.
  void open() => call('open');

  /// Close the overlay. This is equivalent to setting the opened property to
  /// false.
  void close() => call('close');
}

abstract class IronSelectableBehavior extends PolymerElement {
  IronSelectableBehavior(String tag) : super(tag);

  IronSelectableBehavior.from(HtmlElement element) : super.from(element);

  // TODO: add valueattr

  String get selected => "${property('selected')}";

  set selected(String value) {
    setAttribute('selected', value);
  }

  dynamic get selectedIndex => property('selectedIndex');

  Object get selectedItem => property('selectedItem');

  /// Selects the previous item.
  void selectPrevious() => call('selectPrevious');

  /// Selects the next item.
  void selectNext() => call('selectNext');

  ///   The event that fires from items when they are selected.
  ///   Selectable will listen for this event from items and update
  ///   the selection state. Set to empty string to listen to no events.
  Stream get ironActivate => listen('iron-activate');

  Stream get ironSelect => listen('iron-select');
}

class CoreSplitter extends PolymerElement {
  CoreSplitter() : super('core-splitter');

  CoreSplitter.from(HtmlElement element) : super.from(element);

  /// Possible values are left, right, up and down.
  String get direction => attribute('direction');

  set direction(String value) => setAttribute('direction', value);

  /// Minimum width to which the splitter target can be sized, e.g.
  /// minSize="100px".
  String get minSize => attribute('minSize');

  set minSize(String value) => setAttribute('minSize', value);

  /// Locks the split bar so it can't be dragged.
  bool get locked => hasAttribute('locked');

  set locked(bool value) => toggleAttribute('locked', value);

  /// By default the parent and siblings of the splitter are set to overflow
  /// hidden. This helps avoid elements bleeding outside the splitter regions.
  /// Set this property to true to allow these elements to overflow.
  bool get allowOverflow => hasAttribute('allowOverflow');

  set allowOverflow(bool value) => toggleAttribute('allowOverflow', value);
}

class PaperToolbar extends PolymerElement {
  PaperToolbar() : super('paper-toolbar');

  PaperToolbar.from(HtmlElement element) : super.from(element);
}

class PolymerElement extends WebElement {
  static PolymerElement div() => PolymerElement('div');

  static PolymerElement p([String text]) => PolymerElement('p', text: text);

  static PolymerElement section() => PolymerElement('section');

  static PolymerElement span([String text]) =>
      PolymerElement('span', text: text);

  JsObject _proxy;
  final _eventStreams = <String, Stream>{};

  PolymerElement(String tag, {String text}) : super(tag, text: text);

  PolymerElement.from(HtmlElement element) : super.from(element);

  void hidden([bool value]) => toggleAttribute('hidden', value);

  String get icon => attribute('icon');

  set icon(String value) => setAttribute('icon', value);

  String get label => attribute('label');

  set label(String value) => setAttribute('label', value);

  String get transitions => attribute('transitions');

  set transitions(String value) => setAttribute('transitions', value);

  bool get disabled => hasAttribute('disabled');

  set disabled(bool value) => toggleAttribute('disabled', value);

  Stream get onTap => listen('tap', sync: true);

  // Layout types.
  void layout() => toggleAttribute('layout');

  void horizontal() => toggleAttribute('horizontal');

  void vertical() => toggleAttribute('vertical');

  // Layout params.
  void fit() => toggleAttribute('fit');

  void flex([int flexAmount]) {
    toggleAttribute('flex', true);

    if (flexAmount != null) {
      if (flexAmount == 1) {
        toggleAttribute('one', true);
      } else if (flexAmount == 2) {
        toggleAttribute('two', true);
      } else if (flexAmount == 3) {
        toggleAttribute('three', true);
      } else if (flexAmount == 4) {
        toggleAttribute('four', true);
      } else if (flexAmount == 5) {
        toggleAttribute('five', true);
      }
    }
  }

  dynamic call(String methodName, [List args]) {
    _proxy ??= JsObject.fromBrowserObject(element);
    return _proxy.callMethod(methodName, args);
  }

  dynamic property(String name) {
    _proxy ??= JsObject.fromBrowserObject(element);
    return _proxy[name];
  }

  Stream listen(String eventName, {Function converter, bool sync = false}) {
    if (!_eventStreams.containsKey(eventName)) {
      StreamController controller = StreamController.broadcast(sync: sync);
      _eventStreams[eventName] = controller.stream;
      element.on[eventName].listen((e) {
        controller.add(converter == null ? e : converter(e));
      });
    }

    return _eventStreams[eventName];
  }

  @override
  void add(dynamic child) {
    if (child is WebElement) {
      child = child.element;
    } else if (child is Element) {
      child = child;
    } else {
      throw ArgumentError('child must be a WebElement or an Element');
    }
    //Polymer.dom(this).appendChild(child);
    context['Polymer']
        .callMethod('dom', [JsObject.fromBrowserObject(element)]).callMethod(
            'appendChild', [JsObject.fromBrowserObject(child)]);
  }

  dynamic selectorAll(String selector) {
    //Polymer.dom(this).childNodes;
    return context['Polymer']
        .callMethod('dom', [JsObject.fromBrowserObject(element)]).callMethod(
            'querySelectorAll', [selector]);
  }
}

class Transition {
  static void coreTransitionCenter(PolymerElement element) =>
      element.setAttribute('transition', 'core-transition-center');
}

class Transitions {
  static void slideFromRight(PolymerElement element) =>
      _add(element, 'slide-from-right');

  static void _add(PolymerElement element, String transitionId) {
    String t = element.transitions;
    t = t == null ? transitionId : '$t $transitionId';
    element.transitions = t;
  }
}

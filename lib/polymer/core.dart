// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library core;

import 'dart:async';
import 'dart:html';
import 'dart:js';

import 'base.dart';

class CoreAnimatedPages extends CoreSelector {
  CoreAnimatedPages() : super('core-animated-pages');
  CoreAnimatedPages.from(HtmlElement element) : super.from(element);
}

// core-drawer-panel
class CoreDrawerPanel extends CoreElement {
  CoreDrawerPanel() : super('core-drawer-panel');
  CoreDrawerPanel.from(HtmlElement element) : super.from(element);

  void forceNarrow() => toggleAttribute('forceNarrow');

  void makeDrawer(CoreElement element) =>
      element.toggleAttribute('drawer', true);

  void makeMain(CoreElement element) => element.toggleAttribute('main', true);

  /// Toggles the panel open and closed.
  void togglePanel() => call('togglePanel');

  /// Opens the drawer.
  void openDrawer() => call('openDrawer');

  /// Closes the drawer.
  void closeDrawer() => call('closeDrawer');
}

class CoreDropdown extends CoreOverlay {
  CoreDropdown([String tag]) : super(tag == null ? 'core-dropdown' : tag);
  CoreDropdown.from(HtmlElement element) : super.from(element);

  String get halign => attribute('halign');
  /// Accepted values: 'left', 'right'.
  set halign(String value) => setAttribute('halign', value);

  String get valign => attribute('valign');
  /// Accepted values: 'top', 'bottom'.
  set valign(String value) => setAttribute('valign', value);
}

class CoreHeaderPanel extends CoreElement {
  CoreHeaderPanel() : super('core-header-panel');
  CoreHeaderPanel.from(HtmlElement element) : super.from(element);
}

class CoreIcon extends CoreElement {
  CoreIcon({String icon, String src}) : super('core-item') {
    if (icon != null) this.icon = icon;
    if (src != null) this.src = src;
  }

  CoreIcon.from(HtmlElement element) : super.from(element);

  String get src => attribute('src');
  set src(String value) => setAttribute('src', value);
}

class CoreItem extends CoreElement {
  CoreItem({String icon, String label}) : super('core-item') {
    if (icon != null) this.icon = icon;
    if (label != null) this.label = label;
  }

  CoreItem.from(HtmlElement element) : super.from(element);

  void name(String value) => setAttribute('name', value);
}

class CoreMenu extends CoreSelector {
  CoreMenu() : super('core-menu');
  CoreMenu.from(HtmlElement element) : super.from(element);
}

class CoreOverlay extends CoreElement {
  CoreOverlay([String tag]) : super(tag == null ? 'core-overlay' : tag);
  CoreOverlay.from(HtmlElement element) : super.from(element);

  /**
   * Toggle the opened state of the overlay.
   */
  void toggle() => call('toggle');

  /**
   * Open the overlay. This is equivalent to setting the opened property to
   * true.
   */
  void open() => call('open');

  /**
   * Close the overlay. This is equivalent to setting the opened property to
   * false.
   */
  void close() => call('close');
}

abstract class CoreSelector extends CoreElement {
  Stream _coreActivateStream;

  CoreSelector(String tag) : super(tag);
  CoreSelector.from(HtmlElement element) : super.from(element);

  // TODO: add valueattr

  String get selected => property('selected');
  set selected(String value) => setAttribute('selected', value);

  dynamic get selectedIndex => property('selectedIndex');

  Object get selectedItem => property('selectedItem');

  /**
   * Selects the previous item; this should be used in single selection only.
   * This will wrap to the end if [wrapped] is `true` and it is already at the
   * first item.
   */
  void selectPrevious(bool wrapped) => call('selectPrevious', [wrapped]);

  /**
   * Selects the next item; this should be used in single selection only. This
   * will wrap to the front if [wrapped] is `true` and it is already at the last
   * item.
   */
  void selectNext(bool wrapped) => call('selectNext', [wrapped]);

  /**
   * Fired when an item's selection state is changed. This event is fired both
   * when an item is selected or deselected.
   */
  Stream get onCoreSelect => listen('core-select');

  /**
   * Fired when a selection is activated.
   */
  Stream get onCoreActivate => listen('core-activate');
}

class CoreSplitter extends CoreElement {
  CoreSplitter() : super('core-splitter');
  CoreSplitter.from(HtmlElement element) : super.from(element);

  /**
   * Possible values are left, right, up and down.
   */
  String get direction => attribute('direction');
  set direction(String value) => setAttribute('direction', value);

  /**
   * Minimum width to which the splitter target can be sized, e.g.
   * minSize="100px".
   */
  String get minSize => attribute('minSize');
  set minSize(String value) => setAttribute('minSize', value);

  /**
   * Locks the split bar so it can't be dragged.
   */
  bool get locked => hasAttribute('locked');
  set locked(bool value) => toggleAttribute('locked', value);

  /**
   * By default the parent and siblings of the splitter are set to overflow
   * hidden. This helps avoid elements bleeding outside the splitter regions.
   * Set this property to true to allow these elements to overflow.
   */
  bool get allowOverflow => hasAttribute('allowOverflow');
  set allowOverflow(bool value) => toggleAttribute('allowOverflow', value);
}

class CoreToolbar extends CoreElement {
  CoreToolbar() : super('core-toolbar');
  CoreToolbar.from(HtmlElement element) : super.from(element);
}

class CoreElement extends WebElement {
  static CoreElement div() => new CoreElement('div');
  static CoreElement p([String text]) => new CoreElement('p', text: text);
  static CoreElement section() => new CoreElement('section');
  static CoreElement span([String text]) => new CoreElement('span', text: text);

  JsObject _proxy;
  Map<String, Stream> _eventStreams = {};

  CoreElement(String tag, {String text}) : super(tag, text: text);
  CoreElement.from(HtmlElement element) : super.from(element);

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
      if (flexAmount == 1) toggleAttribute('one', true);
      else if (flexAmount == 2) toggleAttribute('two', true);
      else if (flexAmount == 3) toggleAttribute('three', true);
      else if (flexAmount == 4) toggleAttribute('four', true);
      else if (flexAmount == 5) toggleAttribute('five', true);
    }
  }

  dynamic call(String methodName, [List args]) {
    if (_proxy == null) _proxy = new JsObject.fromBrowserObject(element);
    return _proxy.callMethod(methodName, args);
  }

  dynamic property(String name) {
    if (_proxy == null) _proxy = new JsObject.fromBrowserObject(element);
    return _proxy[name];
  }

  Stream listen(String eventName, {Function converter, bool sync: false}) {
    if (!_eventStreams.containsKey(eventName)) {
      StreamController controller = new StreamController.broadcast(sync: sync);
      _eventStreams[eventName] = controller.stream;
      element.on[eventName].listen((e) {
        controller.add(converter == null ? e : converter(e));
      });
    }

    return _eventStreams[eventName];
  }
}

class Transition {
  static void coreTransitionCenter(CoreElement element) =>
      element.setAttribute('transition', 'core-transition-center');
}

class Transitions {
  static void slideFromRight(CoreElement element) =>
      _add(element, 'slide-from-right');

  static void _add(CoreElement element, String transitionId) {
    String t = element.transitions;
    t = t == null ? transitionId : '${t} ${transitionId}';
    element.transitions = t;
  }
}

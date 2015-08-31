// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library paper;

import 'dart:async';
import 'dart:html';
import 'dart:js';

import 'iron.dart';

class PaperDrawerPanel extends PolymerElement {
  PaperDrawerPanel() : super('paper-drawer-panel');
  PaperDrawerPanel.from(HtmlElement element) : super.from(element);

  void forceNarrow() => toggleAttribute('forceNarrow');

  void makeDrawer(PolymerElement element) =>
      element.toggleAttribute('drawer', true);

  void makeMain(PolymerElement element) =>
      element.toggleAttribute('main', true);

  /// Toggles the panel open and closed.
  void togglePanel() => call('togglePanel');

  /// Opens the drawer.
  void openDrawer() => call('openDrawer');

  /// Closes the drawer.
  void closeDrawer() => call('closeDrawer');
}

class PaperHeaderPanel extends PolymerElement {
  PaperHeaderPanel() : super('paper-header-panel');
  PaperHeaderPanel.from(HtmlElement element) : super.from(element);
}

class PaperMenu extends IronSelectableBehavior {
  PaperMenu() : super('paper-menu');
  PaperMenu.from(HtmlElement element) : super.from(element);

  void select(String value) {
    call("select", [value]);
  }

  String get selectedName {
    int index = new JsObject.fromBrowserObject(element)["selected"];
    return new PaperItem.from(selectorAll("paper-item")[index]).name;
  }
}

class PaperActionDialog extends PaperDialogBase {
  PaperActionDialog() : super('paper-action-dialog');
  PaperActionDialog.from(HtmlElement element) : super.from(element);

  void makeAffirmative(PolymerElement element) =>
      element.toggleAttribute('affirmative', true);

  void makeDismissive(PolymerElement element) =>
      element.toggleAttribute('dismissive', true);
}

class PaperButton extends PaperButtonBase {
  PaperButton({String text}) : super('paper-button', text: text);
  PaperButton.from(HtmlElement element) : super.from(element);

  bool get raised => hasAttribute('raised');
  set raised(bool value) => toggleAttribute('raised', value);
}

abstract class PaperButtonBase extends PolymerElement {
  PaperButtonBase(String tag, {String text}) : super(tag, text: text);
  PaperButtonBase.from(HtmlElement element) : super.from(element);
}

class PaperDialog extends PaperDialogBase {
  PaperDialog() : super('paper-dialog');
  PaperDialog.from(HtmlElement element) : super.from(element);
}

class PaperDialogBase extends IronOverlayBehavior {
  PaperDialogBase([String tag])
      : super(tag == null ? 'paper-dialog-base' : tag);
  PaperDialogBase.from(HtmlElement element) : super.from(element);

  String get heading => attribute('heading');
  set heading(String value) => setAttribute('heading', value);
}

class PaperFab extends PaperButtonBase {
  PaperFab({String icon, bool mini}) : super('paper-fab') {
    if (icon != null) this.icon = icon;
    if (mini != null) this.mini = mini;
  }

  PaperFab.from(HtmlElement element) : super.from(element);

  bool get mini => hasAttribute('mini');
  set mini(bool value) => toggleAttribute('mini', value);
}

class PaperIconButton extends PolymerElement {
  PaperIconButton({String icon}) : super('paper-icon-button') {
    if (icon != null) this.icon = icon;
  }

  PaperIconButton.from(HtmlElement element) : super.from(element);
}

class PaperItem extends PaperButtonBase {
  PaperItem({String text, String icon}) : super('paper-item', text: text) {
    if (icon != null) this.icon = icon;
  }

  PaperItem.from(HtmlElement element) : super.from(element);

  String get name => attribute("name");
  set name(String value) => setAttribute('name', value);
}

// TODO: extends core-dropdown-base
class PaperMenuButton extends PolymerElement {
  PaperMenuButton() : super('paper-menu-button');
  PaperMenuButton.from(HtmlElement element) : super.from(element);
}

class PaperSpinner extends PolymerElement {
  PaperSpinner() : super('paper-spinner');
  PaperSpinner.from(HtmlElement element) : super.from(element);

  bool get active => hasAttribute('active');
  set active(bool value) => toggleAttribute('active', value);
}

class PaperTabs extends IronSelectableBehavior {
  PaperTabs() : super('paper-tabs');
  PaperTabs.from(HtmlElement element) : super.from(element);

  String get selectedName {
    return new PaperTab.from(property("focusedItem")).name;
  }
}

class PaperTab extends PolymerElement {
  String name;
  PaperTab({String name, String text}) : super('paper-tab', text: text) {
    if (name != null) {
      setAttribute('name', name);
      this.name = name;
    }
  }

  PaperTab.from(HtmlElement element) : super.from(element) {
    name = attribute("name");
  }
}

class PaperToast extends PolymerElement {
  PaperToast({String text}) : super('paper-toast') {
    if (text != null) this.text = text;
  }
  PaperToast.from(HtmlElement element) : super.from(element);

  String get text => attribute('text');
  set text(String value) => setAttribute('text', value);

  /**
   * The duration in milliseconds to show the toast (this defaults to 3000ms).
   */
  // TODO: set the JS property
  set duration(int value) => setAttribute('duration', '${value}');

  /// True if the toast is currently visible.
  bool get visible => hasAttribute('visible');

  /// Toggle the opened state of the toast.
  void toggle() => call('toggle');

  /// Show the toast.
  void show() => call('show');

  /// Show the toast.
  void hide() => call('hide');
}

class PaperToggleButton extends PolymerElement {
  PaperToggleButton() : super('paper-toggle-button');
  PaperToggleButton.from(HtmlElement element) : super.from(element);

  // TODO: get checked is not corrent -
  bool get checked => property('checked');
  set checked(bool value) => toggleAttribute('checked', value);

  bool get disabled => hasAttribute('disabled');
  set disabled(bool value) => toggleAttribute('disabled', value);

  /**
   * Fired when the checked state changes due to user interaction.
   */
  Stream get onChange => listen('change');

  /**
   * Fired when the checked state changes.
   */
  Stream get onIronChange => listen('iron-change');
}

class PaperProgress extends PolymerElement {
  PaperProgress() : super('paper-progress');
  PaperProgress.from(HtmlElement element) : super.from(element);

  bool get indeterminate => hasAttribute('indeterminate');
  set indeterminate(bool value) => toggleAttribute('indeterminate', value);
}

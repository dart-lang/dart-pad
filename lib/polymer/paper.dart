// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library paper;

import 'dart:async';
import 'dart:html';

import 'core.dart';

class PaperActionDialog extends PaperDialogBase {
  PaperActionDialog() : super('paper-action-dialog');
  PaperActionDialog.from(HtmlElement element) : super.from(element);

  void makeAffirmative(CoreElement element) =>
      element.toggleAttribute('affirmative', true);

  void makeDismissive(CoreElement element) =>
      element.toggleAttribute('dismissive', true);
}

class PaperButton extends PaperButtonBase {
  PaperButton({String text}) : super('paper-button', text: text);
  PaperButton.from(HtmlElement element) : super.from(element);

  bool get raised => hasAttribute('raised');
  set raised(bool value) => toggleAttribute('raised', value);
}

abstract class PaperButtonBase extends CoreElement {
  PaperButtonBase(String tag, {String text}) : super(tag, text: text);
  PaperButtonBase.from(HtmlElement element) : super.from(element);
}

class PaperDialog extends PaperDialogBase {
  PaperDialog() : super('paper-dialog');
  PaperDialog.from(HtmlElement element) : super.from(element);
}

class PaperDialogBase extends CoreOverlay {
  PaperDialogBase([String tag]) : super(tag == null ? 'paper-dialog-base' : tag);
  PaperDialogBase.from(HtmlElement element) : super.from(element);

  String get heading => attribute('heading');
  set heading(String value) => setAttribute('heading', value);
}

class PaperDropdown extends CoreDropdown {
  PaperDropdown() : super('paper-dropdown') {
    clazz('dropdown core-transition');
  }
  PaperDropdown.from(HtmlElement element) : super.from(element);
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

class PaperIconButton extends CoreElement {
  PaperIconButton({String icon}) : super('paper-icon-button') {
    if (icon != null) this.icon = icon;
  }

  PaperIconButton.from(HtmlElement element) : super.from(element);
}

class PaperItem extends PaperButtonBase {
  PaperItem({String text, String icon}) :
      super('paper-item', text: text) {
    if (icon != null) this.icon = icon;
  }

  PaperItem.from(HtmlElement element) : super.from(element);

  void name(String value) => setAttribute('name', value);
}

// TODO: extends core-dropdown-base
class PaperMenuButton extends CoreElement {
  PaperMenuButton() : super('paper-menu-button');
  PaperMenuButton.from(HtmlElement element) : super.from(element);
}

class PaperSpinner extends CoreElement {
  PaperSpinner() : super('paper-spinner');
  PaperSpinner.from(HtmlElement element) : super.from(element);

  bool get active => hasAttribute('active');
  set active(bool value) => toggleAttribute('active', value);
}

class PaperTabs extends CoreSelector {
  PaperTabs() : super('paper-tabs');
  PaperTabs.from(HtmlElement element) : super.from(element);
}

class PaperTab extends CoreElement {
  PaperTab({String name, String text}) : super('paper-tab', text: text) {
    if (name != null) setAttribute('name', name);
  }

  PaperTab.from(HtmlElement element) : super.from(element);
}

class PaperToast extends CoreElement {
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

  /// Set opened to true to show the toast and to false to hide it.
  bool get opened => hasAttribute('opened');
  set opened(bool value) => toggleAttribute('opened', value);

  /// If true, the toast can't be swiped.
  bool get swipeDisabled => hasAttribute('swipeDisabled');
  set swipeDisabled(bool value) => toggleAttribute('swipeDisabled', value);

  /**
   * By default, the toast will close automatically if the user taps outside it
   * or presses the escape key. Disable this behavior by setting the
   * autoCloseDisabled property to true.
   */
  bool get autoCloseDisabled => hasAttribute('autoCloseDisabled');
  set autoCloseDisabled(bool value) => toggleAttribute('autoCloseDisabled', value);

  /// Toggle the opened state of the toast.
  void toggle() => call('toggle');

  /// Show the toast for the specified duration.
  void show([Duration duration]) {
    call('show', duration != null ? [duration.inMilliseconds] : null);
  }

  /// Dismiss the toast and hide it.
  void dismiss() => call('dismiss');
}

class PaperToggleButton extends CoreElement {
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
  Stream get onCoreChange => listen('core-change');
}

class PaperProgress extends CoreElement {
  PaperProgress() : super('paper-progress');
  PaperProgress.from(HtmlElement element) : super.from(element);

  bool get indeterminate => hasAttribute('indeterminate');
  set indeterminate(bool value) => toggleAttribute('indeterminate', value);
}

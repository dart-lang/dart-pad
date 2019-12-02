// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html';

import 'package:dart_pad/elements/elements.dart';
import 'package:dart_pad/services/dartservices.dart';
import 'package:mdc_web/mdc_web.dart';

class AnalysisResultsController {
  static const String _noIssuesMsg = 'no issues';
  static const String _hideMsg = 'hide';
  static const String _showMsg = 'show';

  static const Map<String, List<String>> _classesForType = {
    'info': ['issuelabel', 'info'],
    'warning': ['issuelabel', 'warning'],
    'error': ['issuelabel', 'error'],
  };

  DElement flash;
  DElement message;
  DElement toggle;
  bool _flashHidden;

  final StreamController<AnalysisIssue> _onClickController =
      StreamController.broadcast();

  Stream<AnalysisIssue> get onIssueClick => _onClickController.stream;

  AnalysisResultsController(this.flash, this.message, this.toggle) {
    // Show issues by default, but hide the flash element (otherwise an empty
    // flash container will be shown). display() will un-hide the element when
    // there are issues to display.
    _flashHidden = false;
    flash.setAttr('hidden');
    toggle.text = _hideMsg;

    message.text = _noIssuesMsg;
    MDCRipple(toggle.element);
    toggle.onClick.listen((_) {
      if (_flashHidden) {
        showFlash();
      } else {
        hideFlash();
      }
    });
  }

  void display(List<AnalysisIssue> issues) {
    if (issues.isEmpty) {
      message.text = _noIssuesMsg;

      // hide the flash without toggling the hidden state
      flash.setAttr('hidden');

      hideToggle();
      return;
    }

    // show the flash without toggling the hidden state
    if (!_flashHidden) {
      flash.clearAttr('hidden');
    }

    showToggle();
    message.text = '${issues.length} issues';

    flash.clearChildren();
    for (var elem in issues.map(_issueElement)) {
      flash.add(elem);
    }
  }

  Element _issueElement(AnalysisIssue issue) {
    var message = issue.message;
    if (issue.message.endsWith('.')) {
      message = message.substring(0, message.length - 1);
    }

    var elem = DivElement()..classes.add('issue');

    elem.children.add(SpanElement()
      ..text = issue.kind
      ..classes.addAll(_classesForType[issue.kind]));

    elem.children.add(SpanElement()
      ..text = '$message - line ${issue.line}'
      ..classes.add('message'));

    elem.onClick.listen((_) {
      _onClickController.add(issue);
    });

    return elem;
  }

  void hideToggle() {
    toggle.setAttr('hidden');
  }

  void showToggle() {
    toggle.clearAttr('hidden');
  }

  void hideFlash() {
    flash.setAttr('hidden');
    _flashHidden = true;
    toggle.text = _showMsg;
  }

  void showFlash() {
    _flashHidden = false;
    flash.clearAttr('hidden');
    toggle.text = _hideMsg;
  }
}

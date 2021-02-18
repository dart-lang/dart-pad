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

  final DElement flash;
  final DElement message;
  final DElement toggle;
  bool _flashHidden;

  final StreamController<LineInfo> _onClickController =
      StreamController.broadcast();

  Stream<LineInfo> get onItemClicked => _onClickController.stream;

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
    final amount = issues.length;
    if (amount == 0) {
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
    message.text = '$amount ${amount == 1 ? 'issue' : 'issues'}';

    flash.clearChildren();
    for (var issue in issues) {
      var elem = _issueElement(issue);
      flash.add(elem);

      for (var diagnostic in issue.diagnosticMessages) {
        var diagnosticElement = _diagnosticElement(diagnostic);
        flash.add(diagnosticElement);
      }
    }
  }

  Element _issueElement(AnalysisIssue issue) {
    var message = issue.message;
    message = _stripPeriod(message);

    var elem = DivElement()..classes.addAll(['issue', 'clickable']);

    elem.children.add(SpanElement()
      ..text = issue.kind
      ..classes.addAll(_classesForType[issue.kind]));

    var columnElem = DivElement()..classes.add('issue-column');

    var messageSpan = DivElement()
      ..text = '$message - line ${issue.line}'
      ..classes.add('message');
    columnElem.children.add(messageSpan);

    // Add the correction, if any.
    if (issue.correction != null && issue.correction.isNotEmpty) {
      var correctionMessage = _stripPeriod(issue.correction);
      columnElem.children.add(DivElement()
        ..text = correctionMessage
        ..classes.add('message'));
    }

    // Add a link to the documentation
    if (issue.url != null && issue.url.isNotEmpty) {
      columnElem.children.add(AnchorElement()
        ..href = issue.url
        ..text = ' Open Documentation'
        ..target = '_blank'
        ..classes.add('issue-anchor'));
    }

    elem.children.add(columnElem);

    elem.onClick.listen((_) {
      _onClickController.add(LineInfo(
          line: issue.line,
          charStart: issue.charStart,
          charLength: issue.charLength));
    });

    return elem;
  }

  String _stripPeriod(String s) {
    if (s.endsWith('.')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  Element _diagnosticElement(DiagnosticMessage diagnosticMessage) {
    var message = diagnosticMessage.message;
    if (message.endsWith('.')) {
      message = message.substring(0, message.length - 1);
    }

    var elem = DivElement()..classes.addAll(['issue', 'clickable']);

    elem.children.add(SpanElement()..classes.add('issue-indent'));

    elem.children.add(SpanElement()
      ..text = message
      ..classes.add('message'));

    elem.onClick.listen((_) {
      _onClickController.add(LineInfo(
          line: diagnosticMessage.line,
          charStart: diagnosticMessage.charStart,
          charLength: diagnosticMessage.charLength));
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

class LineInfo {
  final int line;
  final int charStart;
  final int charLength;

  LineInfo({
    this.line,
    this.charStart,
    this.charLength,
  });
}

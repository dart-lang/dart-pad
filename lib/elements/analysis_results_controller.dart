// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html';

import 'package:mdc_web/mdc_web.dart';

import '../services/dartservices.dart';
import 'button.dart';
import 'elements.dart';

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
  final MDCSnackbar snackbar;
  late bool _flashHidden;

  final StreamController<Location> _onClickController =
      StreamController.broadcast();

  Stream<Location> get onItemClicked => _onClickController.stream;

  AnalysisResultsController(
      this.flash, this.message, this.toggle, this.snackbar) {
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
    for (final issue in issues) {
      flash.add(_createIssueElement(issue));
    }
  }

  Element _createIssueElement(AnalysisIssue issue) {
    final message = issue.message;

    final elem = DivElement()..classes.addAll(['issue', 'clickable']);

    elem.children.add(SpanElement()
      ..text = issue.kind
      ..classes.addAll(_classesForType[issue.kind]!));

    final columnElem = DivElement()..classes.add('issue-column');

    final additionalSourceInfo =
        (issue.sourceName == 'main.dart') ? '' : ' of ${issue.sourceName} ';

    final messageSpan = DivElement()
      ..text = 'line ${issue.line}$additionalSourceInfo • $message'
      ..classes.add('message');
    columnElem.children.add(messageSpan);

    // Add a link to the documentation
    if (issue.url.isNotEmpty) {
      messageSpan.children.add(AnchorElement()
        ..href = issue.url
        ..text = ' (view docs)'
        ..target = '_blank'
        ..classes.add('issue-anchor'));
    }

    // Add the correction, if any.
    if (issue.correction.isNotEmpty) {
      columnElem.children.add(DivElement()
        ..text = issue.correction
        ..classes.add('message'));
    }

    // TODO: This should likely be named contextMessages.
    for (final diagnostic in issue.diagnosticMessages) {
      columnElem.children.add(_createDiagnosticElement(diagnostic,issue));
    }

    elem.children.add(columnElem);

    final copyButton = MDCButton(ButtonElement(), isIcon: true);
    copyButton.buttonElement.setInnerHtml('content_copy');
    copyButton
      ..toggleClass('mdc-icon-button', true)
      ..toggleClass('mdc-button-small', true)
      ..toggleClass('material-icons', true);

    copyButton.onClick.listen((event) async {
      try {
        await window.navigator.clipboard?.writeText(message);
        snackbar.showMessage('Copied to clipboard successfully!');
      } catch (_) {
        snackbar.showMessage('Failed to copy');
      }
    });

    elem.children.add(copyButton.element);

    elem.onClick.listen((_) {
      _onClickController.add(Location(
          sourceName:issue.sourceName,
          line: issue.line,
          charStart: issue.charStart,
          charLength: issue.charLength));
    });

    return elem;
  }

  Element _createDiagnosticElement(DiagnosticMessage diagnosticMessage, AnalysisIssue parentIssue ) {
    final message = diagnosticMessage.message;

    final elem = DivElement()..classes.addAll(['message', 'clickable']);
    elem.text = message;
    elem.onClick.listen((event) {
      // Stop the mouse event so the outer issue mouse handler doesn't process
      // it.
      event.stopPropagation();

      _onClickController.add(Location(
          //TODO: @timmaffett multi files will need -> diagnosticMessage.sourceName,
          sourceName:parentIssue.sourceName, 
          // For now if the source name is NOT main.dart then ASSUME that the
          // line number and charStart could have been adjust because of an
          // appended test, and use the information for the parentIssue instead.
          // (It would probably be safe to always do this, but by doing this
          // we DO NOT change any behavior except for when we have changed the
          // sourceName to `test.dart` (the only way the sourceName can currently
          // change until multi file source merged)) 
          //TODO: @timmaffett For now we assume only 2 possibilities, 'main.dart'
          // or 'test.dart' (and in that case we changed line# and charStart).
          line: parentIssue.sourceName=='main.dart' ? 
                  diagnosticMessage.line :
                  parentIssue.line,
          charStart: parentIssue.sourceName=='main.dart' ? 
                  diagnosticMessage.charStart :
                  parentIssue.charStart,
          charLength: parentIssue.sourceName=='main.dart' ?
                  diagnosticMessage.charLength :
                  parentIssue.charLength ));
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

/// A range of text in the file.
class Location {
  final String sourceName;
  final int line;
  final int charStart;
  final int charLength;

  Location({
    required this.sourceName,
    required this.line,
    required this.charStart,
    required this.charLength,
  });
}

extension SnackbarExtension on MDCSnackbar {
  void showMessage(String message) {
    labelText = message;
    open();
  }
}

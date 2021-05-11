import 'dart:async';
import 'dart:html';

import 'package:meta/meta.dart';
import 'package:split/split.dart';

import 'button.dart';
import 'counter.dart';
import 'elements.dart';

enum TabState {
  closed,
  ui,
  docs,
  console,
}

/// Manages the bottom-left panel and tabs
class TabExpandController {
  final MDCButton uiOutputButton;
  final MDCButton consoleButton;
  final MDCButton docsButton;
  final MDCButton closeButton;
  final DElement console;
  final DElement docs;
  final Counter unreadCounter;
  final DElement iframe;

  /// The element to give the top half of the split when this panel
  /// opens
  final Element topSplit;

  /// The element to give the bottom half of the split
  final Element bottomSplit;

  final List<StreamSubscription> _subscriptions = [];

  TabState _state;
  Splitter _splitter;
  bool _splitterConfigured = false;

  TabState get state => _state;

  TabExpandController({
    this.uiOutputButton,
    @required this.consoleButton,
    @required this.docsButton,
    @required this.closeButton,
    IFrameElement iframeElement,
    @required Element consoleElement,
    @required Element docsElement,
    @required this.topSplit,
    @required this.bottomSplit,
    @required this.unreadCounter,
  })  : console = DElement(consoleElement),
        docs = DElement(docsElement),
        iframe = iframeElement == null ? null : DElement(iframeElement) {
    _state = TabState.closed;
    iframe?.setAttr('hidden');
    console.setAttr('hidden');
    docs.setAttr('hidden');

    if (uiOutputButton != null) {
      _subscriptions.add(uiOutputButton.onClick.listen((_) {
        toggleIframe();
      }));
    }

    _subscriptions.add(consoleButton.onClick.listen((_) {
      toggleConsole();
    }));

    _subscriptions.add(docsButton.onClick.listen((_) {
      toggleDocs();
    }));

    _subscriptions.add(closeButton.onClick.listen((_) {
      _hidePanel();
    }));
  }

  void toggleIframe() {
    if (_state == TabState.closed) {
      _showUiOutput();
    } else if (_state == TabState.docs) {
      _showUiOutput();
      docs.setAttr('hidden');
      docsButton.toggleClass('active', false);
    } else if (_state == TabState.console) {
      _showUiOutput();
      console.setAttr('hidden');
      consoleButton.toggleClass('active', false);
    } else if (_state == TabState.ui) {
      _hidePanel();
    }
  }

  void toggleConsole() {
    if (_state == TabState.closed) {
      _showConsole();
    } else if (_state == TabState.docs) {
      _showConsole();
      docs.setAttr('hidden');
      docsButton.toggleClass('active', false);
    } else if (_state == TabState.ui) {
      _showConsole();
      iframe?.setAttr('hidden');
      uiOutputButton?.toggleClass('active', false);
    } else if (_state == TabState.console) {
      _hidePanel();
    }
  }

  void toggleDocs() {
    if (_state == TabState.closed) {
      _showDocs();
    } else if (_state == TabState.console) {
      _showDocs();
      console.setAttr('hidden');
      consoleButton.toggleClass('active', false);
    } else if (_state == TabState.ui) {
      _showConsole();
      iframe?.setAttr('hidden');
      uiOutputButton?.toggleClass('active', false);
    } else if (_state == TabState.docs) {
      _hidePanel();
    }
  }

  void _showUiOutput() {
    _state = TabState.ui;
    iframe.clearAttr('hidden');
    bottomSplit.classes.remove('border-top');
    uiOutputButton.toggleClass('active', true);
    _initSplitter();
    closeButton.toggleAttr('hidden', false);
  }

  void _showConsole() {
    unreadCounter.clear();
    _state = TabState.console;
    console.clearAttr('hidden');
    bottomSplit.classes.remove('border-top');
    consoleButton.toggleClass('active', true);
    _initSplitter();
    closeButton.toggleAttr('hidden', false);
  }

  void _hidePanel() {
    _destroySplitter();
    _state = TabState.closed;
    iframe?.setAttr('hidden');
    console.setAttr('hidden');
    docs.setAttr('hidden');
    bottomSplit.classes.add('border-top');
    uiOutputButton?.toggleClass('active', false);
    consoleButton.toggleClass('active', false);
    docsButton.toggleClass('active', false);
    closeButton.toggleAttr('hidden', true);
  }

  void _showDocs() {
    _state = TabState.docs;
    docs.clearAttr('hidden');
    bottomSplit.classes.remove('border-top');
    docsButton.toggleClass('active', true);
    _initSplitter();
    closeButton.toggleAttr('hidden', false);
  }

  void _initSplitter() {
    if (_splitterConfigured) {
      return;
    }

    _splitter = flexSplit(
      [topSplit, bottomSplit],
      horizontal: false,
      gutterSize: 6,
      sizes: [70, 30],
      minSize: [100, 100],
    );
    _splitterConfigured = true;
  }

  void _destroySplitter() {
    if (!_splitterConfigured) {
      return;
    }

    _splitter?.destroy();
    _splitterConfigured = false;
  }

  void dispose() {
    bottomSplit.classes.add('border-top');
    _destroySplitter();

    // Reset selected tab
    docsButton.toggleClass('active', false);
    consoleButton.toggleClass('active', false);

    // Clear listeners
    for (var s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
  }
}

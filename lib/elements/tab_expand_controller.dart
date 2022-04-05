import 'dart:async';
import 'dart:html';

import 'package:split/split.dart';

import '../sharing/editor_ui.dart';
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
  MDCButton? uiOutputButton;
  final MDCButton consoleButton;
  final MDCButton docsButton;
  final MDCButton clearConsoleButton;
  final MDCButton closeButton;
  final DElement console;
  final DElement docs;
  final Counter unreadCounter;
  final DElement? iframe;
  final EditorUi editorUi;

  /// The element to give the top half of the split when this panel
  /// opens
  final Element topSplit;

  /// The element to give the bottom half of the split
  final Element bottomSplit;

  final List<StreamSubscription<Event>> _subscriptions = [];

  late TabState _state;
  late Splitter _splitter;
  bool _splitterConfigured = false;

  TabState get state => _state;

  TabExpandController({
    this.uiOutputButton,
    required this.consoleButton,
    required this.docsButton,
    required this.clearConsoleButton,
    required this.closeButton,
    IFrameElement? iframeElement,
    required Element consoleElement,
    required Element docsElement,
    required this.topSplit,
    required this.bottomSplit,
    required this.unreadCounter,
    required this.editorUi,
  })  : console = DElement(consoleElement),
        docs = DElement(docsElement),
        iframe = iframeElement == null ? null : DElement(iframeElement) {
    _state = TabState.closed;
    iframe?.setAttr('hidden');
    console.setAttr('hidden');
    docs.setAttr('hidden');

    final uiOutputButton = this.uiOutputButton;
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

    clearConsoleButton.setAttr('style', 'visibility:hidden;');
  }

  void showUI({bool maximize = true}) {
    if (state != TabState.ui) {
      toggleIframe();
    }
    if (maximize) {
      _splitter.collapse(0);
    }
  }

  void showCode({bool maximize = true}) {
    if (state == TabState.ui) {
      _splitter.collapse(1);
    }
  }

  void toggleIframe() {
    switch (_state) {
      case TabState.closed:
        _showUiOutput();
        break;
      case TabState.ui:
        _hidePanel();
        break;
      case TabState.console:
        _showUiOutput();
        console.setAttr('hidden');
        consoleButton.toggleClass('active', false);
        break;
      case TabState.docs:
        _showUiOutput();
        docs.setAttr('hidden');
        docsButton.toggleClass('active', false);
        break;
    }
  }

  void toggleConsole() {
    switch (_state) {
      case TabState.closed:
        _showConsole();
        break;
      case TabState.ui:
        _showConsole();
        iframe?.setAttr('hidden');
        uiOutputButton?.toggleClass('active', false);
        break;
      case TabState.console:
        _hidePanel();
        break;
      case TabState.docs:
        _showConsole();
        docs.setAttr('hidden');
        docsButton.toggleClass('active', false);
        break;
    }
  }

  void toggleDocs() {
    switch (_state) {
      case TabState.closed:
        _showDocs();
        break;
      case TabState.ui:
        _showConsole();
        iframe?.setAttr('hidden');
        uiOutputButton?.toggleClass('active', false);
        break;
      case TabState.console:
        _showDocs();
        console.setAttr('hidden');
        consoleButton.toggleClass('active', false);
        break;
      case TabState.docs:
        _hidePanel();
        break;
    }
  }

  void _showUiOutput() {
    _state = TabState.ui;
    iframe?.clearAttr('hidden');
    bottomSplit.classes.remove('border-top');
    uiOutputButton?.toggleClass('active', true);
    _initSplitter();
    closeButton.toggleAttr('hidden', false);
    clearConsoleButton.setAttr('style', 'visibility:hidden;');
  }

  void _showConsole() {
    unreadCounter.clear();
    _state = TabState.console;
    console.clearAttr('hidden');
    bottomSplit.classes.remove('border-top');
    consoleButton.toggleClass('active', true);
    _initSplitter();
    closeButton.toggleAttr('hidden', false);
    clearConsoleButton.clearAttr('style');
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
    clearConsoleButton.setAttr('style', 'visibility:hidden;');
  }

  void _showDocs() {
    _state = TabState.docs;
    docs.clearAttr('hidden');
    bottomSplit.classes.remove('border-top');
    docsButton.toggleClass('active', true);
    _initSplitter();
    closeButton.toggleAttr('hidden', false);
    clearConsoleButton.setAttr('style', 'visibility:hidden;');
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

    editorUi.listenForResize(topSplit);

    _splitterConfigured = true;
  }

  void _destroySplitter() {
    if (!_splitterConfigured) {
      return;
    }

    _splitter.destroy();
    _splitterConfigured = false;
  }

  void dispose() {
    bottomSplit.classes.add('border-top');
    _destroySplitter();

    // Reset selected tab
    docsButton.toggleClass('active', false);
    consoleButton.toggleClass('active', false);

    // Clear listeners
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
  }
}

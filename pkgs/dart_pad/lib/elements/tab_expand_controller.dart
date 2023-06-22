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

typedef IFrameProvider = IFrameElement Function();

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
  final IFrameProvider? iFrameProvider;

  DElement? get iframe {
    final provider = iFrameProvider;
    if (provider == null) {
      return null;
    }
    return DElement(provider());
  }

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
    required Element consoleElement,
    required Element docsElement,
    required this.topSplit,
    required this.bottomSplit,
    required this.unreadCounter,
    required this.editorUi,
    this.iFrameProvider,
  })  : console = DElement(consoleElement),
        docs = DElement(docsElement) {
    state = TabState.closed;

    final uiOutputButton = this.uiOutputButton;
    if (uiOutputButton != null) {
      _subscriptions.add(uiOutputButton.onClick.listen((_) {
        _toggleUiOutput();
      }));
    }

    _subscriptions.add(consoleButton.onClick.listen((_) {
      _toggleConsole();
    }));

    _subscriptions.add(docsButton.onClick.listen((_) {
      _toggleDocs();
    }));

    _subscriptions.add(closeButton.onClick.listen((_) {
      hidePanel();
    }));

    clearConsoleButton.setAttr('style', 'visibility:hidden;');
  }

  void _toggleUiOutput() => _toggleState(TabState.ui);
  void _toggleConsole() => _toggleState(TabState.console);
  void _toggleDocs() => _toggleState(TabState.docs);

  void _toggleState(TabState state) {
    if (this.state == state) {
      this.state = TabState.closed;
    } else {
      this.state = state;
    }
  }

  set state(TabState state) {
    _state = state;
    switch (_state) {
      case TabState.closed:
        hidePanel();
        break;
      case TabState.ui:
        _selectUiOutputTab();
        break;
      case TabState.console:
        _selectConsoleTab();
        break;
      case TabState.docs:
        _selectDocsTab();
        break;
    }
  }

  set _showIframe(bool show) {
    if (show) {
      iframe?.clearAttr('hidden');
    } else {
      iframe?.setAttr('hidden');
    }
    uiOutputButton?.toggleClass('active', show);
  }

  set _showConsole(bool show) {
    console.toggleAttr('hidden', !show);
    consoleButton.toggleClass('active', show);
  }

  set _showDocs(bool show) {
    docs.toggleAttr('hidden', !show);
    docsButton.toggleClass('active', show);
  }

  set _showClearConsoleButton(bool show) {
    if (show) {
      clearConsoleButton.clearAttr('style');
    } else {
      clearConsoleButton.setAttr('style', 'visibility:hidden;');
    }
  }

  set _showSplitter(bool show) {
    bottomSplit.classes.toggle('border-top', !show);
    if (show) {
      _initSplitter();
    } else {
      _destroySplitter();
    }
  }

  set _showCloseButtons(bool show) {
    closeButton.toggleAttr('hidden', show);
  }

  void _selectUiOutputTab() {
    _state = TabState.ui;

    _showIframe = true;
    _showConsole = false;
    _showDocs = false;

    _showSplitter = true;
    _showCloseButtons = true;
    _showClearConsoleButton = false;
  }

  void _selectConsoleTab() {
    _state = TabState.console;

    unreadCounter.clear();

    _showIframe = false;
    _showConsole = true;
    _showDocs = false;

    _showSplitter = true;
    _showCloseButtons = true;
    _showClearConsoleButton = true;
  }

  void _selectDocsTab() {
    _state = TabState.docs;

    _showIframe = false;
    _showConsole = false;
    _showDocs = true;

    _showSplitter = true;
    _showCloseButtons = true;
    _showClearConsoleButton = false;
  }

  void hidePanel() {
    _state = TabState.closed;
    _showSplitter = false;
    _showIframe = false;
    _showConsole = false;
    _showDocs = false;
    _showCloseButtons = false;
    _showClearConsoleButton = false;
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

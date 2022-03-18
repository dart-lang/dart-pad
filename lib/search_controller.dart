import 'dart:html';

import 'package:mdc_web/mdc_web.dart';
import '../dart_pad.dart';
import '../editing/editor.dart';
import '../elements/analysis_results_controller.dart';
import '../elements/button.dart';
import '../elements/elements.dart';

class SearchController {
  final EditorFactory editorFactory;

  final Editor editor;

  final MDCSnackbar snackbar;

  /// The find/replace dialog box
  final DElement _searchDialog =
      DElement(querySelector('#search-dialog') as DivElement);

  final List<String> searchHistory = [];
  final List<String> replaceHistory = [];

  static const int keyCodeUp = 38;
  static const int keyCodeDown = 40;
  static const int keyCodeEnter = 13;
  static const int keyCodeEscape = 27;

  SearchController(this.editorFactory, this.editor, this.snackbar) {
    initUi();
    initKeyBindings();
    hide();

    editorFactory
        .registerSearchUpdateCallback(editorUpdatedSearchAnnotationsCallback);
  }

  void initKeyBindings() {
    keys.bind(['ctrl-f', 'macctrl-f'], () {
      userOpenFindDialogHotkey();
    }, 'Find');
    keys.bind(['ctrl-h', 'macctrl-h'], () {
      userOpenReplaceDialogHotkey();
    }, 'Replace');
    keys.bind(['f4'], () {
      userFindNextHotkey();
    }, 'Find Next');
    keys.bind(['shift-f4'], () {
      userFindPreviousHotkey();
    }, 'Find Previous');
  }

  void editorUpdatedSearchAnnotationsCallback() {
    final Map<String, dynamic> res =
        editor.getMatchesFromSearchQueryUpdatedCallback();
    int total = 0;
    int curMatchNum = -1;
    //List<Position> matches = [];

    total = res['total'] as int;
    curMatchNum = res['curMatchNum'] as int;
    //matches = res['matches'] as List<Position>;

    //final int line= matches.length>2 ? matches[2].line : -1;
    //final int ch = matches.length>2 ? matches[2].char : -1;
    //showSnackbar( 'CALLBACK number of items in matches array is ${matches.length} [0] line=$line ch=$ch');
    if (total == 0) {
      searchResultsSpan.innerText = 'No results';
      searchResultsSpan.classes.add('no-results');
    } else {
      final String resultMsg =
          '${(curMatchNum >= 0 ? (curMatchNum + 1).toString() : "?")} of $total';
      searchResultsSpan.innerText = resultMsg;
      searchResultsSpan.classes.remove('no-results');
    }
  }

  bool get hidden => !_searchDialog.hasClass('revealed');

  void hide() {
    //_searchDialog.setAttr('hidden');
    _searchDialog.toggleClass('revealed', false);
    clearSearch();
  }

  void show() {
    _searchDialog.clearAttr('hidden');
    _searchDialog.toggleClass('revealed', true);
    //this should be happening anyway (from filling find input) executeFind();
  }

  final DivElement replaceRowDiv = querySelector('#replace-row') as DivElement;
  final InputElement findTextInput =
      querySelector('#find-text')! as InputElement;
  final InputElement replaceTextInput =
      querySelector('#replace-text')! as InputElement;
  final ButtonElement findMatchCaseButton =
      querySelector('#find-match-case') as ButtonElement;
  final ButtonElement findWholeWordButton =
      querySelector('#find-wholeword') as ButtonElement;
  final ButtonElement findRegExButton =
      querySelector('#find-regex') as ButtonElement;
  final SpanElement searchResultsSpan =
      querySelector('#search-results') as SpanElement;
  final MDCButton replaceAndFindNextButton =
      MDCButton(querySelector('#replace-once') as ButtonElement, isIcon: true);
  final MDCButton replaceAllButton =
      MDCButton(querySelector('#replace-all') as ButtonElement, isIcon: true);
  final ButtonElement ourOpenReplaceIcon =
      querySelector('#open-replace') as ButtonElement;
  final MDCButton openReplaceButton =
      MDCButton(querySelector('#open-replace') as ButtonElement, isIcon: true);
  final MDCButton findPreviousButton =
      MDCButton(querySelector('#find-previous') as ButtonElement, isIcon: true);
  final MDCButton findNextButton =
      MDCButton(querySelector('#find-next') as ButtonElement, isIcon: true);
  final MDCButton findCloseButton =
      MDCButton(querySelector('#find-close') as ButtonElement, isIcon: true);

  bool get matchCase =>
      findMatchCaseButton.getAttribute('aria-pressed') == 'true';
  bool get wholeWord =>
      findWholeWordButton.getAttribute('aria-pressed') == 'true';
  bool get regExMatch => findRegExButton.getAttribute('aria-pressed') == 'true';
  String get findText => findTextInput.value ?? '';
  String get replaceText => replaceTextInput.value ?? '';

  void initUi() {
    findNextButton.onClick.listen((_) => userFindNextHotkey());
    findPreviousButton.onClick.listen((_) => userFindPreviousHotkey());
    findCloseButton.onClick.listen((_) => hide());
    replaceAndFindNextButton.onClick
        .listen((_) => userReplaceAndFindNextHotkey());
    replaceAllButton.onClick.listen((_) => userReplaceAllHotkey());

    // For each find search option we toggle it when pressed and update search highlights
    findMatchCaseButton.onClick.listen((_) {
      final String stateBeforeToggle =
          findMatchCaseButton.getAttribute('aria-pressed') ?? 'false';
      findMatchCaseButton.setAttribute(
          'aria-pressed', (stateBeforeToggle == 'false') ? 'true' : 'false');
      executeFind(highlightOnly: true);
    });
    findWholeWordButton.onClick.listen((_) {
      final String stateBeforeToggle =
          findWholeWordButton.getAttribute('aria-pressed') ?? 'false';
      findWholeWordButton.setAttribute(
          'aria-pressed', (stateBeforeToggle == 'false') ? 'true' : 'false');
      executeFind(highlightOnly: true);
    });
    findRegExButton.onClick.listen((_) {
      final String stateBeforeToggle =
          findRegExButton.getAttribute('aria-pressed') ?? 'false';
      findRegExButton.setAttribute(
          'aria-pressed', (stateBeforeToggle == 'false') ? 'true' : 'false');
      executeFind(highlightOnly: true);
    });
    openReplaceButton.onClick.listen((_) {
      if (replaceRowDiv.style.display == 'none') {
        openReplace();
      } else {
        closeReplace();
      }
    });
    // // disabled our buttons when no find text
    // findTextInput.onChange.listen((event) {
    //   if (findText.isEmpty) {
    //     findPreviousButton.disabled = findNextButton.disabled =
    //         replaceAndFindNextButton.disabled =
    //             replaceAllButton.disabled = true;
    //   } else {
    //     findPreviousButton.disabled = findNextButton.disabled =
    //         replaceAndFindNextButton.disabled =
    //             replaceAllButton.disabled = false;
    //   }
    // });
    // update highlighted matches as user types
    findTextInput.onInput.listen((event) {
      if (findText.isEmpty) {
        findPreviousButton.disabled = findNextButton.disabled =
            replaceAndFindNextButton.disabled =
                replaceAllButton.disabled = true;
      } else {
        findPreviousButton.disabled = findNextButton.disabled =
            replaceAndFindNextButton.disabled =
                replaceAllButton.disabled = false;
      }
      executeFind(highlightOnly: true);
    });
    // focus/blur behavior of find/replace inputs, change prompts when empty
    findTextInput.onFocus.listen((_) {
      findTextInput.setAttribute(
          'placeholder', 'Find (\u2191\u2193 for history)');
    });
    findTextInput.onBlur.listen((_) {
      if (findText.isEmpty) {
        findTextInput.setAttribute('placeholder', 'Find');
      }
    });
    replaceTextInput.onFocus.listen((_) {
      replaceTextInput.setAttribute(
          'placeholder', 'Replace (\u2191\u2193 for history)');
    });
    replaceTextInput.onBlur.listen((_) {
      final String current = replaceText;
      if (current.isEmpty) {
        replaceTextInput.setAttribute('placeholder', 'Replace');
      }
    });
    // handle Arrow keys (history navigation) and
    //    (we must preventDefault for arrow keys also)
    //    Enter presses (Find next shortcut) in Find/Replace inputs
    //    ESC closes dialog, we can only trap it on our inputs since
    //    editor needs it for vim..
    findTextInput.onKeyDown.listen((event) {
      final int keyCode = event.keyCode;
      if (keyCode == keyCodeUp || keyCode == keyCodeDown) {
        arrowKeysNavigateFindTextHistory(keyCode);
        event
            .preventDefault(); // so arrow keys don't mess with cursor in input element
      } else if (keyCode == keyCodeEnter) {
        userFindNextHotkey();
      } else if (keyCode == keyCodeEscape) {
        hide();
      }
    });
    replaceTextInput.onKeyDown.listen((event) {
      final int keyCode = event.keyCode;
      if (keyCode == keyCodeUp || keyCode == keyCodeDown) {
        arrowKeysNavigateReplaceTextHistory(keyCode);
        event
            .preventDefault(); // so arrow keys don't mess with cursor in input element
      } else if (keyCode == keyCodeEnter) {
        userReplaceAndFindNextHotkey();
      } else if (keyCode == keyCodeEscape) {
        hide();
      }
    });
  }

  void addFindTextToSearchHistory() {
    if (findText.isNotEmpty && !searchHistory.contains(findText)) {
      searchHistory.add(findText);
    }
  }

  void addReplaceTextToReplaceHistory() {
    if (replaceText.isNotEmpty && !replaceHistory.contains(replaceText)) {
      replaceHistory.add(replaceText);
    }
  }

  void arrowKeysNavigateFindTextHistory(int keyCode) {
    if (keyCode == keyCodeUp || keyCode == keyCodeDown) {
      // UP or DOWN
      // first figure out where we are in the history
      if (!searchHistory.contains(findText)) {
        addFindTextToSearchHistory();
      }
      int searchHistoryPos = searchHistory.indexOf(findText);
      if (keyCode == keyCodeUp) {
        // UP
        searchHistoryPos--;
      } else {
        searchHistoryPos++;
      }
      if (searchHistoryPos < 0) {
        searchHistoryPos = 0;
      } else if (searchHistoryPos >= searchHistory.length) {
        searchHistoryPos = searchHistory.length - 1;
      }
      setFindAndCursorAtEnd(searchHistory[searchHistoryPos]);
    }
  }

  void arrowKeysNavigateReplaceTextHistory(int keyCode) {
    if (keyCode == keyCodeUp || keyCode == keyCodeDown) {
      // UP or DOWN
      // first figure out where we are in the history
      if (!replaceHistory.contains(replaceText)) {
        addReplaceTextToReplaceHistory();
      }
      int replaceHistoryPos = replaceHistory.indexOf(replaceText);
      if (keyCode == keyCodeUp) {
        // UP
        replaceHistoryPos--;
      } else {
        replaceHistoryPos++;
      }
      if (replaceHistoryPos < 0) {
        replaceHistoryPos = 0;
      } else if (replaceHistoryPos >= replaceHistory.length) {
        replaceHistoryPos = replaceHistory.length - 1;
      }
      setReplaceAndCursorAtEnd(replaceHistory[replaceHistoryPos]);
    }
  }

  bool get somethingSelected {
    return editor.document.somethingSelected;
  }

  String? get selectedText {
    if (!somethingSelected) return null;
    return editor.document.selection;
  }

  void userOpenFindDialogHotkey() {
    if (!somethingSelected) {
      // for FIND, if there is nothing selected, try and grab
      // the token we are on (or near) and use that
      setFindSelectAllFocus(
          findStr: editor.getTokenWeAreOnOrNear(), forceExecuteFind: true);
    } else {
      setFindSelectAllFocus(findStr: selectedText, forceExecuteFind: true);
    }
    if (hidden) {
      // dialog currently hidden, so bring it up in FIND mode (hide replace)
      closeReplace();
      show();
    }
  }

  void userOpenReplaceDialogHotkey() {
    if (somethingSelected) {
      // something selected, we put it in the find and select the replace text
      setFindAndCursorAtEnd(selectedText, forceExecuteFind: true);
      addFindTextToSearchHistory();
      replaceSelectAllFocus();
    } else {
      // nothing selected, so just select all the find text and focus
      // (replace hotkey does no token finding)
      setFindSelectAllFocus(forceExecuteFind: true);
    }
    openReplace();
    if (hidden) {
      show();
    }
  }

  void userFindNextHotkey() {
    if (findText.isNotEmpty) {
      executeFind(highlightOnly: false);
      addFindTextToSearchHistory();
    }
  }

  void userFindPreviousHotkey() {
    if (findText.isNotEmpty) {
      executeFind(reverse: true, highlightOnly: false);
      addFindTextToSearchHistory();
    }
  }

  void userReplaceAndFindNextHotkey() {
    // what happens depends on whats selected..
    if (somethingSelected && selectedText == findText) {
      // matches find text, so execute replace
      executeReplace();
      addReplaceTextToReplaceHistory();
    }
    userFindNextHotkey();
  }

  void userReplaceAllHotkey() {
    executeReplace(replaceAll: true);
    addReplaceTextToReplaceHistory();
    executeFind(highlightOnly: true);
  }

  void setFindSelectAllFocus({String? findStr, bool forceExecuteFind = false}) {
    if (forceExecuteFind || findStr != null && findStr.isNotEmpty) {
      if (forceExecuteFind || findStr != findTextInput.value) {
        findTextInput.value = findStr ?? findTextInput.value;
        executeFind(highlightOnly: true);
      }
      addFindTextToSearchHistory();
    }
    findTextInput.focus();
    findTextInput.select();
  }

  void setFindAndCursorAtEnd(String? newFindText,
      {bool forceExecuteFind = false}) {
    if (forceExecuteFind || newFindText != null) {
      if (forceExecuteFind || newFindText != findTextInput.value) {
        findTextInput.value = newFindText ?? findTextInput.value;
        executeFind(highlightOnly: true);
      }
    }
    findTextInput.setSelectionRange(9999, 9999);
  }

  void replaceSelectAllFocus() {
    replaceTextInput.focus();
    replaceTextInput.select();
  }

  void setReplaceAndCursorAtEnd(String? newReplaceText) {
    if (newReplaceText != null) replaceTextInput.value = newReplaceText;
    replaceTextInput.setSelectionRange(9999, 9999);
  }

  void closeReplace() {
    if (replaceRowDiv.style.display != 'none') {
      replaceRowDiv.style.display = 'none';
      ourOpenReplaceIcon.innerText = 'chevron_right';
    }
  }

  void openReplace() {
    if (replaceRowDiv.style.display != 'flex') {
      replaceRowDiv.style.display = 'flex';
      ourOpenReplaceIcon.innerText = 'expand_more';
    }
  }

  void executeFind({bool reverse = false, bool highlightOnly = true}) {
    final String query = findTextInput.value ?? '';
    if (query != '') {
      //showSnackbar('Searching on "$query"');

      final Map<String, dynamic> res = editor.startSearch(
          query, reverse, highlightOnly, matchCase, wholeWord, regExMatch);
      int total = 0;
      int curMatchNum = -1;
      //List<Position> matches = [];

      total = res['total'] as int;
      curMatchNum = res['curMatchNum'] as int;
      //matches = res['matches'] as List<Position>;

      //showSnackbar( 'number of items in matches array is ${matches.length} [0] line=$line ch=$ch');
      if (total == 0) {
        searchResultsSpan.innerText = 'No results';
        searchResultsSpan.classes.add('no-results');
      } else {
        final String resultMsg =
            '${(curMatchNum >= 0 ? (curMatchNum + 1).toString() : "?")} of $total';
        searchResultsSpan.innerText = resultMsg;
        searchResultsSpan.classes.remove('no-results');
      }
    } else {
      //showSnackbar("Can't search for nothing");
    }
    // update the history
  }

  ///  There is currently selected text that matches the findText, so execute
  /// a replacement of that text with the replaceText
  void executeReplace({bool replaceAll = false}) {
    if (replaceAll) {
      editor.searchAndReplace(
          findText, replaceText, replaceAll, matchCase, wholeWord, regExMatch);
      executeFind(highlightOnly: true);
    } else {
      editor.document.replaceSelection(replaceText, 'around');
    }
  }

  /// Clears the search query so that there is no active search or highlighting
  void clearSearch() {
    editor.clearActiveSearch();
  }

  void showSnackbar(String message) {
    snackbar.showMessage(message);
  }
}

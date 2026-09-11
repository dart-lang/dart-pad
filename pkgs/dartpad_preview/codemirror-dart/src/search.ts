// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import { StateCommand, EditorSelection, SelectionRange } from "@codemirror/state";
import { SearchCursor } from "@codemirror/search";

/**
 * Selects all occurrences of the currently selected text or surrounding word.
 *
 * Unlike CodeMirror's default `selectSelectionMatches`, this:
 * 1. Automatically expands to the surrounding word when the selection is empty (like `selectNextOccurrence` / VS Code).
 * 2. Works when multiple occurrences are already selected.
 */
export const selectAllOccurrences: StateCommand = ({ state, dispatch }) => {
  let { main } = state.selection;
  let from = main.from;
  let to = main.to;
  let fullWord = false;

  if (main.empty) {
    let word = state.wordAt(main.head);
    if (!word) return false;
    from = word.from;
    to = word.to;
    fullWord = true;
  } else {
    let word = state.wordAt(main.head);
    fullWord = Boolean(word && word.from === main.from && word.to === main.to);
  }

  let text = state.sliceDoc(from, to);
  if (!text) return false;

  let matches: SelectionRange[] = [];
  let mainIndex = 0;
  for (let cur = new SearchCursor(state.doc, text); !cur.next().done;) {
    if (matches.length > 1000) return false;
    if (fullWord) {
      let w = state.wordAt(cur.value.from);
      if (!w || w.from !== cur.value.from || w.to !== cur.value.to) continue;
    }
    if (cur.value.from <= from && cur.value.to >= to) {
      mainIndex = matches.length;
    }
    matches.push(EditorSelection.range(cur.value.from, cur.value.to));
  }

  if (!matches.length) return false;

  dispatch(
    state.update({
      selection: EditorSelection.create(matches, mainIndex),
      userEvent: "select.search.matches",
    }),
  );
  return true;
};

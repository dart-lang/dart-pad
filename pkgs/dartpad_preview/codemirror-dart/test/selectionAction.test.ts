// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import assert from "node:assert/strict";
import test from "node:test";

import { EditorState, StateField } from "@codemirror/state";
import { EditorView, keymap } from "@codemirror/view";
import { selectionAction } from "../src/selectionAction";

// Setup browser API mocks needed for tooltip testing
class MockElement {
  className = "";
  type = "";
  textContent = "";
  children: MockElement[] = [];
  listeners: Record<string, Function[]> = {};

  appendChild(child: MockElement) {
    this.children.push(child);
  }

  addEventListener(event: string, listener: Function) {
    if (!this.listeners[event]) {
      this.listeners[event] = [];
    }
    this.listeners[event].push(listener);
  }

  click() {
    if (this.listeners["click"]) {
      for (const listener of this.listeners["click"]) {
        listener();
      }
    }
  }
}

function mockView(state: EditorState, dispatch: (tr: any) => void): EditorView {
  return {
    state,
    dispatch,
  } as unknown as EditorView;
}

// Helper to run code with mocked document and navigator
function runWithMocks(
  navigatorValue: { userAgent: string; userAgentData?: { platform: string } },
  fn: () => void,
) {
  const originalDocument = (globalThis as any).document;
  const originalNavigator = (globalThis as any).navigator;

  (globalThis as any).document = {
    createElement(tag: string) {
      return new MockElement();
    },
  };

  Object.defineProperty(globalThis, "navigator", {
    value: navigatorValue,
    configurable: true,
  });

  try {
    fn();
  } finally {
    if (originalDocument === undefined) {
      delete (globalThis as any).document;
    } else {
      (globalThis as any).document = originalDocument;
    }

    if (originalNavigator === undefined) {
      delete (globalThis as any).navigator;
    } else {
      Object.defineProperty(globalThis, "navigator", {
        value: originalNavigator,
        configurable: true,
      });
    }
  }
}

test("tooltip is null when selection is empty", () => {
  const extensions = selectionAction({
    key: "Mod-/",
    label: "Test Action",
    run: () => {},
  });
  const field = extensions[0] as StateField<any>;
  const state = EditorState.create({
    doc: "line one\nline two\nline three",
    extensions,
  });

  // Initial state is null
  let tooltip = state.field(field);
  assert.equal(tooltip, null);

  // Empty selection (cursor)
  const tr = state.update({ selection: { anchor: 5 } });
  tooltip = tr.state.field(field);
  assert.equal(tooltip, null);
});

test("tooltip is not null when selection is non-empty", () => {
  const extensions = selectionAction({
    key: "Mod-/",
    label: "Test Action",
    run: () => {},
  });
  const field = extensions[0] as StateField<any>;
  const state = EditorState.create({
    doc: "line one\nline two\nline three",
    extensions,
  });

  const tr = state.update({ selection: { anchor: 0, head: 8 } });
  const tooltip = tr.state.field(field);
  assert.ok(tooltip);
  assert.equal(tooltip.pos, 0);
  assert.equal(tooltip.end, 8);
  assert.equal(tooltip.above, true);
  assert.equal(tooltip.strictSide, true);
});

test("keymap commands work on empty and non-empty selections", () => {
  let runParams: { from: number; to: number; text: string } | null = null;
  let dispatchedTr: any = null;

  const extensions = selectionAction({
    key: "Mod-/",
    label: "Test Action",
    run: (from, to, text) => {
      runParams = { from, to, text };
    },
  });

  const state = EditorState.create({
    doc: "line one\nline two\nline three",
    selection: { anchor: 9, head: 17 }, // "line two"
    extensions,
  });

  const bindings = state.facet(keymap).flat();
  const binding = bindings.find((b) => b.key === "Mod-/");
  assert.ok(binding);
  assert.ok(binding.run);

  // Test empty selection returns false and does not run action
  const stateEmpty = EditorState.create({
    doc: "line one",
    selection: { anchor: 3 },
    extensions,
  });
  const viewEmpty = mockView(stateEmpty, () => {});
  const emptyResult = binding.run(viewEmpty);
  assert.equal(emptyResult, false);
  assert.equal(runParams, null);

  // Test non-empty selection runs action and dispatches selection collapse
  const viewNonEmpty = mockView(state, (tr) => {
    dispatchedTr = tr;
  });
  const nonEmptyResult = binding.run(viewNonEmpty);
  assert.equal(nonEmptyResult, true);
  // lineFrom and lineTo should be 1-based line numbers (line two is line 2)
  assert.deepEqual(runParams, { from: 2, to: 2, text: "line two" });
  assert.deepEqual(dispatchedTr, { selection: { anchor: 17 } });
});

test("tooltip DOM is created correctly for Mac shortcuts", () => {
  runWithMocks({ userAgent: "Macintosh" }, () => {
    const extensions = selectionAction({
      key: "Mod-/",
      label: "Test Action",
      run: () => {},
    });
    const field = extensions[0] as StateField<any>;
    let state = EditorState.create({
      doc: "hello world",
      extensions,
    });
    state = state.update({ selection: { anchor: 0, head: 5 } }).state;

    const tooltip = state.field(field);
    assert.ok(tooltip);

    const view = mockView(state, () => {});
    const { dom } = tooltip.create(view);

    assert.equal((dom as any).className, "cm-selection-action-tooltip");
    assert.equal((dom as any).children.length, 1);
    const button = (dom as any).children[0];
    assert.equal(button.className, "cm-selection-action-btn");
    assert.equal(button.type, "button");
    assert.equal(button.children.length, 2);

    const labelEl = button.children[0];
    assert.equal(labelEl.className, "cm-selection-action-label");
    assert.equal(labelEl.textContent, "Test Action");

    const shortcutEl = button.children[1];
    assert.equal(shortcutEl.className, "cm-selection-action-shortcut");
    assert.equal(shortcutEl.textContent, "⌘/");
  });
});

test("tooltip DOM is created correctly for non-Mac shortcuts", () => {
  runWithMocks(
    { userAgent: "Windows NT 10.0", userAgentData: { platform: "Windows" } },
    () => {
      const extensions = selectionAction({
        key: "Mod-/",
        label: "Test Action",
        run: () => {},
      });
      const field = extensions[0] as StateField<any>;
      let state = EditorState.create({
        doc: "hello world",
        extensions,
      });
      state = state.update({ selection: { anchor: 0, head: 5 } }).state;

      const tooltip = state.field(field);
      assert.ok(tooltip);

      const view = mockView(state, () => {});
      const { dom } = tooltip.create(view);

      const button = (dom as any).children[0];
      const shortcutEl = button.children[1];
      assert.equal(shortcutEl.textContent, "Ctrl+/");
    },
  );
});

test("tooltip button click executes callback and collapses selection", () => {
  runWithMocks({ userAgent: "Macintosh" }, () => {
    let runParams: { from: number; to: number; text: string } | null = null;
    let dispatchedTr: any = null;

    const extensions = selectionAction({
      key: "Mod-/",
      label: "Test Action",
      run: (from, to, text) => {
        runParams = { from, to, text };
      },
    });
    const field = extensions[0] as StateField<any>;
    let state = EditorState.create({
      doc: "hello world",
      extensions,
    });
    state = state.update({ selection: { anchor: 0, head: 5 } }).state;

    const tooltip = state.field(field);
    assert.ok(tooltip);

    const view = mockView(state, (tr) => {
      dispatchedTr = tr;
    });
    const { dom } = tooltip.create(view);
    const button = (dom as any).children[0];

    button.click();

    assert.deepEqual(runParams, { from: 1, to: 1, text: "hello" });
    assert.deepEqual(dispatchedTr, { selection: { anchor: 5 } });
  });
});

test("shortcut formatting when key is mixed or doesn't start with Mod-", () => {
  // Test Mac platform
  runWithMocks({ userAgent: "Macintosh" }, () => {
    const extensionsMac = selectionAction({
      key: "Shift-Mod-P",
      label: "Test",
      run: () => {},
    });
    let stateMac = EditorState.create({
      doc: "hello",
      extensions: extensionsMac,
    });
    stateMac = stateMac.update({ selection: { anchor: 0, head: 5 } }).state;
    const tooltipMac = stateMac.field(extensionsMac[0] as StateField<any>);
    const { dom: domMac } = tooltipMac.create(mockView(stateMac, () => {}));
    const shortcutElMac = (domMac as any).children[0].children[1];
    assert.equal(shortcutElMac.textContent, "Shift-⌘-P");
  });

  // Test non-Mac platform
  runWithMocks({ userAgent: "Windows" }, () => {
    const extensionsWin = selectionAction({
      key: "Shift-Mod-P",
      label: "Test",
      run: () => {},
    });
    let stateWin = EditorState.create({
      doc: "hello",
      extensions: extensionsWin,
    });
    stateWin = stateWin.update({ selection: { anchor: 0, head: 5 } }).state;
    const tooltipWin = stateWin.field(extensionsWin[0] as StateField<any>);
    const { dom: domWin } = tooltipWin.create(mockView(stateWin, () => {}));
    const shortcutElWin = (domWin as any).children[0].children[1];
    assert.equal(shortcutElWin.textContent, "Shift-Ctrl-P");
  });
});

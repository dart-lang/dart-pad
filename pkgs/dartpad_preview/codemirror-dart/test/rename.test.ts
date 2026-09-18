// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import assert from "node:assert/strict";
import test from "node:test";

import { EditorSelection, EditorState, Text } from "@codemirror/state";
import type { EditorView } from "@codemirror/view";
import type { LSPPlugin, WorkspaceMapping } from "@codemirror/lsp-client";

import {
  createRenameKeymap,
  createRenameTooltip,
  getRenameErrorMessage,
  rebaseWorkspaceEdit,
  renameSymbolAsync,
  renameTooltipEffect,
  renameTooltipField,
  showRenameMessage,
  startRename,
  type WorkspaceEdit,
} from "../src/rename";

class MockElement {
  className = "";
  textContent = "";
  children: MockElement[] = [];
  parentElement: MockElement | null = null;
  classList = {
    add: (cls: string) => {
      this.className = this.className ? `${this.className} ${cls}` : cls;
    },
  };

  listeners: Record<string, Function[]> = {};

  appendChild(child: MockElement) {
    child.parentElement = this;
    this.children.push(child);
    return child;
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

(globalThis as any).document = {
  createElement(_tag: string) {
    return new MockElement();
  },
};

function fakeView(
  contents = "final oldName = oldName;",
  selectionPos = 6,
): EditorView {
  let state = EditorState.create({
    doc: contents,
    selection: EditorSelection.cursor(selectionPos),
    extensions: [renameTooltipField],
  });
  return {
    get state() {
      return state;
    },
    dispatch(tr: any) {
      state = state.update(tr).state;
    },
  } as unknown as EditorView;
}

function fakePlugin(
  response: WorkspaceEdit | null,
  options: {
    requestError?: unknown;
    prepareResponse?: unknown;
    prepareError?: unknown;
  } = {},
) {
  const events: string[] = [];
  const mapping = {
    getMapping() {
      return null;
    },
  } as unknown as WorkspaceMapping;
  const plugin = {
    uri: "file:///workspace/main.dart",
    toPosition(position: number) {
      return { line: 0, character: position };
    },
    client: {
      hasCapability() {
        return true;
      },
      workspace: { getFile() {} },
      sync() {
        events.push("sync");
      },
      async withMapping<T>(
        callback: (mapping: WorkspaceMapping) => Promise<T>,
      ) {
        return callback(mapping);
      },
      async request(method: string) {
        events.push(method);
        if (method === "textDocument/prepareRename") {
          if (options.prepareError) throw options.prepareError;
          return options.prepareResponse !== undefined
            ? options.prepareResponse
            : { placeholder: "oldName" };
        }
        if (options.requestError) throw options.requestError;
        return response;
      },
    },
  } as unknown as LSPPlugin;
  return {
    plugin,
    events,
  };
}

test("rename forwards changes and documentChanges workspace edits", async () => {
  const edits: WorkspaceEdit[] = [
    {
      changes: {
        "file:///workspace/main.dart": [
          {
            range: {
              start: { line: 0, character: 6 },
              end: { line: 0, character: 13 },
            },
            newText: "newName",
          },
        ],
      },
    },
    {
      documentChanges: [
        {
          textDocument: {
            uri: "file:///workspace/main.dart",
            version: 1,
          },
          edits: [
            {
              range: {
                start: { line: 0, character: 6 },
                end: { line: 0, character: 13 },
              },
              newText: "newName",
            },
          ],
        },
      ],
    },
  ];

  for (const edit of edits) {
    const fake = fakePlugin(edit);
    let applied: WorkspaceEdit | undefined;
    const result = await renameSymbolAsync(
      fakeView(),
      "newName",
      async (workspaceEdit) => {
        applied = workspaceEdit;
      },
      () => fake.plugin,
    );

    assert.equal(result, true);
    assert.deepEqual(fake.events, ["sync", "textDocument/rename"]);
    assert.deepEqual(applied, edit);
  }
});

test("rename ignores a null result", async () => {
  const fake = fakePlugin(null);
  let applyCalls = 0;

  assert.equal(
    await renameSymbolAsync(
      fakeView(),
      "newName",
      () => {
        applyCalls++;
      },
      () => fake.plugin,
    ),
    true,
  );
  assert.equal(applyCalls, 0);
});

test("rename displays request failures as inline tooltip", async () => {
  const requestError = new Error(
    "The class 'Padding' is defined outside of the project, so cannot be renamed.",
  );
  const failedRequest = fakePlugin(null, { requestError });
  const view = fakeView();
  assert.equal(
    await renameSymbolAsync(
      view,
      "newName",
      () => {},
      () => failedRequest.plugin,
    ),
    false,
  );

  const tooltip = view.state.field(renameTooltipField);
  assert.ok(tooltip);
  const created = tooltip.create(view);
  assert.equal(
    created.dom.textContent,
    "The class 'Padding' is defined outside of the project, so cannot be renamed.",
  );
});

test("startRename shows tooltip on empty space or whitespace", async () => {
  const view = fakeView("   \n   ", 1);
  const fake = fakePlugin(null);
  const result = await startRename(
    view,
    () => {},
    () => fake.plugin,
  );

  assert.equal(result, true);
  const tooltip = view.state.field(renameTooltipField);
  assert.ok(tooltip);
  const created = tooltip.create(view);
  assert.equal(created.dom.textContent, "The element can't be renamed.");
});

test("startRename shows tooltip when prepareRename rejects with outside project error", async () => {
  const view = fakeView("expect(true, isTrue);", 2);
  const fake = fakePlugin(null, {
    prepareError: {
      message:
        "The function 'expect' is defined outside of the project, so cannot be renamed.",
    },
  });
  const result = await startRename(
    view,
    () => {},
    () => fake.plugin,
  );

  assert.equal(result, true);
  const tooltip = view.state.field(renameTooltipField);
  assert.ok(tooltip);
  const created = tooltip.create(view);
  assert.equal(
    created.dom.textContent,
    "The function 'expect' is defined outside of the project, so cannot be renamed.",
  );
});

test("startRename shows tooltip when prepareRename returns null", async () => {
  const view = fakeView("final a = 1;", 0);
  const fake = fakePlugin(null, { prepareResponse: null });
  const result = await startRename(
    view,
    () => {},
    () => fake.plugin,
  );

  assert.equal(result, true);
  const tooltip = view.state.field(renameTooltipField);
  assert.ok(tooltip);
  const created = tooltip.create(view);
  assert.equal(created.dom.textContent, "The element can't be renamed.");
});

test("tooltip clears on selection or doc change", () => {
  const view = fakeView("hello world", 0);
  showRenameMessage(view, 0, "Test error");
  assert.ok(view.state.field(renameTooltipField));

  view.dispatch({ selection: { anchor: 4 } });
  assert.equal(view.state.field(renameTooltipField), null);

  showRenameMessage(view, 0, "Test error");
  assert.ok(view.state.field(renameTooltipField));

  view.dispatch({ changes: { from: 0, insert: "a" } });
  assert.equal(view.state.field(renameTooltipField), null);
});

test("rename rebases edits for documents changed while awaiting the server", () => {
  const currentDoc = Text.of(["x final oldName = oldName;"]);
  const plugin = {
    client: {
      workspace: {
        getFile() {
          return { doc: currentDoc, getView: () => null };
        },
      },
    },
  } as unknown as LSPPlugin;
  const mapping = {
    getMapping() {
      return {};
    },
    mapPosition(_uri: string, position: { line: number; character: number }) {
      return position.character + 2;
    },
  } as unknown as WorkspaceMapping;

  const result = rebaseWorkspaceEdit(plugin, mapping, {
    changes: {
      "file:///workspace/main.dart": [
        {
          range: {
            start: { line: 0, character: 6 },
            end: { line: 0, character: 13 },
          },
          newText: "newName",
        },
      ],
    },
  });

  assert.deepEqual(result.changes?.["file:///workspace/main.dart"][0].range, {
    start: { line: 0, character: 8 },
    end: { line: 0, character: 15 },
  });
});

test("custom rename keymap keeps F2 registration", () => {
  const keymap = createRenameKeymap(() => {});
  assert.equal(keymap[0].key, "F2");
  assert.equal(keymap[0].preventDefault, true);
});

test("F2 closes tooltip when one is already active", () => {
  const view = fakeView("hello world", 0);
  showRenameMessage(view, 0, "Test error");
  assert.ok(view.state.field(renameTooltipField));

  const keymap = createRenameKeymap(() => {});
  const f2Command = keymap.find((k) => k.key === "F2")?.run;
  assert.ok(f2Command);
  f2Command(view);

  assert.equal(view.state.field(renameTooltipField), null);
});

test("Escape closes tooltip when active", () => {
  const view = fakeView("hello world", 0);
  showRenameMessage(view, 0, "Test error");
  assert.ok(view.state.field(renameTooltipField));

  const keymap = createRenameKeymap(() => {});
  const escCommand = keymap.find((k) => k.key === "Escape")?.run;
  assert.ok(escCommand);
  escCommand(view);

  assert.equal(view.state.field(renameTooltipField), null);
});

test("clicking tooltip closes it", () => {
  const view = fakeView("hello world", 0);
  showRenameMessage(view, 0, "Test error");
  const tooltip = view.state.field(renameTooltipField);
  assert.ok(tooltip);

  const created = tooltip.create(view);
  (created.dom as any).click?.();
  assert.equal(view.state.field(renameTooltipField), null);
});

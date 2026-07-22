// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import assert from "node:assert/strict";
import test from "node:test";

import { Text } from "@codemirror/state";
import type { EditorView } from "@codemirror/view";
import { LSPPlugin } from "@codemirror/lsp-client";

import { CMWorkspace } from "../src/lspClient";

function fakeView(contents: string): EditorView {
  return {
    state: { doc: Text.of([contents]) },
  } as unknown as EditorView;
}

test("a stale view cannot close its replacement", () => {
  const notifications: string[] = [];
  const client = {
    didOpen(file: { uri: string }) {
      notifications.push(`open:${file.uri}`);
    },
    didClose(uri: string) {
      notifications.push(`close:${uri}`);
    },
  };
  const workspace = new CMWorkspace(client);
  const uri = "file:///main.dart";
  const oldView = fakeView("void main() {} ");
  const replacementView = fakeView("void main() {} ");

  workspace.openFile(uri, "dart", oldView);
  workspace.openFile(uri, "dart", replacementView);
  workspace.closeFile(uri, oldView);

  assert.equal(workspace.getFile(uri)?.getView(), replacementView);
  assert.deepEqual(notifications, [
    `open:${uri}`,
    `close:${uri}`,
    `open:${uri}`,
  ]);

  workspace.closeFile(uri, replacementView);

  assert.equal(workspace.getFile(uri)?.getView(), null);
  assert.deepEqual(notifications, [
    `open:${uri}`,
    `close:${uri}`,
    `open:${uri}`,
    `close:${uri}`,
  ]);
});

test("displayFile waits until the requested editor is mounted", async () => {
  const client = {
    didOpen() {},
    didClose() {},
  };
  let requestedUri: string | null = null;
  const workspace = new CMWorkspace(client, (uri) => {
    requestedUri = uri;
  });
  const uri = "file:///other.dart";
  const view = fakeView("final answer = 42;");
  const display = workspace.displayFile(uri);

  assert.equal(requestedUri, uri);
  workspace.openFile(uri, "dart", view);

  assert.equal(await display, view);
});

test("syncFiles returns and clears only unsynchronized changes", () => {
  const client = {
    didOpen() {},
    didClose() {},
  };
  const workspace = new CMWorkspace(client);
  const uri = "file:///main.dart";
  const view = fakeView("before");
  workspace.openFile(uri, "dart", view);
  const file = workspace.getFile(uri)!;
  const previousDocument = file.doc;
  const currentDocument = Text.of(["after"]);
  (view as unknown as { state: { doc: Text } }).state.doc = currentDocument;

  const changes = { empty: false };
  let clearCalls = 0;
  const plugin = {
    unsyncedChanges: changes,
    clear() {
      clearCalls++;
      changes.empty = true;
    },
  };
  const originalGet = LSPPlugin.get;
  LSPPlugin.get = (candidate) =>
    candidate === view ? (plugin as unknown as LSPPlugin) : null;

  try {
    const result = workspace.syncFiles();

    assert.equal(result.length, 1);
    assert.equal(result[0].changes, changes);
    assert.equal(result[0].file, file);
    assert.equal(result[0].prevDoc, previousDocument);
    assert.equal(file.doc, currentDocument);
    assert.equal(file.version, 1);
    assert.equal(clearCalls, 1);
    assert.deepEqual(workspace.syncFiles(), []);
  } finally {
    LSPPlugin.get = originalGet;
  }
});

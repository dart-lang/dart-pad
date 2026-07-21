// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import { getIndentUnit, indentUnit } from "@codemirror/language";
import type { ChangeSpec } from "@codemirror/state";
import { LSPPlugin } from "@codemirror/lsp-client";
import type { Command, EditorView } from "@codemirror/view";

interface Position {
  line: number;
  character: number;
}

interface TextEdit {
  range: {
    start: Position;
    end: Position;
  };
  newText: string;
}

type PluginLookup = (view: EditorView) => LSPPlugin | null;

/**
 * Starts formatting from a synchronous CodeMirror command such as a keymap.
 */
export const formatDocument: Command = (view) => {
  const plugin = LSPPlugin.get(view);
  if (!plugin) return false;

  void formatDocumentAsync(view, () => plugin);
  return true;
};

/**
 * Formats a document and resolves after the returned edits have been applied.
 */
export async function formatDocumentAsync(
  view: EditorView,
  getPlugin: PluginLookup = LSPPlugin.get,
): Promise<boolean> {
  const plugin = getPlugin(view);
  if (!plugin) return false;

  try {
    plugin.client.sync();
    await plugin.client.withMapping(async (mapping) => {
      const response = await plugin.client.request<
        {
          options: { tabSize: number; insertSpaces: boolean };
          textDocument: { uri: string };
        },
        TextEdit[] | null
      >("textDocument/formatting", {
        options: {
          tabSize: getIndentUnit(view.state),
          insertSpaces: view.state.facet(indentUnit).indexOf("\t") < 0,
        },
        textDocument: { uri: plugin.uri },
      });

      if (!response) return;

      const changed = mapping.getMapping(plugin.uri);
      const changes: ChangeSpec[] = [];

      for (const edit of response) {
        let from = mapping.mapPosition(plugin.uri, edit.range.start);
        let to = mapping.mapPosition(plugin.uri, edit.range.end);

        if (changed) {
          // Do not apply stale edits when their range changed during the request.
          if (changed.touchesRange(from, to)) return;
          from = changed.mapPos(from, 1);
          to = changed.mapPos(to, -1);
        }

        changes.push({ from, to, insert: edit.newText });
      }

      view.dispatch({ changes, userEvent: "format" });
    });
  } catch (error) {
    plugin.reportError("Formatting request failed", error);
    return false;
  }

  return true;
}

// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import {
  StateEffect,
  StateField,
  type Extension,
  type Text,
} from "@codemirror/state";
import {
  closeHoverTooltips,
  getDialog,
  showDialog,
  showTooltip,
  type Command,
  type EditorView,
  type KeyBinding,
  type Tooltip,
} from "@codemirror/view";
import { LSPPlugin, type WorkspaceMapping } from "@codemirror/lsp-client";

interface Position {
  line: number;
  character: number;
}

interface TextEdit {
  range: { start: Position; end: Position };
  newText: string;
  [key: string]: unknown;
}

interface TextDocumentEdit {
  textDocument: { uri: string; [key: string]: unknown };
  edits: TextEdit[];
}

export interface WorkspaceEdit {
  changes?: Record<string, TextEdit[]>;
  documentChanges?: unknown[];
  [key: string]: unknown;
}

/**
 * Applies a workspace-wide edit returned by an editor-initiated LSP request.
 * Async handlers are awaited, and rejected promises are reported by the
 * initiating editor operation.
 */
export type ApplyWorkspaceEdit = (edit: WorkspaceEdit) => Promise<void> | void;
type PluginLookup = (view: Parameters<Command>[0]) => LSPPlugin | null;

export const renameTooltipEffect = StateEffect.define<Tooltip | null>();

export const renameTooltipField = StateField.define<Tooltip | null>({
  create() {
    return null;
  },
  update(tooltip, tr) {
    if (tr.docChanged || tr.selection) {
      return null;
    }
    for (const effect of tr.effects) {
      if (effect.is(renameTooltipEffect)) {
        return effect.value;
      }
    }
    return tooltip;
  },
  provide: (field) => showTooltip.from(field),
});

export function getRenameErrorMessage(error: unknown): string {
  if (!error) return "The element can't be renamed.";
  if (typeof error === "string" && error.trim().length > 0) return error;
  if (typeof error === "object") {
    const errObj = error as Record<string, unknown>;
    if (
      typeof errObj.message === "string" &&
      errObj.message.trim().length > 0
    ) {
      return errObj.message;
    }
  }
  return "The element can't be renamed.";
}

export function createRenameTooltip(pos: number, message: string): Tooltip {
  return {
    pos,
    above: true,
    strictSide: true,
    arrow: true,
    create(view) {
      const dom = document.createElement("div");
      dom.className = "cm-rename-message-tooltip";
      dom.textContent = message;
      dom.addEventListener("click", () => {
        view.dispatch({ effects: renameTooltipEffect.of(null) });
      });

      const attachClass = () => {
        if (dom.parentElement) {
          dom.parentElement.classList.add("cm-rename-message-tooltip-wrapper");
        }
      };

      if (typeof queueMicrotask === "function") {
        queueMicrotask(attachClass);
      }
      setTimeout(attachClass, 0);

      return {
        dom,
        mount() {
          attachClass();
        },
        positioned() {
          attachClass();
        },
      };
    },
  };
}

export function showRenameMessage(
  view: EditorView,
  pos: number,
  message: string,
) {
  const effects: StateEffect<unknown>[] = [closeHoverTooltips];
  if (view.state.field(renameTooltipField, false) === undefined) {
    effects.push(StateEffect.appendConfig.of(renameTooltipField));
  }
  const tooltip = createRenameTooltip(pos, message);
  effects.push(renameTooltipEffect.of(tooltip));
  view.dispatch({ effects });

  setTimeout(() => {
    try {
      const current = view.state.field(renameTooltipField, false);
      if (current && current.pos === pos) {
        view.dispatch({ effects: renameTooltipEffect.of(null) });
      }
    } catch {
      // Ignore if view destroyed
    }
  }, 5000);
}

function isTextDocumentEdit(change: unknown): change is TextDocumentEdit {
  if (!change || typeof change !== "object") return false;
  const candidate = change as Partial<TextDocumentEdit>;
  return !!candidate.textDocument?.uri && Array.isArray(candidate.edits);
}

function toPosition(doc: Text, offset: number): Position {
  const line = doc.lineAt(offset);
  return { line: line.number - 1, character: offset - line.from };
}

function rebaseEdits(
  plugin: LSPPlugin,
  mapping: WorkspaceMapping,
  uri: string,
  edits: TextEdit[],
): TextEdit[] {
  const file = plugin.client.workspace.getFile(uri);
  const doc = file?.getView()?.state.doc ?? file?.doc;
  if (!doc || !mapping.getMapping(uri)) return edits;

  return edits.map((edit) => ({
    ...edit,
    range: {
      start: toPosition(doc, mapping.mapPosition(uri, edit.range.start, 1)),
      end: toPosition(doc, mapping.mapPosition(uri, edit.range.end, -1)),
    },
  }));
}

/** Rebase edits for open CodeMirror documents while preserving the LSP shape. */
export function rebaseWorkspaceEdit(
  plugin: LSPPlugin,
  mapping: WorkspaceMapping,
  edit: WorkspaceEdit,
): WorkspaceEdit {
  const rebased: WorkspaceEdit = { ...edit };

  if (edit.changes) {
    rebased.changes = Object.fromEntries(
      Object.entries(edit.changes).map(([uri, edits]) => [
        uri,
        rebaseEdits(plugin, mapping, uri, edits),
      ]),
    );
  }

  if (edit.documentChanges) {
    rebased.documentChanges = edit.documentChanges.map((change) => {
      if (!isTextDocumentEdit(change)) return change;
      return {
        ...change,
        edits: rebaseEdits(
          plugin,
          mapping,
          change.textDocument.uri,
          change.edits,
        ),
      };
    });
  }

  return rebased;
}

/** Requests a symbol rename and forwards the resulting workspace edit. */
export async function renameSymbolAsync(
  view: Parameters<Command>[0],
  newName: string,
  applyWorkspaceEdit: ApplyWorkspaceEdit,
  getPlugin: PluginLookup = LSPPlugin.get,
  targetPos?: number,
): Promise<boolean> {
  const plugin = getPlugin(view);
  const pos = targetPos ?? view.state.selection.main.head;
  const word = view.state.wordAt(pos);
  if (!plugin || !word) {
    showRenameMessage(view, pos, "The element can't be renamed.");
    return false;
  }

  try {
    plugin.client.sync();
    await plugin.client.withMapping(async (mapping) => {
      const response = await plugin.client.request<
        {
          newName: string;
          position: Position;
          textDocument: { uri: string };
        },
        WorkspaceEdit | null
      >("textDocument/rename", {
        newName,
        position: plugin.toPosition(word.from),
        textDocument: { uri: plugin.uri },
      });

      if (response) {
        await applyWorkspaceEdit(
          rebaseWorkspaceEdit(plugin, mapping, response),
        );
      }
    });
    return true;
  } catch (error) {
    showRenameMessage(view, pos, getRenameErrorMessage(error));
    return false;
  }
}

/** Handles checking prepareRename and opening the rename prompt. */
export async function startRename(
  view: EditorView,
  applyWorkspaceEdit: ApplyWorkspaceEdit,
  getPlugin: PluginLookup = LSPPlugin.get,
): Promise<boolean> {
  const pos = view.state.selection.main.head;
  const wordRange = view.state.wordAt(pos);
  const plugin = getPlugin(view);

  if (
    !wordRange ||
    !plugin ||
    (plugin.client as any).hasCapability?.("renameProvider") === false
  ) {
    showRenameMessage(view, pos, "The element can't be renamed.");
    return true;
  }

  let initialName = view.state.sliceDoc(wordRange.from, wordRange.to);

  try {
    plugin.client.sync();
    const prepareResult = await plugin.client.request<
      { textDocument: { uri: string }; position: Position },
      | { range: { start: Position; end: Position }; placeholder?: string }
      | { start: Position; end: Position }
      | { defaultBehavior: boolean }
      | null
    >("textDocument/prepareRename", {
      textDocument: { uri: plugin.uri },
      position: plugin.toPosition(pos),
    });

    if (prepareResult === null) {
      showRenameMessage(view, pos, "The element can't be renamed.");
      return true;
    }

    if (typeof prepareResult === "object" && prepareResult !== null) {
      if (
        "placeholder" in prepareResult &&
        typeof prepareResult.placeholder === "string"
      ) {
        initialName = prepareResult.placeholder;
      }
    }
  } catch (error: any) {
    // If the server doesn't support prepareRename (e.g. -32601 Method not found),
    // proceed to open the rename dialog.
    if (
      error?.code === -32601 ||
      (typeof error?.message === "string" &&
        error.message.includes("Method not found"))
    ) {
      // Continue to open dialog
    } else {
      showRenameMessage(view, pos, getRenameErrorMessage(error));
      return true;
    }
  }

  const panel = getDialog(view, "cm-lsp-rename-panel");
  if (panel) {
    const input = panel.dom.querySelector<HTMLInputElement>("[name=name]");
    if (input) {
      input.value = initialName;
      input.select();
    }
  } else {
    const { close, result } = showDialog(view, {
      label: view.state.phrase("New name"),
      input: { name: "name", value: initialName },
      focus: true,
      submitLabel: view.state.phrase("rename"),
      class: "cm-lsp-rename-panel",
    });
    void result.then((form) => {
      view.dispatch({ effects: close });
      if (form) {
        const input = form.elements.namedItem("name") as HTMLInputElement;
        void renameSymbolAsync(
          view,
          input.value,
          applyWorkspaceEdit,
          getPlugin,
          pos,
        );
      }
    });
  }
  return true;
}

/** Creates the F2 rename command for a specific workspace-edit handler. */
export function createRenameKeymap(
  applyWorkspaceEdit: ApplyWorkspaceEdit,
): readonly KeyBinding[] {
  const renameSymbol: Command = (view) => {
    if (view.state.field(renameTooltipField, false)) {
      view.dispatch({
        effects: [renameTooltipEffect.of(null), closeHoverTooltips],
      });
      return true;
    }
    view.dispatch({ effects: closeHoverTooltips });
    void startRename(view, applyWorkspaceEdit);
    return true;
  };

  const closeRenameTooltip: Command = (view) => {
    if (view.state.field(renameTooltipField, false)) {
      view.dispatch({
        effects: [renameTooltipEffect.of(null), closeHoverTooltips],
      });
      return true;
    }
    return false;
  };

  return [
    { key: "F2", run: renameSymbol, preventDefault: true },
    { key: "Escape", run: closeRenameTooltip },
  ];
}

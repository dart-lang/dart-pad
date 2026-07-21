// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import { showTooltip, Tooltip, EditorView, keymap } from "@codemirror/view";
import { StateField } from "@codemirror/state";

export function selectionAction(config: {
  key: string;
  label: string;
  run: (from: number, to: number, text: string) => void;
}) {
  const runAction = (view: EditorView, from: number, to: number) => {
    const text = view.state.sliceDoc(from, to);
    const lineFrom = view.state.doc.lineAt(from).number;
    const lineTo = view.state.doc.lineAt(to).number;
    config.run(lineFrom, lineTo, text);
    view.dispatch({
      selection: { anchor: to },
    });
  };

  const selectionTooltipField = StateField.define<Tooltip | null>({
    create() {
      return null;
    },
    update(value, tr) {
      if (tr.docChanged || tr.selection) {
        const { main } = tr.state.selection;
        if (main.empty) {
          return null;
        }
        return {
          pos: main.from,
          end: main.to,
          above: true,
          strictSide: true,
          create(view) {
            const dom = document.createElement("div");
            dom.className = "cm-selection-action-tooltip";

            const button = document.createElement("button");
            button.className = "cm-selection-action-btn";
            button.type = "button";

            const labelEl = document.createElement("span");
            labelEl.className = "cm-selection-action-label";
            labelEl.textContent = config.label;

            const shortcutEl = document.createElement("span");
            shortcutEl.className = "cm-selection-action-shortcut";

            const userAgentData = (navigator as any).userAgentData;
            const isMac = userAgentData
              ? /Mac|iPhone|iPad|iPod/i.test(userAgentData.platform)
              : /Mac|iPhone|iPad|iPod/i.test(navigator.userAgent);
            let keyText = config.key;
            if (keyText.toLowerCase().startsWith("mod-")) {
              keyText =
                (isMac ? "⌘" : "Ctrl+") + keyText.slice(4).toUpperCase();
            } else {
              keyText = keyText.replace(/Mod/gi, isMac ? "⌘" : "Ctrl");
            }
            shortcutEl.textContent = keyText;

            button.appendChild(labelEl);
            button.appendChild(shortcutEl);

            button.addEventListener("click", () => {
              runAction(view, main.from, main.to);
            });

            dom.appendChild(button);
            return { dom };
          },
        };
      }
      return value;
    },
    provide: (f) => showTooltip.from(f),
  });

  return [
    selectionTooltipField,
    keymap.of([
      {
        key: config.key,
        run: (view: EditorView) => {
          const { main } = view.state.selection;
          if (main.empty) {
            return false;
          }
          runAction(view, main.from, main.to);
          return true;
        },
      },
    ]),
  ];
}

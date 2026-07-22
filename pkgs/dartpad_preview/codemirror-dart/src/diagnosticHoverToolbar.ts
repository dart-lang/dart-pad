// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import { Extension } from "@codemirror/state";
import { EditorView, hoverTooltip } from "@codemirror/view";
import { forEachDiagnostic, setDiagnosticsEffect } from "@codemirror/lint";

export interface ToolbarAction {
  label: string;
  run: (view: EditorView, from: number, to: number, diagnostics: any[]) => void;
}

function hideTooltip(tr: any, tooltip: any) {
  const from = tooltip.pos,
    to = tooltip.end || from;
  const line = tr.startState.doc.lineAt(tooltip.pos);
  return !!(
    tr.effects.some((e: any) => e.is(setDiagnosticsEffect)) ||
    tr.changes.touchesRange(line.from, Math.max(line.to, to))
  );
}

export function diagnosticHoverToolbar(actions: ToolbarAction[]): Extension {
  return hoverTooltip(
    (view, pos, side) => {
      const activeDiagnostics: any[] = [];
      forEachDiagnostic(view.state, (diagnostic, from, to) => {
        if (pos >= from && pos <= to) {
          activeDiagnostics.push({ from, to, diagnostic });
        }
      });

      if (activeDiagnostics.length === 0) return null;

      const from = Math.min(...activeDiagnostics.map((d) => d.from));
      const to = Math.max(...activeDiagnostics.map((d) => d.to));

      return {
        pos: from,
        end: to,
        above: true,
        arrow: true,
        create(view) {
          const dom = document.createElement("div");
          dom.className = "cm-diagnostic-hover-toolbar";
          dom.style.display = "flex";
          dom.style.gap = "6px";
          dom.style.padding = "4px 6px";

          for (const action of actions) {
            const button = document.createElement("button");
            button.type = "button";
            button.className = "cm-diagnostic-toolbar-btn";
            button.textContent = action.label;

            button.addEventListener("click", (e) => {
              e.preventDefault();
              e.stopPropagation();
              action.run(
                view,
                from,
                to,
                activeDiagnostics.map((d) => d.diagnostic),
              );
            });
            dom.appendChild(button);
          }

          return { dom };
        },
      };
    },
    {
      hideOn: hideTooltip,
    },
  );
}

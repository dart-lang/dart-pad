import { EditorView, Decoration, DecorationSet, ViewPlugin } from "@codemirror/view";
import { StateField, StateEffect } from "@codemirror/state";
import { LSPPlugin, jumpToDefinition } from "@codemirror/lsp-client";

// A StateEffect to update the hover definition link range
const setHoverLink = StateEffect.define<{from: number, to: number} | null>();

// Underline decoration style
const linkDecoration = Decoration.mark({ class: "cm-cmd-click-link" });

// A StateField to track the active hover link range and supply decorations
export const hoverLinkState = StateField.define<DecorationSet>({
  create() {
    return Decoration.none;
  },
  update(value, tr) {
    value = value.map(tr.changes);
    for (let effect of tr.effects) {
      if (effect.is(setHoverLink)) {
        if (effect.value) {
          return Decoration.set([linkDecoration.range(effect.value.from, effect.value.to)]);
        } else {
          return Decoration.none;
        }
      }
    }
    return value;
  },
  provide: f => EditorView.decorations.from(f)
});

export const gotoDefinitionOnClick = () => {
  return [
    hoverLinkState,
    ViewPlugin.define(view => {
      let hoveredWord: {from: number, to: number} | null = null;
      let queryTimeout: any = null;

      function clear() {
        if (queryTimeout) {
          clearTimeout(queryTimeout);
          queryTimeout = null;
        }
        if (hoveredWord) {
          hoveredWord = null;
          view.dispatch({effects: setHoverLink.of(null)});
        }
      }

      function handleMove(event: MouseEvent) {
        if (!event.metaKey && !event.ctrlKey) {
          clear();
          return;
        }

        const pos = view.posAtCoords({x: event.clientX, y: event.clientY});
        if (pos === null) {
          clear();
          return;
        }

        const word = view.state.wordAt(pos);
        if (!word) {
          clear();
          return;
        }

        // If we're already hovering over this word, do nothing
        if (hoveredWord && hoveredWord.from === word.from && hoveredWord.to === word.to) {
          return;
        }

        // Clear previous state and queue a new query
        clear();
        hoveredWord = {from: word.from, to: word.to};

        queryTimeout = setTimeout(() => {
          const plugin = LSPPlugin.get(view);
          if (!plugin) return;
          
          plugin.client.sync();
          
          // Request definition at the current position
          plugin.client.request("textDocument/definition", {
            textDocument: {uri: plugin.uri},
            position: plugin.toPosition(word.from)
          }).then(result => {
            // Check if the hovered word is still the same when the response arrives
            if (hoveredWord && hoveredWord.from === word.from && hoveredWord.to === word.to) {
              if (result && (!Array.isArray(result) || result.length > 0)) {
                view.dispatch({effects: setHoverLink.of({from: word.from, to: word.to})});
              } else {
                view.dispatch({effects: setHoverLink.of(null)});
              }
            }
          }).catch(() => {
            if (hoveredWord && hoveredWord.from === word.from && hoveredWord.to === word.to) {
              view.dispatch({effects: setHoverLink.of(null)});
            }
          });
        }, 150);
      }

      const keyListener = (e: KeyboardEvent) => {
        if (e.key === "Meta" || e.key === "Control") {
          if (e.type === "keyup") {
            clear();
          }
        }
      };

      window.addEventListener("keydown", keyListener);
      window.addEventListener("keyup", keyListener);
      window.addEventListener("blur", clear);

      return {
        handleMove,
        clear,
        destroy() {
          clear();
          window.removeEventListener("keydown", keyListener);
          window.removeEventListener("keyup", keyListener);
          window.removeEventListener("blur", clear);
        }
      };
    }, {
      eventHandlers: {
        mousemove(event) {
          this.handleMove(event);
        },
        mouseleave() {
          this.clear();
        },
        mousedown(event, view) {
          if (event.metaKey || event.ctrlKey) {
            const pos = view.posAtCoords({x: event.clientX, y: event.clientY});
            if (pos !== null) {
              this.clear();
              view.dispatch({selection: {anchor: pos}});
              jumpToDefinition(view);
              event.preventDefault();
              event.stopPropagation();
              return true;
            }
          }
          return false;
        }
      }
    })
  ];
};

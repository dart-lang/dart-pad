import { EditorView, Decoration, DecorationSet, ViewUpdate, ViewPlugin } from "@codemirror/view";
import { StateField, StateEffect, RangeSetBuilder } from "@codemirror/state";
import { highlightingFor } from "@codemirror/language";
import { tags as t } from "@lezer/highlight";

export const semanticExtension = {
  clientCapabilities: {
    textDocument: {
      semanticTokens: {
        dynamicRegistration: false,
        formats: ["relative"],
        requests: { full: true },
        tokenTypes: [
          "class",
          "enum",
          "enumMember",
          "type",
          "typeParameter",
          "property",
          "variable",
          "parameter",
          "function",
          "method",
          "keyword",
          "modifier",
          "comment",
          "string",
          "number",
          "operator",
          "annotation",
          "boolean",
        ],
        tokenModifiers: [
          "declaration",
          "definition",
          "readonly",
          "static",
          "deprecated",
          "abstract",
          "async",
        ],
      },
    },
  },
};

/**
 * Maps standard LSP Semantic Token Type strings dynamically to 
 * underlying Lezer theme tags to natively map CSS aesthetics.
 */
function getSemanticTag(typeString: string) {
  switch (typeString) {
    case 'class':
    case 'type':
    case 'struct': return t.className;
    case 'typeParameter': return t.typeName;
    case 'property': return t.propertyName;
    case 'variable': return t.variableName;
    case 'function':
    case 'method': return t.function(t.variableName);
    case 'keyword': return t.keyword;
    case 'modifier': return t.modifier;
    case 'comment': return t.comment;
    case 'string': return t.string;
    case 'number': return t.number;
    case 'operator': return t.operator;
    case 'enum': return t.typeName;
    case 'enumMember': return t.propertyName;
    case 'macro': return t.macroName;
    case 'parameter': return t.local(t.variableName);
    case 'annotation': return t.meta;
    case 'boolean': return t.bool;
    default: return null;
  }
}

const setSemanticTokens = StateEffect.define<DecorationSet>();
export const forceSemanticTokensRefresh = StateEffect.define<void>();

const semanticTokensField = StateField.define<DecorationSet>({
  create() { return Decoration.none; },
  update(value, tr) {
    value = value.map(tr.changes);
    for (const e of tr.effects) {
      if (e.is(setSemanticTokens)) value = e.value;
    }
    return value;
  },
  provide: f => EditorView.decorations.from(f)
});

/**
 * Mounts standard LSP semantic tokens natively extracted from the Dart Language Server
 * as visually overriding decoration spans.
 * 
 * Extracts styling asynchronously, parsing the 5-integer incremental token array cleanly.
 */
export function semanticHighlightingPlugin(client: any, uri: string) {
  const plugin = ViewPlugin.fromClass(class {
    updateId: number | null = null;

    constructor(view: EditorView) {
      this.fetchSemanticTokens(view);
    }

    update(update: ViewUpdate) {
      if (update.docChanged || update.transactions.some(tr => tr.effects.some(e => e.is(forceSemanticTokensRefresh)))) {
        if (this.updateId !== null) clearTimeout(this.updateId);
        // Throttle synchronization request lag.
        this.updateId = window.setTimeout(() => this.fetchSemanticTokens(update.view, 1), 250);
      }
    }

    async fetchSemanticTokens(view: EditorView, retries = 5) {
      await client.initializing;

      if (client.isAnalyzing) {
        // Delay requesting tokens until analysis is complete.
        await client.analysisFinished;
      }

      const capabilities = client.serverCapabilities?.semanticTokensProvider;
      if (!capabilities) { return; }

      const legend = capabilities.legend;
      if (!legend || !legend.tokenTypes) { return; }

      try {
        // Enforce pushing CodeMirror text changes onto Language Server AST before queries
        client.sync();
        const response = await client.request("textDocument/semanticTokens/full", {
          textDocument: { uri }
        });

        const data = response?.data;
        if (!data) { return; }

        const builder = new RangeSetBuilder<Decoration>();

        let currentLine = 0;
        let currentCol = 0;

        for (let i = 0; i < data.length; i += 5) {
          const deltaLine = data[i];
          const deltaStartChar = data[i + 1];
          const length = data[i + 2];
          const tokenTypeIndex = data[i + 3];

          if (deltaLine > 0) {
            currentLine += deltaLine;
            currentCol = deltaStartChar;
          } else {
            currentCol += deltaStartChar;
          }

          const typeString = legend.tokenTypes[tokenTypeIndex];
          const tag = getSemanticTag(typeString);

          if (tag) {
            const themeClass = highlightingFor(view.state, [tag]);
            if (themeClass) {
              const line = view.state.doc.line(currentLine + 1);
              const start = line.from + currentCol;
              builder.add(start, start + length, Decoration.mark({ class: themeClass + " cm-semantic-token" }));
            }
          }
        }

        view.dispatch({ effects: setSemanticTokens.of(builder.finish()) });
      } catch (e: any) {
        // Gracefully retry on timeout during cold initialization delays naturally 
        // mitigating server sync bottlenecks. 
        if (retries > 0) {
          setTimeout(() => {
            this.fetchSemanticTokens(view, retries - 1);
          }, 1000);
        }
      }
    }
  });

  // Dominant inheritance mapping forcing wrapped syntax layers logically
  // to inherit from the external LSP CSS wrappers.
  const semanticTheme = EditorView.theme({
    ".cm-semantic-token *": {
      color: "inherit !important",
      fontStyle: "inherit !important",
      fontWeight: "inherit !important",
      textDecoration: "inherit !important"
    }
  });

  return [semanticTokensField, plugin, semanticTheme];
}

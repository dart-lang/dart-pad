// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import { dartLanguage } from "codemirror-lang-dart";
import { yaml } from "@codemirror/lang-yaml";
import { markdown } from "@codemirror/lang-markdown";
import { javascript } from "@codemirror/lang-javascript";
import { html } from "@codemirror/lang-html";
import { css } from "@codemirror/lang-css";
import { json } from "@codemirror/lang-json";
import { xml } from "@codemirror/lang-xml";
import { sass } from "@codemirror/lang-sass";
import { sql } from "@codemirror/lang-sql";
import {
  EditorSelection,
  EditorState,
  Compartment,
  Extension,
} from "@codemirror/state";
import { EditorView, keymap, showPanel, KeyBinding } from "@codemirror/view";
import {
  formatKeymap,
  renameKeymap,
  jumpToDefinitionKeymap,
  findReferencesKeymap,
} from "@codemirror/lsp-client";
import { basicSetup } from "codemirror";
import { dartpad as dartpadTheme } from "./theme";
import { indentWithTab, toggleLineComment } from "@codemirror/commands";
import {
  syntaxHighlighting,
  defaultHighlightStyle,
  HighlightStyle,
  indentUnit,
} from "@codemirror/language";
import { lintGutter, linter } from "@codemirror/lint";
import { LSPPlugin } from "@codemirror/lsp-client";
import { createLspClient } from "./lspClient";
import { gotoDefinitionOnClick } from "./gotoDefinition";
import { diagnosticHoverToolbar } from "./diagnosticHoverToolbar";
import { forceSemanticTokensRefresh } from "./semanticHighlighting";
import { formatDocument, formatDocumentAsync } from "./formatting";
import { selectionAction } from "./selectionAction";

declare global {
  interface Window {
    _codemirror: {
      // codemirror types
      Compartment: typeof Compartment;
      EditorSelection: typeof EditorSelection;
      EditorState: typeof EditorState;
      EditorView: typeof EditorView;

      // codemirror extensions
      basicSetup: Extension;
      defaultHighlightStyle: HighlightStyle;
      indentUnit: typeof indentUnit;
      indentWithTab: any;
      keymap: typeof keymap;
      lintGutter: () => Extension;
      linter: (source: any, config?: any) => Extension;
      LSPPlugin: typeof LSPPlugin;
      formatDocument: typeof formatDocument;
      formatDocumentAsync: typeof formatDocumentAsync;
      dartpadTheme: Extension;
      showPanel: typeof showPanel;
      syntaxHighlighting: (style: any, options?: any) => Extension;
      toggleLineComment: any;

      // custom extensions
      dartLanguage: typeof dartLanguage;
      yaml: typeof yaml;
      markdown: typeof markdown;
      javascript: typeof javascript;
      html: typeof html;
      css: typeof css;
      json: typeof json;
      xml: typeof xml;
      sass: typeof sass;
      sql: typeof sql;
      createLspClient: typeof createLspClient;
      gotoDefinitionOnClick: typeof gotoDefinitionOnClick;
      selectionAction: typeof selectionAction;
      diagnosticHoverToolbar: typeof diagnosticHoverToolbar;
      forceSemanticTokensRefresh: typeof forceSemanticTokensRefresh;

      // test utilities
      getRegisteredKeys: (state: EditorState) => string[];
      formatKeymap: readonly KeyBinding[];
      renameKeymap: readonly KeyBinding[];
      jumpToDefinitionKeymap: readonly KeyBinding[];
      findReferencesKeymap: readonly KeyBinding[];
    };
  }
}

/**
 * Returns all key binding strings registered in the given editor state.
 *
 * This is used by tests to verify that every shortcut listed in the
 * shortcuts dialog is actually registered in CodeMirror.
 */
function getRegisteredKeys(state: EditorState): string[] {
  return state
    .facet(keymap)
    .flat()
    .flatMap((b) => {
      const keys: string[] = [b.key, b.mac, b.linux, b.win].filter(
        (k): k is string => k != null,
      );
      // CodeMirror stores Shift-modified handlers (e.g. Shift-Tab for
      // indentWithTab) as a separate `shift` property rather than a
      // distinct key string. Emit `Shift-{key}` so tests can find them.
      if (b.shift && b.key) {
        keys.push(`Shift-${b.key}`);
      }
      return keys;
    });
}

/**
 * Main global interface exporting CodeMirror dependencies to Dart JS-Interop bindings.
 */
window._codemirror = {
  // codemirror types
  Compartment,
  EditorSelection,
  EditorState,
  EditorView,

  // codemirror extensions
  basicSetup,
  defaultHighlightStyle,
  indentUnit,
  indentWithTab,
  keymap,
  lintGutter,
  linter,
  LSPPlugin,
  formatDocument,
  formatDocumentAsync,
  dartpadTheme,
  showPanel,
  syntaxHighlighting,
  toggleLineComment,

  // custom extensions
  dartLanguage,
  yaml,
  markdown,
  javascript,
  html,
  css,
  json,
  xml,
  sass,
  sql,
  createLspClient,
  gotoDefinitionOnClick,
  selectionAction,
  diagnosticHoverToolbar,
  forceSemanticTokensRefresh,

  // test utilities
  getRegisteredKeys,
  formatKeymap,
  renameKeymap,
  jumpToDefinitionKeymap,
  findReferencesKeymap,
};

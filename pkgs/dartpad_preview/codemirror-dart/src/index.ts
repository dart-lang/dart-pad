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
import { EditorView, keymap, showPanel } from "@codemirror/view";
import { basicSetup } from "codemirror";
import { oneDark } from "@codemirror/theme-one-dark";
import { indentWithTab, toggleLineComment } from "@codemirror/commands";
import {
  syntaxHighlighting,
  defaultHighlightStyle,
  HighlightStyle,
} from "@codemirror/language";
import { lintGutter, linter } from "@codemirror/lint";
import { LSPPlugin, formatDocument } from "@codemirror/lsp-client";
import { createLspClient } from "./lspClient";
import { gotoDefinitionOnClick } from "./gotoDefinition";
import { selectionAction } from "./selectionAction";
import { diagnosticHoverToolbar } from "./diagnosticHoverToolbar";
import { forceSemanticTokensRefresh } from "./semanticHighlighting";

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
      indentWithTab: any;
      keymap: typeof keymap;
      lintGutter: () => Extension;
      linter: (source: any, config?: any) => Extension;
      LSPPlugin: typeof LSPPlugin;
      formatDocument: typeof formatDocument;
      oneDark: Extension;
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
    };
  }
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
  indentWithTab,
  keymap,
  lintGutter,
  linter,
  LSPPlugin,
  formatDocument,
  oneDark,
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
};

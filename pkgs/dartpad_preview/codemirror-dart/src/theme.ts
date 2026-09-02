// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import { EditorView } from "@codemirror/view";
import { HighlightStyle, syntaxHighlighting } from "@codemirror/language";
import { tags } from "@lezer/highlight";

export const dartpadTheme = EditorView.theme({
  "&": {
    fontFamily: "'Roboto Mono', monospace",
    fontWeight: "400",
    // Default to Light Mode variables and styles
    backgroundColor: "#fff",
    color: "#4a4a4a",
    colorScheme: "light",
    "--cm-builtin": "#4a4a4a",
    "--cm-comment": "#5F6368",
    "--cm-keyword": "#007a27",
    "--cm-atom": "#2f4960",
    "--cm-variable": "#0E161F",
    "--cm-variable2": "#a54a78",
    "--cm-string": "#bc0056",
    "--cm-string2": "#983ab3",
    "--cm-number": "#00786d",
    "--cm-attribute": "#0E161F",
    "--cm-qualifier": "#d32923",
    "--cm-meta": "#00786d",
    "--cm-header": "#0E161F",
    "--cm-operator": "#4a4a4a",
    "--cm-def": "#4a4a4a",
    "--cm-tag": "#007a27",
    "--cm-property": "#a54a78",
  },

  // Light Mode Scoped Styles
  ".cm-content": {
    caretColor: "#4a4a4a",
  },
  ".cm-cursor, .cm-dropCursor": {
    borderLeft: "1px solid #4a4a4a",
  },
  ".cm-selectionBackground, .cm-content ::selection": {
    backgroundColor: "#e8e8e8 !important",
  },
  ".cm-gutters": {
    backgroundColor: "#fff !important",
    color: "#d0d0d2",
    borderRight: "none",
  },
  "&.cm-focused .cm-matchingBracket, &.cm-focused .cm-nonmatchingBracket": {
    outline: "1px solid #606060",
    color: "#a54a78 !important",
  },
  ".cm-activeLine": {
    backgroundColor: "rgba(27, 134, 245, 0.035)",
  },
  ".cm-activeLineGutter": {
    backgroundColor: "rgba(27, 134, 245, 0.07)",
  },

  // Dark Mode Overrides (triggered by data-theme="dark" on ancestor html or body)
  '[data-theme="dark"] &': {
    backgroundColor: "#0E161F",
    color: "#FFFFFF",
    colorScheme: "dark",
    "--cm-builtin": "#FFFFFF",
    "--cm-comment": "#909CC3",
    "--cm-keyword": "#50E191",
    "--cm-atom": "#FF916E",
    "--cm-variable": "#00D2FA",
    "--cm-variable2": "#FF916E",
    "--cm-string": "#FA557D",
    "--cm-string2": "#FF00FA",
    "--cm-number": "#909090",
    "--cm-attribute": "#00D2FA",
    "--cm-qualifier": "#FF9B00",
    "--cm-meta": "#909090",
    "--cm-header": "#00D2FA",
    "--cm-operator": "#FFFFFF",
    "--cm-def": "#FFFFFF",
    "--cm-tag": "#50E191",
    "--cm-property": "#FF2D64",
  },
  '[data-theme="dark"] & .cm-content': {
    caretColor: "white",
  },
  '[data-theme="dark"] & .cm-cursor, [data-theme="dark"] & .cm-dropCursor': {
    borderLeft: "1px solid white",
  },
  '[data-theme="dark"] & .cm-selectionBackground, [data-theme="dark"] & .cm-content ::selection':
    {
      backgroundColor: "#23364D !important",
    },
  '[data-theme="dark"] & .cm-gutters': {
    backgroundColor: "#0E161F !important",
    color: "#909090",
    borderRight: "none",
  },
  '[data-theme="dark"] &.cm-focused .cm-matchingBracket, [data-theme="dark"] &.cm-focused .cm-nonmatchingBracket':
    {
      outline: "1px solid #606060",
      color: "#FF2D64 !important",
    },
  '[data-theme="dark"] & .cm-activeLine': {
    backgroundColor: "rgba(32, 143, 253, 0.035)",
  },
  '[data-theme="dark"] & .cm-activeLineGutter': {
    backgroundColor: "rgba(32, 143, 253, 0.07)",
  },

  // Shared Styles
  ".cm-foldPlaceholder": {
    backgroundColor: "rgb(82, 192, 155)",
    color: "#000",
    fontWeight: "bold",
    border: "none",
    padding: "0 3px",
  },
  ".cm-tooltip.cm-rename-message-tooltip": {
    border: "1px solid #1B86F5 !important",
    borderRadius: "3px !important",
    backgroundColor: "#ffffff !important",
    color: "#1E1E1E !important",
    boxShadow: "0 2px 6px rgba(0, 0, 0, 0.15) !important",
    maxWidth: "max-content !important",
    width: "max-content !important",
    whiteSpace: "nowrap !important",
    padding: "3px 8px !important",
    fontSize: "12px !important",
    lineHeight: "1.3 !important",
    userSelect: "none",
    cursor: "default",
  },
  ".cm-tooltip.cm-rename-message-tooltip .cm-tooltip-arrow::before": {
    borderTopColor: "#1B86F5 !important",
    borderBottomColor: "#1B86F5 !important",
  },
  ".cm-tooltip.cm-rename-message-tooltip .cm-tooltip-arrow::after": {
    borderTopColor: "#1B86F5 !important",
    borderBottomColor: "#1B86F5 !important",
  },
  '[data-theme="dark"] & .cm-tooltip.cm-rename-message-tooltip': {
    borderColor: "#208FFD !important",
    backgroundColor: "#1E1E1E !important",
    color: "#FFFFFF !important",
  },
  '[data-theme="dark"] & .cm-tooltip.cm-rename-message-tooltip .cm-tooltip-arrow::before':
    {
      borderTopColor: "#208FFD !important",
      borderBottomColor: "#208FFD !important",
    },
  '[data-theme="dark"] & .cm-tooltip.cm-rename-message-tooltip .cm-tooltip-arrow::after':
    {
      borderTopColor: "#208FFD !important",
      borderBottomColor: "#208FFD !important",
    },
});

export const dartpadHighlightStyle = HighlightStyle.define([
  { tag: tags.keyword, color: "var(--cm-keyword)" },
  {
    tag: [tags.comment, tags.lineComment, tags.blockComment],
    color: "var(--cm-comment)",
  },
  { tag: tags.standard(tags.name), color: "var(--cm-builtin)" },
  { tag: [tags.atom, tags.bool, tags.null], color: "var(--cm-atom)" },
  { tag: tags.variableName, color: "var(--cm-variable)" },
  { tag: [tags.typeName, tags.className], color: "var(--cm-variable2)" },
  { tag: tags.string, color: "var(--cm-string)" },
  { tag: tags.special(tags.string), color: "var(--cm-string2)" },
  { tag: tags.number, color: "var(--cm-number)" },
  { tag: tags.attributeName, color: "var(--cm-attribute)" },
  { tag: [tags.namespace, tags.modifier], color: "var(--cm-qualifier)" },
  { tag: [tags.meta, tags.annotation], color: "var(--cm-meta)" },
  { tag: tags.heading, color: "var(--cm-header)", fontWeight: "bold" },
  { tag: [tags.operator, tags.operatorKeyword], color: "var(--cm-operator)" },
  {
    tag: [tags.definition(tags.name), tags.definition(tags.variableName)],
    color: "var(--cm-def)",
  },
  { tag: tags.tagName, color: "var(--cm-tag)" },
  { tag: tags.propertyName, color: "var(--cm-property)" },
]);

export const dartpad = [
  dartpadTheme,
  syntaxHighlighting(dartpadHighlightStyle),
];

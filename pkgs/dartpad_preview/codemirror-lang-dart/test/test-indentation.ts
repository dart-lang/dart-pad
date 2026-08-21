// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import { createRequire } from "node:module";
const require = createRequire(import.meta.url);

(global as any).window = global;
(global as any).self = global;
(global as any).location = { href: "file:///" };
(global as any)._codemirror = {
  dartLanguage: (cb: any) => {
    (global as any).dartParseCallback = cb;
    return {};
  },
};

require("./dist/dart_impl.cjs");

import { dartLanguage } from "../src/index.js";
import { EditorState } from "@codemirror/state";
import { getIndentation } from "@codemirror/language";
import * as assert from "node:assert";

describe("Dart Auto-Indentation", () => {
  it("indents after opening parenthesis (e.g. return Container()", () => {
    const dartSupport = dartLanguage((global as any).dartParseCallback);
    const doc = "  return Container(\n";
    const state = EditorState.create({
      doc,
      extensions: [dartSupport],
    });

    const indent = getIndentation(state, doc.length);
    assert.strictEqual(indent, 4); // 2 spaces base + 2 spaces indent
  });

  it("indents after opening brace", () => {
    const dartSupport = dartLanguage((global as any).dartParseCallback);
    const doc = "void main() {\n";
    const state = EditorState.create({
      doc,
      extensions: [dartSupport],
    });

    const indent = getIndentation(state, doc.length);
    assert.strictEqual(indent, 2); // 0 spaces base + 2 spaces indent
  });

  it("indents after opening square bracket", () => {
    const dartSupport = dartLanguage((global as any).dartParseCallback);
    const doc = "  final list = [\n";
    const state = EditorState.create({
      doc,
      extensions: [dartSupport],
    });

    const indent = getIndentation(state, doc.length);
    assert.strictEqual(indent, 4);
  });

  it("indents after arrow =>", () => {
    const dartSupport = dartLanguage((global as any).dartParseCallback);
    const doc = "Widget build(BuildContext context) =>\n";
    const state = EditorState.create({
      doc,
      extensions: [dartSupport],
    });

    const indent = getIndentation(state, doc.length);
    assert.strictEqual(indent, 2);
  });

  it("maintains current indentation on standard statements", () => {
    const dartSupport = dartLanguage((global as any).dartParseCallback);
    const doc = "  final a = 1;\n";
    const state = EditorState.create({
      doc,
      extensions: [dartSupport],
    });

    const indent = getIndentation(state, doc.length);
    assert.strictEqual(indent, 2);
  });

  it("outdents before closing bracket", () => {
    const dartSupport = dartLanguage((global as any).dartParseCallback);
    const doc = "  return Container(\n  );";
    const state = EditorState.create({
      doc,
      extensions: [dartSupport],
    });

    const line2Pos = doc.indexOf("  );");
    const indent = getIndentation(state, line2Pos);
    assert.strictEqual(indent, 0);
  });
});

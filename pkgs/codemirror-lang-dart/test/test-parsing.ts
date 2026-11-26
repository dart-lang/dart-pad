// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import { createRequire } from "module";
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
import { syntaxTree } from "@codemirror/language";
import { printTree } from "./test-helper.js";
import * as assert from "assert";

describe("Dart Analyzer Parsing", () => {
  it("parses basic code correctly into TopLevel blocks", () => {
    const dartSupport = dartLanguage((global as any).dartParseCallback);
    const state = EditorState.create({
      doc: "void main() {\n  print('Hello');\n}\n\nint foo = 5;",
      extensions: [dartSupport],
    });

    const tree = syntaxTree(state);

    let topLevelCount = 0;
    tree.cursor().iterate((node) => {
      if (node.name === "TopLevel") topLevelCount++;
    });
    assert.equal(topLevelCount, 2, "There should be two TopLevel declarations");

    assert.strictEqual(
      printTree(tree),
      "Program(Program(TopLevel(Keyword, Identifier, ArgumentList(Punctuation, Punctuation), Block(Punctuation, Identifier, ArgumentList(Punctuation, String, Punctuation), Punctuation, Punctuation)), TopLevel(Identifier, Identifier, Operator, Number, Punctuation)))",
    );
  });

  it("handles string types natively", () => {
    const dartSupport = dartLanguage((global as any).dartParseCallback);
    const state = EditorState.create({
      doc: "String k = 'some string mapping';",
      extensions: [dartSupport],
    });

    const tree = syntaxTree(state);

    let hasString = false;
    tree.cursor().iterate((node) => {
      if (node.name === "String") hasString = true;
    });
    assert.ok(hasString, "Parser must identify string literals");

    assert.strictEqual(
      printTree(tree),
      "Program(Program(TopLevel(Identifier, Identifier, Operator, String, Punctuation)))",
    );
  });
});

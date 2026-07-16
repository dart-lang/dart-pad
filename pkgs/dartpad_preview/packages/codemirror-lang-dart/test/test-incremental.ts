import { createRequire } from 'module';
const require = createRequire(import.meta.url);

(global as any).window = global;
(global as any).self = global;
(global as any).location = { href: "file:///" };
(global as any)._codemirror = {
  dartLanguage: (cb: any) => { (global as any).dartParseCallback = cb; return {}; }
};

require("./dist/dart_impl.cjs");

import { dartLanguage } from "../src/index.js";
import { EditorState } from "@codemirror/state";
import { syntaxTree } from "@codemirror/language";
import { printTree } from "./test-helper.js";
import * as assert from "assert";

describe("Dart Analyzer Incremental Parsing & Bleeding", () => {
  it("handles unmodified isolated edits properly", () => {
    const dartSupport = dartLanguage((global as any).dartParseCallback);
    let state = EditorState.create({
      doc: "void foo() {}\nvoid bar() {}",
      extensions: [dartSupport]
    });

    // Initial parse gives two TopLevel blocks
    let tree = syntaxTree(state);
    const expected = "Program(Program(TopLevel(Keyword, Identifier, ArgumentList(Punctuation, Punctuation), Block(Punctuation, Punctuation)), TopLevel(Keyword, Identifier, ArgumentList(Punctuation, Punctuation), Block(Punctuation, Punctuation))))";
    assert.strictEqual(printTree(tree), expected);

    // Mutate the second block only
    state = state.update({
      changes: { from: 19, to: 19, insert: " " }
    }).state;

    tree = syntaxTree(state);
    assert.strictEqual(printTree(tree), expected);
  });

  it("handles lexical bleeding via unterminated comments", () => {
    const dartSupport = dartLanguage((global as any).dartParseCallback);
    let state = EditorState.create({
      doc: "void foo() {}\nvoid bar() {}",
      extensions: [dartSupport]
    });

    // Initially parsed cleanly
    const expectedInitial = "Program(Program(TopLevel(Keyword, Identifier, ArgumentList(Punctuation, Punctuation), Block(Punctuation, Punctuation)), TopLevel(Keyword, Identifier, ArgumentList(Punctuation, Punctuation), Block(Punctuation, Punctuation))))";
    assert.strictEqual(printTree(syntaxTree(state)), expectedInitial);

    // Inject a block comment start to swallow the rest of the file
    state = state.update({
      changes: { from: 0, to: 0, insert: "/*" }
    }).state;

    const tree = syntaxTree(state);
    assert.strictEqual(printTree(tree), "Program(Program)"); // Swallowed entirely without error
  });

  it("handles syntactic bleeding via unbalanced brackets", () => {
    const dartSupport = dartLanguage((global as any).dartParseCallback);
    let state = EditorState.create({
      doc: "void foo() {}\nvoid bar() {}",
      extensions: [dartSupport]
    });

    // Delete closing bracket of first TopLevel to break encapsulation
    state = state.update({
      changes: { from: 12, to: 13 }
    }).state;

    const tree = syntaxTree(state);
    assert.strictEqual(printTree(tree), "Program(Program(TopLevel(Keyword, Identifier, ArgumentList(Punctuation, Punctuation), Block(Punctuation, Keyword, Identifier, ArgumentList(Punctuation, Punctuation), Block(Punctuation, Punctuation), Punctuation))))");
  });
});

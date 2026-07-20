// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
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
import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const casesDir = path.join(__dirname, "cases");

describe("Dart Analyzer Grammar Syntax Tolerance", () => {
  const dartSupport = dartLanguage((global as any).dartParseCallback);

  if (!fs.existsSync(casesDir)) {
    console.warn("Could not find grammar test dir. Skipping.");
    return;
  }

  for (const file of fs.readdirSync(casesDir)) {
    if (!/\.txt$/.test(file)) continue;

    const content = fs.readFileSync(path.join(casesDir, file), "utf8");
    const testCases = content.split(/^#\s/m).filter((s) => s.trim().length > 0);

    const groupName = /^[^\.]*/.exec(file)![0];

    describe(groupName, () => {
      for (const t of testCases) {
        const lines = t.split("\n").map((l) => l.replace(/\r$/, ""));
        const name = lines[0].trim();

        const separatorIdx = lines.indexOf("==>");
        if (separatorIdx === -1) continue;

        let code = lines.slice(1, separatorIdx).join("\n").trim();
        let expectedTree = lines
          .slice(separatorIdx + 1)
          .join("\n")
          .trim();
        if (code.length === 0) continue;

        it(`verifies tree format for ${name}`, () => {
          const state = EditorState.create({
            doc: code,
            extensions: [dartSupport],
          });
          const tree = syntaxTree(state);
          assert.strictEqual(
            printTree(tree),
            expectedTree,
            "Tree formatting must match standard syntax representations natively",
          );
        });
      }
    });
  }
});

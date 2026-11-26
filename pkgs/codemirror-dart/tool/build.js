// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const packageDir = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const rollupBin = resolve(
  packageDir,
  "node_modules",
  "rollup",
  "dist",
  "bin",
  "rollup",
);

execFileSync(process.execPath, [rollupBin, "-c"], {
  cwd: packageDir,
  stdio: "inherit",
});

for (const relativePath of [
  "lib/assets/codemirror-dart.bundle.js",
  "lib/assets/THIRD_PARTY_NOTICES.txt",
]) {
  const filePath = resolve(packageDir, relativePath);
  const normalized = `${readFileSync(filePath, "utf8")
    .replace(/\r\n?/g, "\n")
    .replace(/[ \t]+$/gm, "")
    .trimEnd()}\n`;
  writeFileSync(filePath, normalized);
}

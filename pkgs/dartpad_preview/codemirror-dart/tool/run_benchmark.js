// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import { execFileSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const packageDir = resolve(dirname(fileURLToPath(import.meta.url)), "..");

execFileSync(process.execPath, [resolve(packageDir, "tool", "build.js")], {
  cwd: packageDir,
  stdio: "inherit",
});

const dartArgs = [
  "compile",
  "js",
  "-O2",
  "benchmark/benchmark.dart",
  "-o",
  "benchmark/dist/benchmark.dart.js",
];
if (process.platform === "win32") {
  // Dart is commonly exposed by Flutter as dart.bat. Unlike PowerShell,
  // execFileSync does not resolve batch files through PATHEXT by itself.
  execFileSync(
    process.env.ComSpec ?? "cmd.exe",
    ["/d", "/c", "dart", ...dartArgs],
    {
      cwd: packageDir,
      stdio: "inherit",
    },
  );
} else {
  execFileSync("dart", dartArgs, { cwd: packageDir, stdio: "inherit" });
}

const benchmarkPath = resolve(packageDir, "benchmark", "benchmark.html");
if (process.env.CI || process.env.CODEMIRROR_DART_NO_OPEN === "1") {
  console.log(`Benchmark ready at ${benchmarkPath}`);
  process.exit(0);
}

if (process.platform === "win32") {
  execFileSync("cmd.exe", ["/c", "start", "", benchmarkPath]);
} else if (process.platform === "darwin") {
  execFileSync("open", [benchmarkPath]);
} else {
  execFileSync("xdg-open", [benchmarkPath]);
}

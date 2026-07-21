// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import nodeResolve from "@rollup/plugin-node-resolve";
import typescript from "@rollup/plugin-typescript";
import license from "rollup-plugin-license";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const plugins = [
  typescript(),
  nodeResolve({
    extensions: [".js", ".ts"],
    dedupe: (importee) =>
      importee.startsWith("@codemirror/") ||
      importee.startsWith("@lezer/") ||
      importee === "codemirror",
  }),
];

export default [
  {
    input: "src/index.ts",
    preserveSymlinks: true,
    output: {
      file: "lib/assets/codemirror-dart.bundle.js",
      format: "iife",
      banner: `// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
// Third-party licenses are listed in THIRD_PARTY_NOTICES.txt.`,
    },
    plugins: [
      ...plugins,
      license({
        thirdParty: {
          output: path.join(
            __dirname,
            "lib",
            "assets",
            "THIRD_PARTY_NOTICES.txt",
          ),
        },
      }),
    ],
  },
];

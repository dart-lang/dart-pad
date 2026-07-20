import nodeResolve from "@rollup/plugin-node-resolve";
import typescript from "@rollup/plugin-typescript";
import license from 'rollup-plugin-license';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const plugins = [
  typescript(),
  nodeResolve({
    extensions: [".js", ".ts"],
    dedupe: (importee) => importee.startsWith("@codemirror/") || importee.startsWith("@lezer/") || importee === "codemirror"
  })
];

export default [
  {
    input: "src/index.ts",
    preserveSymlinks: true,
    output: {
      file: "lib/assets/codemirror-dart.bundle.js",
      format: "iife",
    },
    plugins: [
      ...plugins,
      license({
        banner: {
          content: `Copyright (c) 2026, the Dart project authors.
For third-party licenses, see THIRD_PARTY_NOTICES.txt.`,
          commentStyle: 'ignored',
        },
        thirdParty: {
          output: path.join(__dirname, 'lib', 'assets', 'THIRD_PARTY_NOTICES.txt'),
        }
      }),
    ]
  },
  {
    input: "benchmark/benchmark.ts",
    preserveSymlinks: true,
    output: {
      file: "benchmark/dist/benchmark.bundle.js",
      format: "iife",
    },
    plugins
  }
];

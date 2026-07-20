// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Runs the codemirror-lang-dart test suite.
//
// Usage: node tool/run_tests.mjs

import { mkdirSync } from 'fs';
import { execSync } from 'child_process';
import { resolve, delimiter } from 'path';

const localBin = resolve('node_modules', '.bin');
const env = { ...process.env, PATH: localBin + delimiter + process.env.PATH };
const opts = { stdio: 'inherit', env };

// Ensure the test output directory exists.
mkdirSync('test/dist', { recursive: true });

// Compile the Dart test environment to JavaScript.
execSync(
  'dart compile js -Dnode=true -O2 test/dart_test_env.dart -o test/dist/dart_impl.cjs',
  opts,
);

// Run the Mocha test suite.
execSync(
  'mocha --node-option loader=ts-node/esm test/test-*.ts',
  opts,
);

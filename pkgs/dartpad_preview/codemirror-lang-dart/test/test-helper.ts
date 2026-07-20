// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import type { TreeCursor, Tree } from "@lezer/common";

export function printTree(tree: Tree): string {
  let output = "";
  function walk(cursor: TreeCursor) {
    output += cursor.name;
    if (cursor.firstChild()) {
      output += "(";
      let first = true;
      do {
        if (!first) output += ", ";
        walk(cursor);
        first = false;
      } while (cursor.nextSibling());
      output += ")";
      cursor.parent();
    }
  }
  walk(tree.cursor());
  return output;
}

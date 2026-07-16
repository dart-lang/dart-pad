import { dartLanguage } from "codemirror-lang-dart";
import { parser as jsParser } from "@lezer/javascript";
import { Input, Tree, TreeFragment } from "@lezer/common";

const js10Lines = `
function greet() {
  console.log("Hello World");
}
for (let i = 0; i < 10; i++) {
  greet();
}
class Foo {
  bar() { return 1; }
}
`;

const dart10Lines = `
void greet() {
  print("Hello World");
}
void main() {
  for (int i = 0; i < 10; i++) greet();
}
class Foo {
  int bar() => 1;
}
`;

function generateCode(base: string, count: number): string {
  let res = "";
  for (let i = 0; i < count; i++) {
    res += base.replace(/greet/g, "greet" + i).replace(/Foo/g, "Foo" + i) + "\n";
  }
  return res;
}

const js10k = generateCode(js10Lines, 1000); // 10 * 1000 = 10,000 lines
const dart10k = generateCode(dart10Lines, 1000);

class StringInput implements Input {
  constructor(public string: string) { }
  get length() { return this.string.length; }
  chunk(off: number) { return this.string.slice(off); }
  lineChunks: boolean = false;
  read(from: number, to: number) { return this.string.slice(from, to); }
}

function runPerf(name: string, fn: () => void) {
  let start = performance.now();
  fn();
  let time = performance.now() - start;
  let elem = document.createElement("div");
  elem.textContent = `${name}: ${time.toFixed(2)} ms`;
  document.body.appendChild(elem);
  console.log(`${name}: ${time.toFixed(2)} ms`);
}

declare global {
  interface Window {
    runBenchmark: (dartCallback: (code: string) => Int32Array) => void;
  }
}

window.runBenchmark = (dartCallback: (code: string) => Int32Array) => {
  const dartParser = dartLanguage(dartCallback).language.parser;

  let jsInput10 = new StringInput(js10Lines);
  let dartInput10 = new StringInput(dart10Lines);
  let jsInput10k = new StringInput(js10k);
  let dartInput10k = new StringInput(dart10k);

  // Warmup
  dartParser.parse(dartInput10);
  jsParser.parse(jsInput10);

  document.body.appendChild(document.createElement("hr"));
  document.body.appendChild(document.createTextNode("10 Lines Benchmark"));

  runPerf("Full Parse JS (10 lines)", () => {
    jsParser.parse(jsInput10);
  });
  runPerf("Full Parse Dart SDK (10 lines)", () => {
    dartParser.parse(dartInput10);
  });

  document.body.appendChild(document.createElement("hr"));
  document.body.appendChild(document.createTextNode("10k Lines Benchmark"));

  let jsTree10k: Tree;
  runPerf("Full Parse JS (10k lines)", () => {
    jsTree10k = jsParser.parse(jsInput10k);
  });

  let dartTree10k: Tree;
  runPerf("Full Parse Dart SDK (10k lines)", () => {
    dartTree10k = dartParser.parse(dartInput10k);
  });

  document.body.appendChild(document.createElement("hr"));
  document.body.appendChild(document.createTextNode("Incremental (Modify at END) 10k lines"));

  let jsModEnd10k = js10k + " ";
  let jsInputModEnd10k = new StringInput(jsModEnd10k);
  let jsChangesEnd = [{ fromA: js10k.length, toA: js10k.length, fromB: js10k.length, toB: js10k.length + 1 }];
  runPerf("Incremental Parse JS (End)", () => {
    let oldFragments = TreeFragment.addTree(jsTree10k);
    let shifted = TreeFragment.applyChanges(oldFragments, jsChangesEnd);
    jsParser.parse(jsInputModEnd10k, shifted, [{ from: 0, to: jsModEnd10k.length }]);
  });

  let dartModEnd10k = dart10k + " ";
  let dartInputModEnd10k = new StringInput(dartModEnd10k);
  let dartChangesEnd = [{ fromA: dart10k.length, toA: dart10k.length, fromB: dart10k.length, toB: dart10k.length + 1 }];
  runPerf("Incremental Parse Dart SDK (End)", () => {
    let oldFragments = TreeFragment.addTree(dartTree10k);
    let shifted = TreeFragment.applyChanges(oldFragments, dartChangesEnd);
    dartParser.parse(dartInputModEnd10k, shifted, [{ from: 0, to: dartModEnd10k.length }]);
  });

  document.body.appendChild(document.createElement("hr"));
  document.body.appendChild(document.createTextNode("Incremental (Modify at START) 10k lines"));

  let jsModStart10k = " " + js10k;
  let jsInputModStart10k = new StringInput(jsModStart10k);
  let jsChangesStart = [{ fromA: 0, toA: 0, fromB: 0, toB: 1 }];
  runPerf("Incremental Parse JS (Start)", () => {
    let oldFragments = TreeFragment.addTree(jsTree10k);
    let shifted = TreeFragment.applyChanges(oldFragments, jsChangesStart);
    jsParser.parse(jsInputModStart10k, shifted, [{ from: 0, to: jsModStart10k.length }]);
  });

  let dartModStart10k = " " + dart10k;
  let dartInputModStart10k = new StringInput(dartModStart10k);
  let dartChangesStart = [{ fromA: 0, toA: 0, fromB: 0, toB: 1 }];
  runPerf("Incremental Parse Dart SDK (Start)", () => {
    let oldFragments = TreeFragment.addTree(dartTree10k);
    let shifted = TreeFragment.applyChanges(oldFragments, dartChangesStart);
    dartParser.parse(dartInputModStart10k, shifted, [{ from: 0, to: dartModStart10k.length }]);
  });

  document.body.appendChild(document.createElement("hr"));
  document.body.appendChild(document.createTextNode("Incremental (Unterminated Comment at START) 10k lines"));

  let jsModUnterminated10k = "/*" + js10k;
  let jsInputModUnterminated10k = new StringInput(jsModUnterminated10k);
  let jsChangesUnterminated = [{ fromA: 0, toA: 0, fromB: 0, toB: 2 }];
  runPerf("Incremental Parse JS (Unterminated Comment)", () => {
    let oldFragments = TreeFragment.addTree(jsTree10k);
    let shifted = TreeFragment.applyChanges(oldFragments, jsChangesUnterminated);
    jsParser.parse(jsInputModUnterminated10k, shifted, [{ from: 0, to: jsModUnterminated10k.length }]);
  });

  let dartModUnterminated10k = "/*" + dart10k;
  let dartInputModUnterminated10k = new StringInput(dartModUnterminated10k);
  let dartChangesUnterminated = [{ fromA: 0, toA: 0, fromB: 0, toB: 2 }];
  runPerf("Incremental Parse Dart SDK (Unterminated Comment)", () => {
    let oldFragments = TreeFragment.addTree(dartTree10k);
    let shifted = TreeFragment.applyChanges(oldFragments, dartChangesUnterminated);
    dartParser.parse(dartInputModUnterminated10k, shifted, [{ from: 0, to: dartModUnterminated10k.length }]);
  });

  document.body.appendChild(document.createElement("hr"));
  document.body.appendChild(document.createTextNode("Incremental (Unbalanced Bracket at START) 10k lines"));

  let jsModUnbalanced10k = "{" + js10k;
  let jsInputModUnbalanced10k = new StringInput(jsModUnbalanced10k);
  let jsChangesUnbalanced = [{ fromA: 0, toA: 0, fromB: 0, toB: 1 }];
  runPerf("Incremental Parse JS (Unbalanced Bracket)", () => {
    let oldFragments = TreeFragment.addTree(jsTree10k);
    let shifted = TreeFragment.applyChanges(oldFragments, jsChangesUnbalanced);
    jsParser.parse(jsInputModUnbalanced10k, shifted, [{ from: 0, to: jsModUnbalanced10k.length }]);
  });

  let dartModUnbalanced10k = "{" + dart10k;
  let dartInputModUnbalanced10k = new StringInput(dartModUnbalanced10k);
  let dartChangesUnbalanced = [{ fromA: 0, toA: 0, fromB: 0, toB: 1 }];
  runPerf("Incremental Parse Dart SDK (Unbalanced Bracket)", () => {
    let oldFragments = TreeFragment.addTree(dartTree10k);
    let shifted = TreeFragment.applyChanges(oldFragments, dartChangesUnbalanced);
    dartParser.parse(dartInputModUnbalanced10k, shifted, [{ from: 0, to: dartModUnbalanced10k.length }]);
  });

  document.body.appendChild(document.createElement("hr"));
  document.body.appendChild(document.createTextNode("Incremental (Insert Template lines at MIDDLE) 10k lines"));

  let jsMiddleIdx = js10k.indexOf("function greet500()");
  let jsModMiddle10k = js10k.slice(0, jsMiddleIdx) + js10Lines + js10k.slice(jsMiddleIdx);
  let jsInputModMiddle10k = new StringInput(jsModMiddle10k);
  let jsChangesMiddle = [{ fromA: jsMiddleIdx, toA: jsMiddleIdx, fromB: jsMiddleIdx, toB: jsMiddleIdx + js10Lines.length }];
  runPerf("Incremental Parse JS (Middle Insert)", () => {
    let oldFragments = TreeFragment.addTree(jsTree10k);
    let shifted = TreeFragment.applyChanges(oldFragments, jsChangesMiddle);
    jsParser.parse(jsInputModMiddle10k, shifted, [{ from: 0, to: jsModMiddle10k.length }]);
  });

  let dartMiddleIdx = dart10k.indexOf("void greet500()");
  let dartModMiddle10k = dart10k.slice(0, dartMiddleIdx) + dart10Lines + dart10k.slice(dartMiddleIdx);
  let dartInputModMiddle10k = new StringInput(dartModMiddle10k);
  let dartChangesMiddle = [{ fromA: dartMiddleIdx, toA: dartMiddleIdx, fromB: dartMiddleIdx, toB: dartMiddleIdx + dart10Lines.length }];
  runPerf("Incremental Parse Dart SDK (Middle Insert)", () => {
    let oldFragments = TreeFragment.addTree(dartTree10k);
    let shifted = TreeFragment.applyChanges(oldFragments, dartChangesMiddle);
    dartParser.parse(dartInputModMiddle10k, shifted, [{ from: 0, to: dartModMiddle10k.length }]);
  });
};


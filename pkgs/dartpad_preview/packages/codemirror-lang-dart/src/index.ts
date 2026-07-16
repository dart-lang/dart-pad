import { NodeSet, NodeType, Parser, Tree, PartialParse, Input, TreeFragment } from "@lezer/common";
import { styleTags, tags as t } from "@lezer/highlight";
import { Language, LanguageSupport, foldNodeProp, foldInside } from "@codemirror/language";

import { Facet } from "@codemirror/state";

/**
 * Defines the AST node types and their corresponding syntax highlighting tags and behaviors for the Dart language.
 * Connects Lezer tree nodes to CodeMirror theme identifiers.
 */
export const dartNodeSet = new NodeSet([
  NodeType.define({ id: 0, name: "Error" }),
  NodeType.define({ id: 1, name: "Program", top: true }),
  NodeType.define({ id: 2, name: "Keyword", props: [styleTags({ Keyword: t.keyword })] }),
  NodeType.define({ id: 3, name: "Identifier", props: [styleTags({ Identifier: t.variableName })] }),
  NodeType.define({ id: 4, name: "String", props: [styleTags({ String: t.string })] }),
  NodeType.define({ id: 5, name: "Number", props: [styleTags({ Number: t.number })] }),
  NodeType.define({ id: 6, name: "Operator", props: [styleTags({ Operator: t.operator })] }),
  NodeType.define({ id: 7, name: "Punctuation", props: [styleTags({ Punctuation: t.punctuation })] }),
  NodeType.define({ id: 8, name: "Comment", props: [styleTags({ Comment: t.comment })] }),
  NodeType.define({ id: 9, name: "Block", props: [[foldNodeProp, foldInside]] }),
  NodeType.define({ id: 10, name: "List", props: [[foldNodeProp, foldInside]] }),
  NodeType.define({ id: 11, name: "ArgumentList", props: [[foldNodeProp, foldInside]] }),
  NodeType.define({ id: 12, name: "TopLevel" }),
]);

/**
 * Implements an incremental parser state for Dart, adhering to CodeMirror's `PartialParse` interface.
 * Handles extracting reusable tree fragments from previous parses for performance optimization.
 */
class DartPartialParse implements PartialParse {
  parsedPos: number;

  /**
   * Initializes the partial parse.
   * @param input The text input buffer containing the document source.
   * @param parseCode The Dart-JS interop callback that synchronously performs syntax analysis.
   * @param fragments Previous syntax tree fragments that may be partially reused during incremental edits.
   */
  constructor(
    private input: Input,
    private parseCode: (code: string, cleanRanges: number[]) => Int32Array,
    private fragments: readonly TreeFragment[]
  ) {
    this.parsedPos = input.length;
  }

  /**
   * Evaluates the current input text and systematically reconstructs the syntax tree.
   * Extracts clean syntax subtrees mapping unedited ranges to optimize Dart's parsing workload.
   * @returns The newly built `Tree`.
   */
  advance(): Tree | null {
    const code = this.input.read(0, this.input.length);

    let reused: Tree[] = [];
    let cleanRanges: number[] = [];

    // Find valid chunks of previous trees to reuse
    for (let fragment of this.fragments) {
      const collectReusable = (node: Tree, startPosInDoc: number) => {
        for (let i = 0; i < node.children.length; i++) {
          let child = node.children[i];
          let childAbsPos = startPosInDoc + node.positions[i];
          let childNewPos = childAbsPos - fragment.offset;
          let end = childNewPos + child.length;

          // Is this child entirely within the unmodified fragment bounds?
          if (childNewPos >= fragment.from && end <= fragment.to) {
            let reusedIndex = reused.length;
            reused.push(child as any as Tree);
            cleanRanges.push(childNewPos, end, reusedIndex);
          } else if ((child as any).children) {
            // It intersects the edit boundary, but might have smaller clean children!
            collectReusable(child as Tree, childAbsPos);
          }
        }
      };

      if (fragment.tree.type.id === 1 || fragment.tree.type.id === 0) {
        collectReusable(fragment.tree, 0);
      }
    }

    const buffer = this.parseCode(code, cleanRanges);
    let nativeBuffer = Array.from(buffer);

    let res = Tree.build({ buffer: nativeBuffer, nodeSet: dartNodeSet, topID: 1, length: code.length, reused: reused });
    return res;
  }

  /**
   * Instructs the parser to pause execution upon reaching a specific character index.
   * Currently a no-op as the Dart backend parses document states synchronously.
   */
  stopAt(pos: number): void { }

  /**
   * Indicates the position at which the partial parse was interrupted.
   * Always `null` since the parse runs synchronously to completion.
   */
  get stoppedAt(): number | null {
    return null;
  }
}

/**
 * A custom CodeMirror Parser that delegates AST generation to the Dart analyzer compiler backend.
 */
export class DartParser extends Parser {
  /**
   * @param dartParseCallback A bridging function that forwards Document state strings to the Dart runtime.
   */
  constructor(private dartParseCallback: (code: string, cleanRanges: number[]) => Int32Array) {
    super();
  }

  /**
   * Spawns a new incremental parsing session when document edits occur.
   */
  createParse(input: Input, fragments: readonly TreeFragment[], ranges: readonly { from: number, to: number }[]): PartialParse {
    return new DartPartialParse(input, this.dartParseCallback, fragments);
  }
}

/**
 * Describes the function signature for invoking the Dart parser.
 * It accepts the full source code and an array isolating clean edit ranges for tree reuse,
 * returning a packed flatbuffer tree representation.
 */
type ParseCallback = (code: string, cleanRanges: number[]) => Int32Array;

/**
 * A CodeMirror State Facet representing metadata associated with the Dart syntax rules.
 */
const dataFacet = Facet.define<any, readonly any[]>();

/**
 * Instantiates the Dart language support extension for CodeMirror.
 * @param parseCallback A function interfacing with the Dart `analyzer` token scanner to generate trees.
 * @returns An initialized `LanguageSupport` object configuring the editor environment.
 */
export function dartLanguage(parseCallback: ParseCallback) {
  const customParser = new DartParser(parseCallback);
  const dartLanguage = new Language(
    dataFacet,
    customParser,
    [] // extensions
  );

  return new LanguageSupport(dartLanguage, []);
}
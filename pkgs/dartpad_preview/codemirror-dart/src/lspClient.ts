import { Extension, Text } from "@codemirror/state";
import { EditorView, keymap } from "@codemirror/view";
import {
  LSPClient,
  Workspace,
  WorkspaceFile,
  LSPPlugin,
  serverCompletion,
  hoverTooltips,
  signatureHelp,
  formatKeymap,
  renameKeymap,
  jumpToDefinitionKeymap,
  findReferencesKeymap,
  serverDiagnostics,
} from "@codemirror/lsp-client";
import { semanticHighlightingPlugin, semanticExtension } from "./semanticHighlighting";
import { LanguageSupport } from "@codemirror/language";

export type LspClientBindings = {
  createExtension: (uri: string) => Extension;
  receiveFromServer: (msg: string) => void;
};

export type NotificationHandler = {
  method: string;
  callback: (client: LSPClient, params: any) => boolean;
};

export function createLspClient(
  sendToServer: (msg: string) => void,
  rootUri: string,
  onInitialized: () => void,
  onDisplayFile: (uri: string) => any,
  notificationHandlers: NotificationHandler[],
  language: LanguageSupport,
): LspClientBindings {
  let handlers: ((msg: string) => void)[] = [];
  const transport = {
    send(message: string) {
      sendToServer(message);
    },
    subscribe(callback: (message: string) => void) {
      handlers.push(callback);
    },
    unsubscribe(callback: (message: string) => void) {
      handlers = handlers.filter((h) => h !== callback);
    },
  };

  const handlersObj: { [method: string]: (client: LSPClient, params: any) => boolean } = {};
  for (const handler of notificationHandlers) {
    handlersObj[handler.method] = handler.callback;
  }

  const client = new LSPClient({
    rootUri,
    timeout: 15000,
    workspace: (c) => new CMWorkspace(c, onDisplayFile),
    notificationHandlers: handlersObj,
    highlightLanguage: (name) => {
      if (!name || name === "dart") return language.language;
      return null;
    },
    extensions: [
      semanticExtension,
      {
        clientCapabilities: {
          workspace: {
            applyEdit: true,
            workspaceEdit: {
              documentChanges: true,
            },
            didChangeWatchedFiles: {
              dynamicRegistration: false,
            },
          },
          textDocument: {
            codeAction: {
              codeActionLiteralSupport: {
                codeActionKind: {
                  valueSet: [
                    "quickfix",
                    "refactor",
                    "refactor.extract",
                    "refactor.inline",
                    "refactor.rewrite",
                    "refactor.convert",
                  ],
                },
              },
              isPreferredSupport: true,
            },
          },
        },
      },
      serverCompletion(),
      [hoverTooltips({ hoverTime: 800 })],
      [keymap.of([...formatKeymap, ...renameKeymap, ...jumpToDefinitionKeymap, ...findReferencesKeymap])],
      signatureHelp(),
      serverDiagnostics(),
    ],
  }).connect(transport);

  client.initializing.then(() => onInitialized());

  return {
    createExtension: (uri: string) => [
      client.plugin(uri, "dart"),
      semanticHighlightingPlugin(client, uri),
    ],
    receiveFromServer: (msg: string) => {
      handlers.forEach((h) => h(msg));
    },
  };
}

/**
 * Representation of a workspace document tracked by the LSP.
 * Keeps track of the file URI, language type, document version,
 * text representation, and active CodeMirror EditorView.
 */
class CMWorkspaceFile implements WorkspaceFile {
  constructor(
    readonly uri: string,
    readonly languageId: string,
    public version: number,
    public doc: Text,
    public view: EditorView | null
  ) { }

  getView() {
    return this.view;
  }
}

/**
 * Subclass of the @codemirror/lsp-client Workspace to support multiple open files.
 * Coordinates open/close events with the LSP, tracks document versions, syncs
 * unsynced edits on changes, and handles switching active files via the frontend callback.
 */
export class CMWorkspace extends Workspace {
  files: CMWorkspaceFile[] = [];
  private fileVersions: { [uri: string]: number } = Object.create(null);
  private pendingDisplayFiles: { [uri: string]: ((view: EditorView | null) => void)[] } = Object.create(null);

  constructor(client: any, private onDisplayFile?: (uri: string) => any) {
    super(client);
  }

  nextFileVersion(uri: string) {
    return (this.fileVersions[uri] = (this.fileVersions[uri] ?? -1) + 1);
  }

  /**
   * Scans all tracked workspace files and synchronizes any changes made in active
   * EditorViews to the LSP client, incrementing file versions accordingly.
   */
  syncFiles() {
    const result: any[] = [];
    for (const file of this.files) {
      if (!file.view) continue;
      const plugin = LSPPlugin.get(file.view);
      if (!plugin) continue;
      const changes = plugin.unsyncedChanges;
      if (!changes.empty) {
        result.push({ changes, file, prevDoc: file.doc });
        file.doc = file.view.state.doc;
        file.version = this.nextFileVersion(file.uri);
        plugin.clear();
      }
    }
    return result;
  }

  /**
   * Registers a file as open. Binds it to its CodeMirror view and notifies
   * the LSP client via `didOpen`.
   */
  openFile(uri: string, languageId: string, view: EditorView) {
    let file = this.getFile(uri) as CMWorkspaceFile | null;
    if (file) {
      file.view = view;
      file.doc = view.state.doc;
    } else {
      file = new CMWorkspaceFile(
        uri,
        languageId,
        this.nextFileVersion(uri),
        view.state.doc,
        view
      );
      this.files.push(file);
    }
    this.client.didOpen(file);

    // Resolve any pending displayFile promises!
    if (this.pendingDisplayFiles[uri]) {
      this.pendingDisplayFiles[uri].forEach((resolve) => resolve(view));
      delete this.pendingDisplayFiles[uri];
    }
  }

  /**
   * Registers a file as closed by detaching the CodeMirror view and notifying
   * the LSP client via `didClose`.
   */
  closeFile(uri: string, view: EditorView) {
    const file = this.getFile(uri) as CMWorkspaceFile | null;
    if (file) {
      file.view = null;
      this.client.didClose(uri);
    }
  }

  /**
   * Called by the LSP when a file needs to be displayed (e.g. following a definition/reference).
   * Triggers the callback `onDisplayFile` to switch tabs in the Jaspr application,
   * and returns a promise that resolves to the editor view once the file is opened.
   */
  displayFile(uri: string): Promise<EditorView | null> {
    const hasCallback = typeof this.onDisplayFile === "function";
    let promise: Promise<any> = Promise.resolve();
    if (hasCallback) {
      const res = this.onDisplayFile!(uri);
      if (res && typeof res.then === "function") {
        promise = res;
      }
    }

    const file = this.getFile(uri);
    if (file && file.getView()) {
      return promise.then(() => file.getView());
    }

    if (!hasCallback) {
      return Promise.resolve(null);
    }

    return new Promise((resolve) => {
      if (!this.pendingDisplayFiles[uri]) {
        this.pendingDisplayFiles[uri] = [];
      }
      this.pendingDisplayFiles[uri].push((view) => {
        promise.then(() => resolve(view));
      });
    });
  }
}

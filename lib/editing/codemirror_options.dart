const codeMirrorOptions = {
  'continueComments': {'continueLineComment': false},
  'autofocus': false,
  'autoCloseTags': {
    'whenOpening':true,
    'whenClosing':true,
    'indentTags': [] // Android Studio/VSCode do not auto indent/add newlines for any completed tags
        //  The default (below) would be the following tags cause indenting and blank line inserted
        // ['applet', 'blockquote', 'body', 'button', 'div', 'dl', 'fieldset',
        //    'form', 'frameset', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'head', 
        //    'html', 'iframe', 'layer', 'legend', 'object', 'ol', 'p', 'select', \
        //    'table', 'ul']
  },
  'autoCloseBrackets': true,
  'matchBrackets': true,
  'tabSize': 2,
  'lineWrapping': false,
  'indentUnit': 2,
  'cursorHeight': 0.85,
  'viewportMargin': 100,
  'extraKeys': {
    'Cmd-/': 'toggleComment',
    'Ctrl-/': 'toggleComment',
    'Tab': 'insertSoftTab'
  },
  'hintOptions': {'completeSingle': false},
  'scrollbarStyle': 'simple',
};

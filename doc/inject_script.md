# DartPad's inject_embed script

## Usage

### Step 1: Include the script
Include `https://dartpad.dev/experimental/inject_embed.dart.js` into your page:

```html
<script type="text/javascript" src="https://dartpad.dev/experimental/inject_embed.dart.js"></script>
```

Alternatively, if you are using Jekyll, use the `js:` field at the top of the
article:

```
title: "Codelab: using DartPad"
js: [{defer: true, url: https://dartpad.dev/experimental/inject_embed.dart.js}]
```

### Step 2: Add a code snippet

In Markdown:

````
```run-dartpad:theme-light:mode-flutter
main() => print("Hello, World!");
```
````

In HTML, use `<pre>` and `<code>` tags:

```
<pre>
    <code class="language-run-dartpad:theme-light:mode-flutter">
        main() => print("Hello, World!");
    </code>
</pre>
```

## Options

The Markdown [info string][] must be `run-dartpad` followed by options separated
by `:`. The following options are supported:

Theme options:
- `theme-light` (default)
- `theme-dark`

Mode options:
- `mode-dart` (default)
- `mode-flutter`
- `mode-html`
- `mode-inline`

## Example

An example is provided in `web/experimental/new_embeddings_with_code_tags.html`
and can be viewed [here][embeddings demo].

## Motivation

DartPad typically uses GitHub Gists to display code snippets. For
example, to add DartPad to a page, you can add an `iframe` with
the URL to DartPad:

```
<iframe src="https://dartpad.dev/experimental/embed-new-flutter.html?id=<GIST_ID>"></iframe>
```

Storing code in Gists is not always desirable:

- Gist changes happen in a different repository with a different commit history.
- Gists only have one owner, and can't take advantage of collaboration features
of a repo
- In an article or codelab, gists are opaque to the writer and more difficult to
edit than inline snippets
  
[info string]: https://spec.commonmark.org/0.29/#info-string
[embeddings demo]: https://dartpad.dev/experimental/new_embeddings_with_code_tags.html

[![Build status](https://travis-ci.org/PolymerElements/iron-pages.svg?branch=master)](https://travis-ci.org/PolymerElements/iron-pages)
[![Published on webcomponents.org](https://img.shields.io/badge/webcomponents.org-published-blue.svg)](https://www.webcomponents.org/element/PolymerElements/iron-pages)

_[Demo and API docs](https://elements.polymer-project.org/elements/iron-pages)_


## &lt;iron-pages&gt;

`iron-pages` is used to select one of its children to show. One use is to cycle through a list of
children "pages".

Example:

```html
<iron-pages selected="0">
  <div>One</div>
  <div>Two</div>
  <div>Three</div>
</iron-pages>

<script>
  document.addEventListener('click', function(e) {
    var pages = document.querySelector('iron-pages');
    pages.selectNext();
  });
</script>
```

### Notable breaking changes between 1.x and 2.x (hybrid):

IronSelectableBehavior and IronMultiSelectableBehavior, which are used by
iron-pages, introduce multiple breaking changes. Please see the README for those
behaviors for more detail.

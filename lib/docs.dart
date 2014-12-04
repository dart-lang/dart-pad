
import 'dart:html';

// TODO: inject some css?

void init() {
  List<Element> elements = querySelectorAll('[executable]');

  List<DartSnippet> snippets = elements.map((e) => new DartSnippet(e)).toList();

  print('Found ${elements.length} matching executable doc comments.');
}

// insert a run button
// have it show on hover
// on a mouse click in the text area
//   realize as codemirror
//   make the button stick
// on run button click click,
//   display the output area, move the button
//   compile and execute the sample
// on focus lost, hide the putput area?

class DartSnippet {
  final Element element;

  DartSnippet(this.element) {
    // TODO:

    element.attributes['foo'] = 'bar';
  }
}

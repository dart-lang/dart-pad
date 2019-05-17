import 'dart:html';

import 'package:html_unescape/html_unescape.dart';

void main() {
  var hosts = querySelectorAll('.dartpad-embed');
  for (var host in hosts) {
    _injectEmbed(host);
  }
}

void _injectEmbed(DivElement host) {
  if (host.children.length != 1) {
    return;
  }

  var preElement = host.children.first;
  if (preElement.children.length != 1) {
    return;
  }

  var codeElement = preElement.children.first;
  var code = HtmlUnescape().convert(codeElement.innerHtml);
  if (code.isEmpty) {
    return;
  }
  InjectedEmbed(host, code);
}

class InjectedEmbed {
  final DivElement host;
  final String code;

  InjectedEmbed(this.host, this.code) {
    _init();
  }

  Future _init() async {
    host.children.clear();
    var iframe = IFrameElement()..setAttribute('src', 'embed-new.html?fw=true');
    var m = {'sourceCode': code, 'type': 'sourceCode'};
    host.children.add(iframe);
    await Future.delayed(Duration(milliseconds: 2000));
    iframe.contentWindow.postMessage(m, '*');
  }
}

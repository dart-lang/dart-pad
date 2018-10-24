library example;

import 'dart:html';

import 'package:logging/logging.dart';
import 'package:route_hierarchical/client.dart';

main() {
  Logger('')
    ..level = Level.FINEST
    ..onRecord.listen((r) => print('[${r.level}] ${r.message}'));

  querySelector('#warning').remove();

  var router = Router(useFragment: true);

  router.root
    ..addRoute(name: 'one', defaultRoute: true, path: '/one', enter: showOne)
    ..addRoute(name: 'two', path: '/two', enter: showTwo);

  querySelector('#linkOne').attributes['href'] = router.url('one');
  querySelector('#linkTwo').attributes['href'] = router.url('two');

  router.listen();
}

void showOne(RouteEvent e) {
  print("showOne");
  querySelector('#one').classes.add('selected');
  querySelector('#two').classes.remove('selected');
}

void showTwo(RouteEvent e) {
  print("showTwo");
  querySelector('#one').classes.remove('selected');
  querySelector('#two').classes.add('selected');
}

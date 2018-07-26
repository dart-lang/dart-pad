# Add CORS Headers Middleware

A Shelf middleware to add CORS headers to shelf responses. Also handles
preflight requests.

## Usage

A simple usage example:

```dart
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors/shelf_cors.dart' as shelf_cors;

shelf.Response handleAll(shelf.Request request) {
  return new shelf.Response.ok("OK");
}

var handler = const shelf.Pipeline()
    .addMiddleware(shelf_cors.createCorsHeadersMiddleware())
    .addHandler(handleAll);

shelf_io.serve(handler, InternetAddress.ANY_IP_V4, port).then((server) {
  print("Serving at http://${server.address.host}:${server.port}");
});
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker](https://github.com/gmosx/dart-shelf_cors/issues).

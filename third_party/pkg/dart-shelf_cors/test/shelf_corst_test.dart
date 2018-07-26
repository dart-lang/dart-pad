library flare.html_optimizer.test;

import 'package:unittest/unittest.dart';
import 'package:shelf/shelf.dart' as shelf;

import 'package:shelf_cors/shelf_cors.dart' as shelf_cors;

main() {
  shelf.Response handleAll(shelf.Request request) {
    return new shelf.Response.ok("OK");
  }

  final request =
      new shelf.Request('GET', Uri.parse('http://example.com/index.html'));

  group("The corsHeaders middleware", () {
    test("adds default CORS headers to the response", () async {
      final middleware = shelf_cors.createCorsHeadersMiddleware();
      final handler = middleware(handleAll);
      final response = await handler(request);

      expect(response.headers['Access-Control-Allow-Origin'], equals("*"));
    });

    test("adds custom CORS headers to the response", () async {
      final corsHeaders = {
        'Access-Control-Allow-Origin': "*",
        'Access-Control-Allow-Methods': "POST, OPTIONS",
        'Access-Control-Allow-Headers':
            "Origin, X-Requested-With, Content-Type, Accept"
      };
      final middleware =
          shelf_cors.createCorsHeadersMiddleware(corsHeaders: corsHeaders);
      final handler = middleware(handleAll);
      final response = await handler(request);

      expect(response.headers['Access-Control-Allow-Origin'], equals("*"));
      expect(response.headers['Access-Control-Allow-Methods'],
          equals("POST, OPTIONS"));
      expect(response.headers['Access-Control-Allow-Headers'],
          equals("Origin, X-Requested-With, Content-Type, Accept"));
    });
  });
}

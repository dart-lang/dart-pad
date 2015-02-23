import 'dart:io' as io;
import 'package:http/http.dart' as http;
import 'dart:async';

const POST_PAYLOAD =
r'''{"source":"void main() {\n  for (int i = 0; i < 4; i++) {\n    print('hello ${i}');\n }\n}\n''';
const EPILOGUE = '\n"}';

const URI = "http://rpc-test.dart-services.appspot.com/api/dartservices/v1/analyze";

int count = 0;

void main(List<String> args) {

  if (args.length == 1) {
    int qps = int.parse(args[0]);
  } else {
    int qps = 1;
  }

  print ("QPS: $qps");

  int ms =  (1000/qps).floor();
  Timer t = new Timer.periodic(new Duration(milliseconds: ms),
     (t) { pingServer(t); });
}

pingServer(Timer t) {
  count++;

  if (count > 25000) {
    t.cancel();
  }

  Stopwatch sw = new Stopwatch()..start();

  int time = new DateTime.now().millisecondsSinceEpoch;
    http.post(Uri.parse(URI),
         body : '$POST_PAYLOAD //$time $EPILOGUE').then((response) {
      print (sw.elapsedMilliseconds);
    });
}
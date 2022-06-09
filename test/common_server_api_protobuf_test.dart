// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server_api_protobuf_test;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/common_server_api.dart';
import 'package:dart_services/src/common_server_impl.dart';
import 'package:dart_services/src/protos/dart_services.pb.dart' as proto;
import 'package:dart_services/src/sdk.dart';
import 'package:dart_services/src/server_cache.dart';
import 'package:logging/logging.dart';
import 'package:protobuf/protobuf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

const preFormattedCode = r'''
void main()
{
int i = 0;
}
''';

const postFormattedCode = r'''
void main() {
  int i = 0;
}
''';

const formatBadCode = r'''
void main()
{
  print('foo')
}
''';

void main() => defineTests();

void defineTests() {
  late CommonServerApi commonServerApi;
  late CommonServerImpl commonServerImpl;

  Future<MockHttpResponse> sendPostRequest(
    String path,
    GeneratedMessage? message,
  ) async {
    final uri = Uri.parse('/api/$path');
    final request = MockHttpRequest('POST', uri);
    request.headers.add('content-type', jsonContentType);
    if (message != null) {
      request.add(utf8.encode(json.encode(message.toProto3Json())));
    }
    await request.close();
    await shelf_io.handleRequest(request, commonServerApi.router);
    return request.response;
  }

  Future<MockHttpResponse> sendGetRequest(
    String path,
  ) async {
    final uri = Uri.parse('/api/$path');
    final request = MockHttpRequest('GET', uri);
    request.headers.add('content-type', jsonContentType);
    await request.close();
    await shelf_io.handleRequest(request, commonServerApi.router);
    return request.response;
  }

  group('CommonServerProto JSON', () {
    setUpAll(() async {
      final container = MockContainer();
      final cache = MockCache();
      final channel = Platform.environment['FLUTTER_CHANNEL'] ?? stableChannel;
      final sdk = Sdk.create(channel);
      commonServerImpl = CommonServerImpl(container, cache, sdk);
      commonServerApi = CommonServerApi(commonServerImpl);
      await commonServerImpl.init();

      // Some piece of initialization doesn't always happen fast enough for this
      // request to work in time for the test. So try it here until the server
      // returns something valid.
      // TODO(jcollins-g): determine which piece of initialization isn't
      // happening and deal with that in warmup/init.
      {
        var decodedJson = <dynamic, dynamic>{};
        final jsonData = proto.SourceRequest()..source = sampleCodeError;
        while (decodedJson.isEmpty) {
          final response =
              await sendPostRequest('dartservices/v2/analyze', jsonData);
          expect(response.statusCode, 200);
          expect(response.headers['content-type'],
              ['application/json; charset=utf-8']);
          final data = await response.transform(utf8.decoder).join();
          decodedJson = json.decode(data) as Map<dynamic, dynamic>;
        }
      }
    });

    tearDownAll(() async {
      await commonServerImpl.shutdown();
    });

    setUp(() {
      log.onRecord.listen((LogRecord rec) {
        print('${rec.level.name}: ${rec.time}: ${rec.message}');
      });
    });

    tearDown(log.clearListeners);

    test('analyze Dart', () async {
      final request = proto.SourceRequest()..source = sampleCode;
      final response =
          await sendPostRequest('dartservices/v2/analyze', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.AnalysisResults()..mergeFromProto3Json(data);
      expect(reply.issues, isEmpty);
      expect(reply.packageImports, isEmpty);
    });

    test('analyze Flutter', () async {
      final request = proto.SourceRequest()..source = sampleCodeFlutter;
      final response =
          await sendPostRequest('dartservices/v2/analyze', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.AnalysisResults()..mergeFromProto3Json(data);
      expect(reply.issues, isEmpty);
      expect(reply.packageImports, ['flutter']);
    });

    test('analyze errors', () async {
      final request = proto.SourceRequest()..source = sampleCodeError;
      late proto.AnalysisResults reply;
      final response =
          await sendPostRequest('dartservices/v2/analyze', request);
      expect(response.statusCode, 200);
      expect(response.headers['content-type'],
          ['application/json; charset=utf-8']);
      final data = json.decode(await response.transform(utf8.decoder).join());
      reply = proto.AnalysisResults()..mergeFromProto3Json(data);
      expect(reply.issues, hasLength(1));
      expect(reply.issues[0].kind, 'error');
      expect(reply.issues[0].line, 2);
      expect(reply.issues[0].sourceName, 'main.dart');
      expect(reply.issues[0].message, "Expected to find ';'.");
      expect(reply.issues[0].hasFixes, true);
      expect(reply.issues[0].charStart, 29);
      expect(reply.issues[0].charLength, 1);
    });

    test('analyze negative-test noSource', () async {
      final request = proto.SourceRequest();
      final response =
          await sendPostRequest('dartservices/v2/analyze', request);
      expect(response.statusCode, 400);
    });

    test('compile', () async {
      final request = proto.CompileRequest()..source = sampleCode;
      final response =
          await sendPostRequest('dartservices/v2/compile', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.CompileResponse()..mergeFromProto3Json(data);
      expect(reply.result, isNotEmpty);
    });

    test('compile error', () async {
      final request = proto.CompileRequest()..source = sampleCodeError;
      final response =
          await sendPostRequest('dartservices/v2/compile', request);
      expect(response.statusCode, 400);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.CompileResponse()..mergeFromProto3Json(data);
      expect(reply.error.message, contains('Error: Expected'));
    });

    test('compile negative-test noSource', () async {
      final request = proto.CompileRequest();
      final response =
          await sendPostRequest('dartservices/v2/compile', request);
      expect(response.statusCode, 400);
    });

    test('compileDDC', () async {
      final request = proto.CompileRequest()..source = sampleCode;
      final response =
          await sendPostRequest('dartservices/v2/compileDDC', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.CompileDDCResponse()..mergeFromProto3Json(data);
      expect(reply.result, isNotEmpty);
    });

    test('complete', () async {
      final request = proto.SourceRequest()
        ..source = 'void main() {print("foo");}'
        ..offset = 1;
      final response =
          await sendPostRequest('dartservices/v2/complete', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.CompleteResponse()..mergeFromProto3Json(data);
      expect(reply.completions, isNotEmpty);
    });

    test('complete no data', () async {
      final request = await sendPostRequest(
          'dartservices/v2/complete', proto.SourceRequest());
      expect(request.statusCode, 400);
    });

    test('complete param missing', () async {
      final request = proto.SourceRequest()..offset = 1;
      final response =
          await sendPostRequest('dartservices/v2/complete', request);
      expect(response.statusCode, 400);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.CompleteResponse()..mergeFromProto3Json(data);
      expect(reply.error.message, 'Missing parameter: \'source\'');
    });

    test('complete param missing 2', () async {
      final request = proto.SourceRequest()
        ..source = 'void main() {print("foo");}';
      final response =
          await sendPostRequest('dartservices/v2/complete', request);
      expect(response.statusCode, 400);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.CompleteResponse()..mergeFromProto3Json(data);
      expect(reply.error.message, 'Missing parameter: \'offset\'');
    });

    test('document', () async {
      final request = proto.SourceRequest()
        ..source = 'void main() {print("foo");}'
        ..offset = 17;
      final response =
          await sendPostRequest('dartservices/v2/document', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.DocumentResponse()..mergeFromProto3Json(data);
      expect(reply.info, isNotEmpty);
    });

    test('document little data', () async {
      final request = proto.SourceRequest()
        ..source = 'void main() {print("foo");}'
        ..offset = 2;
      final response =
          await sendPostRequest('dartservices/v2/document', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.DocumentResponse()..mergeFromProto3Json(data);
      expect(reply.info, isEmpty);
    });

    test('document no data', () async {
      final request = proto.SourceRequest()
        ..source = 'void main() {print("foo");}'
        ..offset = 12;
      final response =
          await sendPostRequest('dartservices/v2/document', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.DocumentResponse()..mergeFromProto3Json(data);
      expect(reply.info, isEmpty);
    });

    test('document negative-test noSource', () async {
      final request = proto.SourceRequest()..offset = 12;
      final response =
          await sendPostRequest('dartservices/v2/document', request);
      expect(response.statusCode, 400);
    });

    test('document negative-test noOffset', () async {
      final request = proto.SourceRequest()
        ..source = 'void main() {print("foo");}';
      final response =
          await sendPostRequest('dartservices/v2/document', request);
      expect(response.statusCode, 400);
    });

    test('format', () async {
      final request = proto.SourceRequest()..source = preFormattedCode;
      final response = await sendPostRequest('dartservices/v2/format', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.FormatResponse()..mergeFromProto3Json(data);
      expect(reply.newString, postFormattedCode);
    });

    test('format bad code', () async {
      final request = proto.SourceRequest()..source = formatBadCode;
      final response = await sendPostRequest('dartservices/v2/format', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.FormatResponse()..mergeFromProto3Json(data);
      expect(reply.newString, formatBadCode);
    });

    test('format position', () async {
      final request = proto.SourceRequest()
        ..source = preFormattedCode
        ..offset = 21;
      final response = await sendPostRequest('dartservices/v2/format', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.FormatResponse()..mergeFromProto3Json(data);
      expect(reply.newString, postFormattedCode);
      expect(reply.offset, 24);
    });

    test('fix', () async {
      final quickFixesCode = '''
import 'dart:async';
void main() {
  int i = 0;
}
''';
      final request = proto.SourceRequest()
        ..source = quickFixesCode
        ..offset = 10;
      final response = await sendPostRequest('dartservices/v2/fixes', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.FixesResponse()..mergeFromProto3Json(data);
      final fixes = reply.fixes;
      expect(fixes.length, 1);
      final problemAndFix = fixes[0];
      expect(problemAndFix.problemMessage, isNotNull);
    });

    test('fixes completeness', () async {
      final request = proto.SourceRequest()
        ..source = '''
void main() {
  for (int i = 0; i < 4; i++) {
    print('hello \$i')
  }
}
'''
        ..offset = 67;
      final response = await sendPostRequest('dartservices/v2/fixes', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.FixesResponse()..mergeFromProto3Json(data);
      expect(reply.fixes[0].fixes[0].message, "Insert ';'");
      expect(reply.fixes[0].fixes[0].edits[0].offset, 67);
      expect(reply.fixes[0].fixes[0].edits[0].length, 0);
      expect(reply.fixes[0].fixes[0].edits[0].replacement, ';');
      expect(reply.fixes[0].problemMessage, "Expected to find ';'.");
      expect(reply.fixes[0].offset, 66);
      expect(reply.fixes[0].length, 1);
    });

    test('assist', () async {
      final assistCode = '''
main() {
  int v = 0;
}
''';
      final request = proto.SourceRequest()
        ..source = assistCode
        ..offset = 15;
      final response =
          await sendPostRequest('dartservices/v2/assists', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.AssistsResponse()..mergeFromProto3Json(data);
      final assists = reply.assists;
      expect(assists, hasLength(2));
      expect(assists.first.edits, isNotNull);
      expect(assists.first.edits, hasLength(1));
      expect(
          assists.where((candidateFix) =>
              candidateFix.message == 'Remove type annotation'),
          isNotEmpty);
    });

    test('version', () async {
      final response = await sendPostRequest('dartservices/v2/version', null);
      expect(response.statusCode, 200);
      final encoded = await response.transform(utf8.decoder).join();
      final data = json.decode(encoded) as Map<String, dynamic>;
      expect(data['sdkVersion'], isNotNull);
      expect(data['runtimeVersion'], isNotNull);
    });

    test('version', () async {
      final response = await sendGetRequest('dartservices/v2/version');
      expect(response.statusCode, 200);
      final encoded = await response.transform(utf8.decoder).join();
      final data = json.decode(encoded) as Map<String, dynamic>;
      expect(data['sdkVersion'], isNotNull);
      expect(data['runtimeVersion'], isNotNull);
    });
  });

  //-----------------------------------------------------------------
  // Beginning of multi file files={} group tests:
  group('CommonServerProto JSON Multi File Group files={}', () {
    setUpAll(() async {
      final container = MockContainer();
      final cache = MockCache();
      final channel = Platform.environment['FLUTTER_CHANNEL'] ?? stableChannel;
      final sdk = Sdk.create(channel);
      commonServerImpl = CommonServerImpl(container, cache, sdk);
      commonServerApi = CommonServerApi(commonServerImpl);
      await commonServerImpl.init();

      // Some piece of initialization doesn't always happen fast enough for this
      // request to work in time for the test. So try it here until the server
      // returns something valid.
      // TODO(jcollins-g): determine which piece of initialization isn't
      // happening and deal with that in warmup/init.
      {
        var decodedJson = <dynamic, dynamic>{};
        final jsonData = proto.SourceRequest()..source = sampleCodeError;
        while (decodedJson.isEmpty) {
          final response =
              await sendPostRequest('dartservices/v2/analyze', jsonData);
          expect(response.statusCode, 200);
          expect(response.headers['content-type'],
              ['application/json; charset=utf-8']);
          final data = await response.transform(utf8.decoder).join();
          decodedJson = json.decode(data) as Map<dynamic, dynamic>;
        }
      }
    });

    tearDownAll(() async {
      await commonServerImpl.shutdown();
    });

    setUp(() {
      log.onRecord.listen((LogRecord rec) {
        print('${rec.level.name}: ${rec.time}: ${rec.message}');
      });
    });

    tearDown(log.clearListeners);

    test('analyzeFiles Dart files={}', () async {
      final request = proto.SourceFilesRequest(files: {kMainDart: sampleCode});
      final response =
          await sendPostRequest('dartservices/v2/analyzeFiles', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.AnalysisResults()..mergeFromProto3Json(data);
      expect(reply.issues, isEmpty);
      expect(reply.packageImports, isEmpty);
    });

    test('analyzeFiles Flutter files={}', () async {
      final request =
          proto.SourceFilesRequest(files: {kMainDart: sampleCodeFlutter});
      final response =
          await sendPostRequest('dartservices/v2/analyzeFiles', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.AnalysisResults()..mergeFromProto3Json(data);
      expect(reply.issues, isEmpty);
      expect(reply.packageImports, ['flutter']);
    });

    test('analyzeFiles errors files={}', () async {
      final request =
          proto.SourceFilesRequest(files: {kMainDart: sampleCodeError});
      late proto.AnalysisResults reply;
      final response =
          await sendPostRequest('dartservices/v2/analyzeFiles', request);
      expect(response.statusCode, 200);
      expect(response.headers['content-type'],
          ['application/json; charset=utf-8']);
      final data = json.decode(await response.transform(utf8.decoder).join());
      reply = proto.AnalysisResults()..mergeFromProto3Json(data);
      expect(reply.issues, hasLength(1));
      expect(reply.issues[0].kind, 'error');
      expect(reply.issues[0].line, 2);
      expect(reply.issues[0].sourceName, 'main.dart');
      expect(reply.issues[0].message, "Expected to find ';'.");
      expect(reply.issues[0].hasFixes, true);
      expect(reply.issues[0].charStart, 29);
      expect(reply.issues[0].charLength, 1);
    });

    test('analyzeFiles negative-test noSource files={}', () async {
      final request = proto.SourceFilesRequest();
      final response =
          await sendPostRequest('dartservices/v2/analyzeFiles', request);
      expect(response.statusCode, 400);
    });

    test('compileFiles files={}', () async {
      final request = proto.CompileFilesRequest(files: {kMainDart: sampleCode});
      final response =
          await sendPostRequest('dartservices/v2/compileFiles', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.CompileResponse()..mergeFromProto3Json(data);
      expect(reply.result, isNotEmpty);
    });

    test('compileFiles 2 simple import files set in files={}', () async {
      final request = proto.CompileFilesRequest(files: {
        kMainDart: sampleCodeMultiFoo,
        'bar.dart': sampleCodeMultiBar,
      }, returnSourceMap: false);
      final response =
          await sendPostRequest('dartservices/v2/compileFiles', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.CompileResponse()..mergeFromProto3Json(data);
      expect(reply.result, isNotEmpty);
    });

    test('compileFiles error files={}', () async {
      final request =
          proto.CompileFilesRequest(files: {kMainDart: sampleCodeError});
      final response =
          await sendPostRequest('dartservices/v2/compileFiles', request);
      expect(response.statusCode, 400);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.CompileResponse()..mergeFromProto3Json(data);
      expect(reply.error.message, contains('Error: Expected'));
    });

    test('compileFiles negative-test noSource files={}', () async {
      final request = proto.CompileFilesRequest();
      final response =
          await sendPostRequest('dartservices/v2/compileFiles', request);
      expect(response.statusCode, 400);
    });

    test('compileFilesDDC mymain.dart files={}', () async {
      final request =
          proto.CompileFilesDDCRequest(files: {'mymain.dart': sampleCode});
      final response =
          await sendPostRequest('dartservices/v2/compileFilesDDC', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.CompileDDCResponse()..mergeFromProto3Json(data);
      expect(reply.result, isNotEmpty);
    });

    test('compileFilesDDC 3 files set in files={}', () async {
      final request = proto.CompileFilesDDCRequest(files: {
        kMainDart: sampleCode3PartLibraryMain,
        'discdata.dart': sampleCode3PartDiscDataPartOfTestAnim,
        'various.dart': sampleCode3PartVariousPartOfTestAnim
      });
      final response =
          await sendPostRequest('dartservices/v2/compileFilesDDC', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.CompileDDCResponse()..mergeFromProto3Json(data);
      expect(reply.result, isNotEmpty);
    });

    test('completeFiles files={}', () async {
      final request = proto.SourceFilesRequest(
          files: {kMainDart: 'void main() {print("foo");}'},
          activeSourceName: kMainDart,
          offset: 1);
      final response =
          await sendPostRequest('dartservices/v2/completeFiles', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.CompleteResponse()..mergeFromProto3Json(data);
      expect(reply.completions, isNotEmpty);
    });

    test('completeFiles no data files={}', () async {
      final request = await sendPostRequest(
          'dartservices/v2/completeFiles', proto.SourceFilesRequest());
      expect(request.statusCode, 400);
    });

    test('completeFiles param missing files={}', () async {
      final request = proto.SourceFilesRequest(offset: 1);
      final response =
          await sendPostRequest('dartservices/v2/completeFiles', request);
      expect(response.statusCode, 400);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.CompleteResponse()..mergeFromProto3Json(data);
      expect(reply.error.message, 'Missing parameter: \'files\'');
    });

    test('completeFiles param missing 2 files={}', () async {
      final request = proto.SourceFilesRequest(
          files: {kMainDart: 'void main() {print("foo");}'});
      final response =
          await sendPostRequest('dartservices/v2/completeFiles', request);
      expect(response.statusCode, 400);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.CompleteResponse()..mergeFromProto3Json(data);
      expect(reply.error.message, 'Missing parameter: \'activeSourceName\'');
    });

    test('documentFiles files={}', () async {
      final request = proto.SourceFilesRequest(
          files: {kMainDart: 'void main() {print("foo");}'},
          activeSourceName: kMainDart,
          offset: 17);
      final response =
          await sendPostRequest('dartservices/v2/documentFiles', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.DocumentResponse()..mergeFromProto3Json(data);
      expect(reply.info, isNotEmpty);
    });

    test('documentFiles little data files={}', () async {
      final request = proto.SourceFilesRequest(
          files: {kMainDart: 'void main() {print("foo");}'},
          activeSourceName: kMainDart,
          offset: 2);
      final response =
          await sendPostRequest('dartservices/v2/documentFiles', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.DocumentResponse()..mergeFromProto3Json(data);
      expect(reply.info, isEmpty);
    });

    test('documentFiles no data files={}', () async {
      final request = proto.SourceFilesRequest(
          files: {kMainDart: 'void main() {print("foo");}'},
          activeSourceName: kMainDart,
          offset: 12);
      final response =
          await sendPostRequest('dartservices/v2/documentFiles', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.DocumentResponse()..mergeFromProto3Json(data);
      expect(reply.info, isEmpty);
    });

    test('documentFiles negative-test noSource files={}', () async {
      final request = proto.SourceFilesRequest(offset: 12);
      final response =
          await sendPostRequest('dartservices/v2/documentFiles', request);
      expect(response.statusCode, 400);
    });

    test('documentFiles negative-test noActiveSource noOffset files={}',
        () async {
      final request = proto.SourceFilesRequest(
          files: {kMainDart: 'void main() {print("foo");}'});
      final response =
          await sendPostRequest('dartservices/v2/documentFiles', request);
      expect(response.statusCode, 400);
    });

    test('fix2 files={}', () async {
      final quickFixesCode = '''
import 'dart:async';
void main() {
  int i = 0;
}
''';
      final request = proto.SourceFilesRequest(
          files: {kMainDart: quickFixesCode},
          activeSourceName: kMainDart,
          offset: 10);
      final response =
          await sendPostRequest('dartservices/v2/fixesFiles', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.FixesResponse()..mergeFromProto3Json(data);
      final fixes = reply.fixes;
      expect(fixes.length, 1);
      final problemAndFix = fixes[0];
      expect(problemAndFix.problemMessage, isNotNull);
    });

    test('fixesFiles completeness files={}', () async {
      final request = proto.SourceFilesRequest(files: {
        kMainDart: '''
void main() {
  for (int i = 0; i < 4; i++) {
    print('hello \$i')
  }
}
'''
      }, activeSourceName: kMainDart, offset: 67);
      final response =
          await sendPostRequest('dartservices/v2/fixesFiles', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.FixesResponse()..mergeFromProto3Json(data);
      expect(reply.fixes[0].fixes[0].message, "Insert ';'");
      expect(reply.fixes[0].fixes[0].edits[0].offset, 67);
      expect(reply.fixes[0].fixes[0].edits[0].length, 0);
      expect(reply.fixes[0].fixes[0].edits[0].replacement, ';');
      expect(reply.fixes[0].problemMessage, "Expected to find ';'.");
      expect(reply.fixes[0].offset, 66);
      expect(reply.fixes[0].length, 1);
    });

    test('assist2 files={}', () async {
      final assistCode = '''
main() {
  int v = 0;
}
''';
      final request = proto.SourceFilesRequest(
          files: {kMainDart: assistCode},
          activeSourceName: kMainDart,
          offset: 15);
      final response =
          await sendPostRequest('dartservices/v2/assistsFiles', request);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      final reply = proto.AssistsResponse()..mergeFromProto3Json(data);
      final assists = reply.assists;
      expect(assists, hasLength(2));
      expect(assists.first.edits, isNotNull);
      expect(assists.first.edits, hasLength(1));
      expect(
          assists.where((candidateFix) =>
              candidateFix.message == 'Remove type annotation'),
          isNotEmpty);
    });
  });
  // End of multi file files={} tests group.
}

class MockContainer implements ServerContainer {
  @override
  String get version => vmVersion;
}

class MockCache implements ServerCache {
  @override
  Future<String?> get(String key) => Future.value(null);

  @override
  Future<void> set(String key, String value, {Duration? expiration}) =>
      Future.value();

  @override
  Future<void> remove(String key) => Future.value();

  @override
  Future<void> shutdown() => Future.value();
}

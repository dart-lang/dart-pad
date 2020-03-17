// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server;

import 'dart:async';

import 'package:rpc/rpc.dart';

import 'api_classes.dart';
import 'common_server_impl.dart' show BadRequest, CommonServerImpl;
export 'common_server_impl.dart' show log, ServerContainer;

@ApiClass(name: 'dartservices', version: 'v1')
class CommonServer {
  final CommonServerImpl _impl;

  CommonServer(this._impl);

  @ApiMethod(
      method: 'POST',
      path: 'analyze',
      description:
          'Analyze the given Dart source code and return any resulting '
          'analysis errors or warnings.')
  Future<AnalysisResults> analyze(SourceRequest request) =>
      _convertBadRequest(() => _impl.analyze(request));

  @ApiMethod(
      method: 'POST',
      path: 'compile',
      description: 'Compile the given Dart source code and return the '
          'resulting JavaScript; this uses the dart2js compiler.')
  Future<CompileResponse> compile(CompileRequest request) =>
      _convertBadRequest(() => _impl.compile(request));

  @ApiMethod(
      method: 'POST',
      path: 'compileDDC',
      description: 'Compile the given Dart source code and return the '
          'resulting JavaScript; this uses the DDC compiler.')
  Future<CompileDDCResponse> compileDDC(CompileRequest request) =>
      _convertBadRequest(() => _impl.compileDDC(request));

  @ApiMethod(
      method: 'POST',
      path: 'complete',
      description:
          'Get the valid code completion results for the given offset.')
  Future<CompleteResponse> complete(SourceRequest request) =>
      _convertBadRequest(() => _impl.complete(request));

  @ApiMethod(
      method: 'POST',
      path: 'fixes',
      description: 'Get any quick fixes for the given source code location.')
  Future<FixesResponse> fixes(SourceRequest request) =>
      _convertBadRequest(() => _impl.fixes(request));

  @ApiMethod(
      method: 'POST',
      path: 'assists',
      description: 'Get assists for the given source code location.')
  Future<AssistsResponse> assists(SourceRequest request) =>
      _convertBadRequest(() => _impl.assists(request));

  @ApiMethod(
      method: 'POST',
      path: 'format',
      description: 'Format the given Dart source code and return the results. '
          'If an offset is supplied in the request, the new position for that '
          'offset in the formatted code will be returned.')
  Future<FormatResponse> format(SourceRequest request) =>
      _convertBadRequest(() => _impl.format(request));

  @ApiMethod(
      method: 'POST',
      path: 'document',
      description: 'Return the relevant dartdoc information for the element at '
          'the given offset.')
  Future<DocumentResponse> document(SourceRequest request) =>
      _convertBadRequest(() => _impl.document(request));

  @ApiMethod(
      method: 'GET',
      path: 'version',
      description: 'Return the current SDK version for DartServices.')
  Future<VersionResponse> version() =>
      _convertBadRequest(() => _impl.version());
}

Future<T> _convertBadRequest<T>(Future<T> Function() fun) async {
  try {
    return await fun();
  } catch (e) {
    if (e is BadRequest) {
      throw BadRequestError(e.cause);
    }
    throw BadRequestError(e.toString());
  }
}

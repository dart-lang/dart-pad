// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library rpc.errors;

class RpcError implements Exception {
  final int statusCode;
  final String name;
  final String message;
  List<RpcErrorDetail> errors;

  RpcError(this.statusCode, this.name, this.message,
      {List<RpcErrorDetail> errors})
      :
        // Making sure that errors can be added later on.
        this.errors = errors == null ? [] : errors;

  String toString() =>
      'RPC Error with status: $statusCode and message: $message';
}

class NotFoundError extends RpcError {
  NotFoundError([String message = "Not found."])
      : super(404, 'Not Found', message);
}

class BadRequestError extends RpcError {
  BadRequestError([String message = "Bad request."])
      : super(400, 'Bad Request', message);
}

class InternalServerError extends RpcError {
  InternalServerError([String message = "Internal Server Error."])
      : super(500, 'Internal Server Error', message);
}

class ApplicationError extends RpcError {
  ApplicationError(e) : super(500, 'Application Invocation Error', '${e}');
}

/// Instances of this class can be added to an [RpcError] to provide detailed
/// information.
/// They will be sent back to the client in the `errors` field.
///
/// This follows the Google JSON style guide:
/// http://google-styleguide.googlecode.com/svn/trunk/jsoncstyleguide.xml?showone=error#error.errors
class RpcErrorDetail {
  /// Unique identifier for the service raising this error. This helps
  /// distinguish service-specific errors (i.e. error inserting an event in a
  /// calendar) from general protocol errors (i.e. file not found).
  final String domain;

  /// Unique identifier for this error. Different from the [RpcError.statusCode]
  /// property in that this is not an http response code.
  final String reason;

  /// A human readable message providing more details about the error. If there
  /// is only one error, this field will match error.message.
  final String message;

  /// The location of the error (the interpretation of its value depends on
  /// [locationType]).
  final String location;

  /// Indicates how the [location] property should be interpreted.
  final String locationType;

  /// A URI for a help text that might shed some more light on the error.
  final String extendedHelp;

  /// A URI for a report form used by the service to collect data about the
  /// error condition. This URI should be preloaded with parameters describing
  /// the request.
  final String sendReport;

  RpcErrorDetail(
      {this.domain,
      this.reason,
      this.message,
      this.location,
      this.locationType,
      this.extendedHelp,
      this.sendReport});

  Map<String, String> toJson() {
    var json = <String, String>{};
    if (domain != null) json['domain'] = domain;
    if (reason != null) json['reason'] = reason;
    if (message != null) json['message'] = message;
    if (location != null) json['location'] = location;
    if (locationType != null) json['locationType'] = locationType;
    if (extendedHelp != null) json['extendedHelp'] = extendedHelp;
    if (sendReport != null) json['sendReport'] = sendReport;
    return json;
  }
}

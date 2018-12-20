// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library rpc.annotations;

/// Use as annotation for your main API class.
///
/// [version] is required. [name] will default to the camel-case version
/// of the annotated class name if not specified. The base path of the
/// api will be /api/[name]/[version].
class ApiClass {
  /// API name.
  ///
  /// E.g. 'storage'.
  final String name;

  /// API version.
  final String version;

  /// API title.
  ///
  /// E.g. 'Ajax Storage API'.
  final String title;

  /// API description.
  final String description;

  const ApiClass({this.name, this.version, this.title, this.description});
}

/// Use as annotation for your API resources that should be added to a parent
/// top-level API class.
class ApiResource {
  /// Name of the resource.
  ///
  /// Defaults to the camel-case version of the class name if not specified.
  final String name;

  const ApiResource({this.name});
}

/// Use as annotation for your API methods inside of the API class.
class ApiMethod {
  /// Name of the method.
  ///
  /// Defaults to the camel-case version of the class name if not.
  final String name;

  /// Path used to route a message to the method.
  ///
  /// It is a required field.
  ///
  /// The path can contain path parameters like `{id}` which have to be part
  /// of the request message class specified in the method parameters.
  final String path;

  /// HTTP method used to call this API method.
  ///
  /// Can be `GET`, `POST`, `PUT`, `PATCH`, `DELETE`.
  /// Defaults to `GET`.
  final String method;

  /// Description of the method.
  final String description;

  const ApiMethod({this.name, this.path, this.method: 'GET', this.description});
}

/// Optional annotation for parameters inside of API request/response messages.
class ApiProperty {
  /// Optional name to use when serializing and deserializing the property.
  final String name;

  /// description of the property to be included in the discovery document.
  final String description;

  /// Specifies the representation of int and double properties in the backend.
  ///
  /// Possible values for int: 'int32' (default), 'uint32', 'int64', 'uint64'.
  /// The 64 bit values will be represented as String in the JSON
  /// requests/responses.
  ///
  /// Possible values for double: 'double' (default), 'float'.
  final String format;

  /// Whether the property is required.
  ///
  /// A request without a required property will fail with BadRequestError.
  /// The generated discovery document will include the required field to
  /// allow client stub generators to validate the request or response as
  /// required.
  final bool required;

  /// Whether the property should be ignored.
  ///
  /// For a request this means the field is left uninitialized. For a response
  /// the field is left out of the response if true.
  final bool ignore;

  /// Default value for this property if it's not supplied.
  final dynamic defaultValue;

  /// For int properties: the minimal value.  Must be int or String (if format == 'uint64' or 'int64')
  final dynamic minValue;

  /// For int properties: the maximal value.  Must be int or String (if format == 'uint64' or 'int64')
  final dynamic maxValue;

  /// Possible values for enum properties, as value - description pairs.
  ///  Properties using this will have to be String.
  final Map<String, String> values;

  const ApiProperty(
      {this.name,
      this.description,
      this.format,
      this.required: false,
      this.ignore: false,
      this.defaultValue,
      this.minValue,
      this.maxValue,
      this.values});
}

/// Optional annotation for API request/response messages.
class ApiMessage {
  final bool includeSuper;

  const ApiMessage({this.includeSuper: false});
}

/// Special API Message to use when a method doesn't need a request or doesn't
/// return a response.
class VoidMessage {}

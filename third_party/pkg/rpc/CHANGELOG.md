## 0.6.0

- Support latest `package:gcloud`.
- Many internal changes for Dart 2.0.  This version will no longer run on Dart 1.x.
- ApiProperty declarations for 64 bit integers now require BigInt type, and clients must use
  Strings for minValue, maxValue, and defaultValue.

## 0.5.10

- Widen constraints on `package:gcloud` dependency.
- Widen constraints on `package:_discoveryapis_generator` dependency.

## 0.5.9

- Fix issue with DoubleProperty.

## 0.5.8

- Rfc7232 specs restrictions on 204, 304 statuses (#106)
- Update generator to work with ".packages" files.
- Widen several dependency constraints.

## 0.5.7+1

- Widen `package:gcloud` constraint in pubspec.yaml to include version `0.4.0`.

## 0.5.7

- Support for `ApiMessage` annotation on message classes which allows including
  fields from base class hierarchy.

## 0.5.6+3

- Ensure errors in the spawned isolate will be propagated to the main isolate.

## 0.5.6+2

- Widen dependency constraints for
  convert/crypto/gcloud/http_parser/discoveryapis_generator
- Merged pull-request for decoding percent-encoded parameters

## 0.5.6+1
- Widen dependency constraints, update to crypto 1.0.0

## 0.5.6
- Fix an exception when run in checked mode.

## 0.5.5
- Added support for MediaMessage, full upload/download support for blob data. 

## 0.5.4
- Allow user specific error details in RPC responses.

## 0.5.3
- Fix bug in the rpc generator causing it to fail on Dart 1.12.

## 0.5.2
- Add support for ignored fields in a request/response schema class.

## 0.5.1
- Update pubspec dependencies.
- Move the examples directory into separate github repo, dart-lang/rpc-examples,
  to avoid having example dependencies in the rpc package.
- Fix up broken tests.

## 0.5.0

- Support for setting HTTP response status code and headers.
- Added HTTP request cookies to the invocation context.
- Changed the default HTTP response status code for empty responses to be
  NO_CONTENT.
- Improve error messages in the rpc:generate script.
- A few bugfixes.

## 0.4.3

- Support constructors taking arguments for message classes used only for
  responses (however not when generating client stubs inside existing
  project).
- Make sure we return header values as strings if passed as strings.

## 0.4.2

- Fix bug with handling OPTIONS request from Shelf.

## 0.4.1

- Fix windows path handling in the generate script.

## 0.4.0

- API method context with the request uri and request headers
- Change HttpApiRequest to take the requested URI instead of path and query
  parameters.
- Change RpcError's msg and code fields to message and statusCode
- Added api.dart file for use in common code shared between server and client

## 0.3.0 

- Adding support for generating Discovery Documents without running the server
- Adding support for generating Dart client stub code from the annotated server
  code

## 0.2.0

- Disallow null to be returned from method declaring a non VoidMessage return type
- Fixed bug when encoding min/max for integers in the discovery document
- Restricted the set of ApiProperty fields depending on the type of the property
- Added min/max and type bound checking for integer and double return values
- Fixed bug with DateTime default value
- Improved error messages

## 0.1.0

- Initial version

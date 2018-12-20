// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
///ported from the http_server package
///http://pub.dartlang.org/packages/http_server
library http_body_parser;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'media_message.dart';
import 'config.dart';

import 'package:mime/mime.dart';

/// The body of a HTTP request.
/// [type] can be 'binary', 'text', 'form' and 'json'.
/// [body] can be a List, Map or String.
class PostData {
  final String type;
  final dynamic body;

  PostData(this.type, this.body);
}

BytesBuilder _fillBytesBuilder(BytesBuilder builder, List<int> data) =>
    builder..add(data);
StringBuffer _fillStringBuffer(StringBuffer buffer, String data) =>
    buffer..write(data);

Future<PostData> _asBinary(ParsedHttpApiRequest request) => request.body
    .fold(new BytesBuilder(), _fillBytesBuilder)
    .then((BytesBuilder bld) => new PostData('binary', bld.takeBytes()));

Future<PostData> _asText(ParsedHttpApiRequest request) {
  final String charset = request.contentType.charset;
  final Encoding encoding =
      charset != null ? Encoding.getByName(charset) : utf8;
  return request.body
      .transform(encoding.decoder)
      .fold(new StringBuffer(), _fillStringBuffer)
      .then((StringBuffer buffer) => new PostData('text', buffer.toString()));
}

Future<PostData> _asFormData(ParsedHttpApiRequest request) {
  final ContentType contentType = request.contentType;
  return request.body
      .transform(
          new MimeMultipartTransformer(contentType.parameters['boundary']))
      .map(_HttpMultipartFormData.parse)
      .map((_HttpMultipartFormData multipart) {
        Future future;
        if (multipart.isText) {
          future = (multipart as _HttpMultipartFormData<String>)
              .fold<StringBuffer>(new StringBuffer(), _fillStringBuffer)
              .then((StringBuffer buffer) => buffer.toString());
        } else {
          future = (multipart as _HttpMultipartFormData<List<int>>)
              .fold(new BytesBuilder(), _fillBytesBuilder)
              .then((BytesBuilder builder) => builder.takeBytes());
        }
        return future.then((dynamic data) {
          final String filename =
              multipart.contentDisposition.parameters['filename'];
          if (filename != null) {
            if (multipart.isText) data = (data as String).codeUnits;
            data = new MediaMessage()
              ..contentType = multipart.contentType.value
              ..bytes = data
              ..metadata = {'filename': filename};
          }
          return [multipart.contentDisposition.parameters['name'], data];
        });
      })
      .fold<List<Future>>([],
          (List<Future> futureList, Future future) => futureList..add(future))
      .then(Future.wait)
      .then((List<dynamic> parts) {
        Map<String, dynamic> map = {};
        // Form input file multiple
        for (var part in parts) {
          if (map[part[0]] != null) {
            if (map[part[0]] is List)
              map[part[0]].add(part[1]);
            else
              map[part[0]] = [map[part[0]], part[1]];
          } else
            map[part[0]] = part[1];
        }
        return new PostData('form', map);
      });
}

Future<PostData> parseRequestBody(ParsedHttpApiRequest request) {
  final ContentType contentType = request.contentType;
  if (contentType == null) return _asBinary(request);

  switch (contentType.primaryType) {
    case "text":
      return _asText(request);

    case "application":
      switch (contentType.subType) {
        case "json":
          return _asText(request).then(
              (PostData body) => new PostData('json', jsonDecode(body.body)));

        case "x-www-form-urlencoded":
          return _asText(request).then((PostData body) {
            Map<String, String> map =
                Uri.splitQueryString(body.body, encoding: utf8);
            return new PostData('form', new Map.from(map));
          });

        default:
          break;
      }
      break;

    case "multipart":
      switch (contentType.subType) {
        case "form-data":
          return _asFormData(request);

        default:
          break;
      }
      break;

    default:
      break;
  }
  return _asBinary(request);
}

class _HttpMultipartFormData<T> extends Stream<T> {
  final ContentType contentType;
  final HeaderValue contentDisposition;
  final HeaderValue contentTransferEncoding;
  final MimeMultipart _mimeMultipart;
  bool _isText = false;
  bool get isText => _isText;
  bool get isBinary => !_isText;
  Stream _stream;

  static _HttpMultipartFormData parse(MimeMultipart multipart) {
    ContentType type;
    HeaderValue encoding;
    HeaderValue disposition;
    for (String key in multipart.headers.keys) {
      switch (key) {
        case 'content-type':
          type = ContentType.parse(multipart.headers[key]);
          break;

        case 'content-transfer-encoding':
          encoding = HeaderValue.parse(multipart.headers[key]);
          break;

        case 'content-disposition':
          disposition = HeaderValue.parse(multipart.headers[key],
              preserveBackslash: true);
          break;

        default:
          break;
      }
    }
    if (disposition == null)
      throw new HttpException(
          "Mime Multipart doesn't contain a Content-Disposition header value");
    return new _HttpMultipartFormData(
        type, disposition, encoding, multipart, utf8);
  }

  _HttpMultipartFormData(
      this.contentType,
      this.contentDisposition,
      this.contentTransferEncoding,
      this._mimeMultipart,
      Encoding defaultEncoding) {
    _stream = _mimeMultipart;

    if (contentTransferEncoding != null)
      throw new HttpException("Unsupported contentTransferEncoding: "
          "${contentTransferEncoding.value}");

    if (contentType == null ||
        contentType.primaryType == 'text' ||
        contentType.mimeType == 'application/json') {
      _isText = true;
      final StringBuffer buffer = new StringBuffer();
      final Encoding encoding = contentType != null
          ? Encoding.getByName(contentType.charset) ?? defaultEncoding
          : defaultEncoding;
      _stream = _stream.transform(encoding.decoder).expand((String data) {
        buffer.write(data);
        final String out = _decodeHttpEntityString(buffer.toString());
        if (out != null) {
          buffer.clear();
          return [out];
        }
        return const [];
      });
    }
  }

  StreamSubscription<T> listen(void onData(T data),
          {void onDone(), Function onError, bool cancelOnError}) =>
      _stream.listen(onData,
          onDone: onDone, onError: onError, cancelOnError: cancelOnError);

  String value(String name) => _mimeMultipart.headers[name];

  // Decode a string with HTTP entities. Returns null if the string ends in the
  // middle of a http entity.
  static String _decodeHttpEntityString(String input) {
    int amp = input.lastIndexOf('&');
    if (amp < 0) return input;
    int end = input.lastIndexOf(';');
    if (end < amp) return null;

    StringBuffer buffer = new StringBuffer();
    int offset = 0;

    final Function parse = (amp, end) {
      switch (input[amp + 1]) {
        case '#':
          if (input[amp + 2] == 'x') {
            buffer.writeCharCode(
                int.parse(input.substring(amp + 3, end), radix: 16));
          } else {
            buffer.writeCharCode(int.parse(input.substring(amp + 2, end)));
          }
          break;

        default:
          throw new HttpException('Unhandled HTTP entity token');
      }
    };

    while ((amp = input.indexOf('&', offset)) >= 0) {
      buffer.write(input.substring(offset, amp));
      end = input.indexOf(';', amp);
      parse(amp, end);
      offset = end + 1;
    }
    buffer.write(input.substring(offset));
    return buffer.toString();
  }
}

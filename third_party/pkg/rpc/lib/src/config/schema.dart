// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of rpc.config;

/// [D] is the type used in Dart code.  [J] is the type used in JSON.
abstract class ApiConfigSchema<D, J> {
  final String schemaName;
  final ClassMirror schemaClass;
  final Map<Symbol, ApiConfigSchemaProperty> _properties = {};
  // This bool tells whether the schema is used as a request in which case it
  // must have a zero-argument constructor in order for us to instantiate it
  // using reflection.
  final bool isUsedForRequest;
  bool propertiesInitialized = false;

  ApiConfigSchema(this.schemaName, this.schemaClass, this.isUsedForRequest);

  // Helper to add properties. We use this to be able to create the schema
  // before having parsed its properties to detect cycles. However we don't
  // want to support updating properties in general, hence the assert.
  void initProperties(Map<Symbol, ApiConfigSchemaProperty> properties) {
    assert(_properties.isEmpty);
    _properties.addAll(properties);
    propertiesInitialized = true;
  }

  bool get containsData => !_properties.isEmpty;

  discovery.JsonSchema get asDiscovery {
    var schema = new discovery.JsonSchema();
    schema
      ..id = schemaName
      ..type = 'object'
      ..properties = new Map<String, discovery.JsonSchema>();
    _properties.values.forEach((prop) {
      schema.properties[prop.name] = prop.asDiscovery;
    });
    return schema;
  }

  D fromRequest(J request);
  J toResponse(D result);
}

// TODO(jcollins-g): consider `J extends Map`
class ConfigSchema<D, J> extends ApiConfigSchema<D, J> {
  ConfigSchema(String schemaName, ClassMirror schemaClass, bool isRequest)
      : super(schemaName, schemaClass, isRequest);

  D fromRequest(J request) {
    if (request is Map) {
      InstanceMirror schema = schemaClass.newInstance(new Symbol(''), []);
      for (Symbol sym in _properties.keys) {
        final ApiConfigSchemaProperty prop = _properties[sym];
        try {
          if (request.containsKey(prop.name)) {
            final requestForSymbol = request[prop.name];
            // MediaMessage special case
            if (requestForSymbol is MediaMessage ||
                requestForSymbol is List<MediaMessage>) {
              // If in form, there is an (input[type="file"] multiple) and the user
              // put only one file. It's not an error and it should be accept.
              // Maybe it cans be optimized.
              if (schema.type.instanceMembers[sym].returnType.reflectedType is List<MediaMessage> &&
                  requestForSymbol is MediaMessage) {
                schema.setField(sym, [requestForSymbol]);
              } else if (requestForSymbol is List) {
                schema.setField(sym, prop.fromRequest(requestForSymbol));
              } else {
                schema.setField(sym, requestForSymbol);
              }
            } else {
              schema.setField(sym, prop.fromRequest(requestForSymbol));
            }
          } else if (prop.hasDefault) {
            schema.setField(sym, prop.fromRequest(prop.defaultValue));
          } else if (prop.required) {
            throw new BadRequestError('Required field ${prop.name} is missing');
          }
        } on TypeError catch (e) {
          throw BadRequestError('Field ${prop.name} has wrong type:  ${e}');
        }
      }
      return schema.reflectee;
    }
    throw new BadRequestError(
        'Invalid parameter: \'$request\', should be an instance of type '
            '\'$schemaName\'.');
  }

  J toResponse(D result) {
    var response = {};
    InstanceMirror mirror = reflect(result);
    _properties.forEach((sym, prop) {
      var value = prop.toResponse(mirror.getField(sym).reflectee);
      if (value != null) {
        response[prop.name] = value;
      }
    });
    return response as J;
  }
}

// Schema for explicitly handling List<'some value'> as either return
// or argument type. For the arguments it is only supported for POST requests.
class NamedListSchema<D> extends ApiConfigSchema<List<D>, List> {
  ApiConfigSchemaProperty _itemsProperty;

  NamedListSchema(String schemaName, ClassMirror schemaClass, bool isRequest)
      : super(schemaName, schemaClass, isRequest);

  void initItemsProperty(ApiConfigSchemaProperty itemsProperty) {
    assert(_itemsProperty == null);
    _itemsProperty = itemsProperty;
  }

  bool get containsData => _itemsProperty != null;

  discovery.JsonSchema get asDiscovery {
    var schema = new discovery.JsonSchema();
    schema
      ..id = schemaName
      ..type = 'array'
      ..items = _itemsProperty.asDiscovery;
    return schema;
  }

  List<D> fromRequest(List request) {
    // TODO: Performance optimization, we don't need to decode a list of
    // primitive-type since it is already the correct list.
    return request.map(_itemsProperty.fromRequest as D Function(Object)).toList();
  }

  // TODO: Performance optimization, we don't need to encode a list of
  // primitive-type since it is already the correct list.
  List toResponse(List<D> result) => result.map(_itemsProperty.toResponse).toList();
}

// Schema for explicitly handling Map<String, 'some value'> as either return
// or argument type. For the arguments it is only supported for POST requests.
class NamedMapSchema<D> extends ApiConfigSchema<Map<String, D>, Map> {
  ApiConfigSchemaProperty _additionalProperty;

  NamedMapSchema(String schemaName, ClassMirror schemaClass, bool isRequest)
      : super(schemaName, schemaClass, isRequest);

  void initAdditionalProperty(ApiConfigSchemaProperty additionalProperty) {
    assert(_additionalProperty == null);
    _additionalProperty = additionalProperty;
  }

  bool get containsData => _additionalProperty != null;

  discovery.JsonSchema get asDiscovery {
    var schema = new discovery.JsonSchema();
    schema
      ..id = schemaName
      ..type = 'object'
      ..additionalProperties = _additionalProperty.asDiscovery;
    return schema;
  }

  Map<String, D> fromRequest(Map request) {
    // Map from String to the type of the additional property.
    var decodedRequest = <String, D>{};
    // TODO: Performance optimization, we don't need to decode a map from
    // <String, primitive-type> since it is already the correct map.
    request.forEach((key, value) {
      decodedRequest[key] = _additionalProperty.fromRequest(value);
    });
    return decodedRequest;
  }

  Map toResponse(Map<String, D> result) {
    var encodedResult = {};
    // TODO: Performance optimization, we don't need to encode a map from
    // <String, primitive-type> since it is already the correct map.
    result.forEach((key, value) {
      encodedResult[key] = _additionalProperty.toResponse(value);
    });
    return encodedResult;
  }
}

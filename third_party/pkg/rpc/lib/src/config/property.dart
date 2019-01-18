// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of rpc.config;

/// [D] is the type used in Dart code.  [J] is the type used in JSON.
abstract class ApiConfigSchemaProperty<D, J> {
  final String name;
  final String description;
  final bool required;

  final J defaultValue;
  bool get hasDefault => (defaultValue != null);

  final String _apiType;
  final String _apiFormat;

  ApiConfigSchemaProperty(this.name, this.description, this.required,
      this.defaultValue, this._apiType, this._apiFormat);

  discovery.JsonSchema get typeAsDiscovery {
    return new discovery.JsonSchema()
      ..type = _apiType
      ..format = _apiFormat;
  }

  discovery.JsonSchema get asDiscovery {
    var property = typeAsDiscovery;
    if (required) {
      property.required = true;
    }
    if (description != null) {
      property.description = description;
    }
    if (defaultValue != null) {
      property.default_ = defaultValue.toString();
    }
    return property;
  }

  bool get isSimple => true;

  /// Convert JSON value to the underlying Dart type.  Default implementation
  /// requires that [J] can be casted to [D].
  D _fromRequest(J value) {
    return value as D;
  }

  D fromRequest(J value) {
    if (value == null) return null;
    return _fromRequest(value);
  }

  /// Convert Dart type to the corresponding JSON value.  Default implementation
  /// requires that [D] can be casted to [J].
  J _toResponse(D value) {
    return value as J;
  }

  J toResponse(D value) {
    if (value == null) return null;
    return _toResponse(value);
  }
}

class BigIntegerProperty extends ApiConfigSchemaProperty<BigInt, String> {
  final BigInt minValue;
  final BigInt maxValue;

  BigIntegerProperty(
      String name,
      String description,
      bool required,
      BigInt defaultValue,
      String apiType,
      String apiFormat,
      this.minValue,
      this.maxValue)
      : super(
            name,
            description,
            required,
            defaultValue != null ? defaultValue.toString() : null,
            apiType,
            apiFormat);

  String _toResponse(BigInt value) {
    assert(value != null);
    assert(_apiFormat.endsWith('64'));

    if (minValue != null && value < minValue) {
      throw new InternalServerError(
          'Return value \'$value\' smaller than minimum value \'$minValue\'');
    }
    if (maxValue != null && value > maxValue) {
      throw new InternalServerError(
          'Return value \'$value\' larger than maximum value \'$maxValue\'');
    }
    if (_apiFormat == 'int64' && value == value.toSigned(64) ||
        _apiFormat == 'uint64' && value == value.toUnsigned(64)) {
      assert(_apiType == 'string');
      return value.toString();
    }
    throw new InternalServerError(
        'Integer return value: \'$value\' not within the \'$_apiFormat\' '
        'property range.');
  }

  BigInt _fromRequest(String value) {
    assert(value != null);
    BigInt parsedValue;
    try {
      parsedValue = BigInt.parse(value);
    } on FormatException catch (e) {
      throw new BadRequestError('Invalid integer format: $e');
    }
    if (minValue != null && parsedValue < minValue) {
      throw new BadRequestError('$name needs to be >= $minValue');
    }
    if (maxValue != null && parsedValue > maxValue) {
      throw new BadRequestError('$name needs to be <= $maxValue');
    }
    return parsedValue;
  }

  discovery.JsonSchema get asDiscovery {
    var property = super.asDiscovery;
    if (minValue != null) {
      property.minimum = minValue.toString();
    }
    if (maxValue != null) {
      property.maximum = maxValue.toString();
    }
    return property;
  }
}

class IntegerProperty extends ApiConfigSchemaProperty<int, int> {
  final int minValue;
  final int maxValue;

  IntegerProperty(
      String name,
      String description,
      bool required,
      int defaultValue,
      String apiType,
      String apiFormat,
      this.minValue,
      this.maxValue)
      : super(name, description, required, defaultValue, apiType, apiFormat);

  int _toResponse(int value) {
    assert(value != null);
    assert(_apiFormat.endsWith('32'));
    if (minValue != null && value < minValue) {
      throw new InternalServerError(
          'Return value \'$value\' smaller than minimum value \'$minValue\'');
    }
    if (maxValue != null && value > maxValue) {
      throw new InternalServerError(
          'Return value \'$value\' larger than maximum value \'$maxValue\'');
    }

    if (_apiFormat == 'int32' && value == value.toSigned(32) ||
        _apiFormat == 'uint32' && value == value.toUnsigned(32)) {
      return value;
    }
    throw new InternalServerError(
        'Integer return value: \'$value\' not within the \'$_apiFormat\' '
        'property range.');
  }

  int _fromRequest(int value) {
    assert(value != null);
    if (minValue != null && value < minValue) {
      throw new BadRequestError('$name needs to be >= $minValue');
    }
    if (maxValue != null && value > maxValue) {
      throw new BadRequestError('$name needs to be <= $maxValue');
    }
    return value;
  }

  discovery.JsonSchema get asDiscovery {
    var property = super.asDiscovery;
    if (minValue != null) {
      property.minimum = minValue.toString();
    }
    if (maxValue != null) {
      property.maximum = maxValue.toString();
    }
    return property;
  }
}

class DoubleProperty extends ApiConfigSchemaProperty<double, dynamic> {
  DoubleProperty(String name, String description, bool required,
      double defaultValue, String apiFormat)
      : super(
            name,
            description,
            required,
            defaultValue != null ? defaultValue.toString() : null,
            'number',
            apiFormat);

  double _fromRequest(dynamic value) {
    assert(value != null);
    if (value is num) {
      return value.toDouble();
    }
    try {
      return double.parse(value);
    } on FormatException catch (e) {
      throw new BadRequestError('Invalid double format: $e');
    }
  }

  dynamic _toResponse(double value) {
    if (_apiFormat == 'float' &&
        (value < SMALLEST_FLOAT || value > LARGEST_FLOAT)) {
      throw new InternalServerError(
          'Result \'$value\' not in single precision \'float\' range: '
          '[$SMALLEST_FLOAT, $LARGEST_FLOAT].');
    }
    return value;
  }
}

class StringProperty extends ApiConfigSchemaProperty<String, String> {
  StringProperty(
      String name, String description, bool required, String defaultValue)
      : super(name, description, required, defaultValue, 'string', null);
}

class EnumProperty extends ApiConfigSchemaProperty<String, String> {
  final Map<String, String> _values;

  EnumProperty(String name, String description, bool required,
      String defaultValue, this._values)
      : super(name, description, required, defaultValue, 'string', null);

  discovery.JsonSchema get asDiscovery {
    return super.asDiscovery
      ..enum_ = _values.keys.toList()
      ..enumDescriptions = _values.values.toList();
  }

  String _fromRequest(String value) {
    assert(value != null);
    if (_values.containsKey(value)) {
      return value;
    }
    throw new BadRequestError('Value is not a valid enum value');
  }
}

class BooleanProperty extends ApiConfigSchemaProperty<bool, dynamic> {
  BooleanProperty(
      String name, String description, bool required, bool defaultValue)
      : super(
            name,
            description,
            required,
            defaultValue != null ? defaultValue.toString() : null,
            'boolean',
            null);

  bool _fromRequest(dynamic value) {
    assert(value != null);
    if (value is bool) {
      return value;
    }
    if (value is String) {
      if (value.toLowerCase() == 'true') {
        return true;
      } else if (value.toLowerCase() == 'false') {
        return false;
      }
    }
    throw new BadRequestError('Invalid boolean value: $value');
  }
}

class DateTimeProperty extends ApiConfigSchemaProperty<DateTime, String> {
  DateTimeProperty(
      String name, String description, bool required, DateTime defaultValue)
      : super(
            name,
            description,
            required,
            defaultValue != null
                ? defaultValue.toUtc().toIso8601String()
                : null,
            'string',
            'date-time');

  String _toResponse(DateTime value) {
    assert(value != null);
    return value.toUtc().toIso8601String();
  }

  DateTime _fromRequest(String value) {
    assert(value != null);
    try {
      return DateTime.parse(value);
    } on FormatException catch (e) {
      throw new BadRequestError('Invalid date format: $e');
    }
  }
}

class SchemaProperty<D> extends ApiConfigSchemaProperty<D, dynamic> {
  final ApiConfigSchema _ref;

  SchemaProperty(String name, String description, bool required, this._ref)
      : super(name, description, required, null, null, null);

  dynamic _toResponse(D value) {
    assert(value != null);
    return _ref.toResponse(value);
  }

  D _fromRequest(dynamic value) {
    assert(value != null);
    if (value is! Map && value is! MediaMessage) {
      throw new BadRequestError('Invalid request message');
    }
    return _ref.fromRequest(value);
  }

  discovery.JsonSchema get typeAsDiscovery =>
      new discovery.JsonSchema()..P_ref = _ref.schemaName;

  bool get isSimple => false;
}

class ListProperty<D> extends ApiConfigSchemaProperty<List<D>, List> {
  final ApiConfigSchemaProperty _itemsProperty;

  ListProperty(
      String name, String description, bool required, this._itemsProperty)
      : super(name, description, required, null, null, null);

  discovery.JsonSchema get typeAsDiscovery =>
      new discovery.JsonSchema()..type = 'array';

  discovery.JsonSchema get asDiscovery =>
      super.asDiscovery..items = _itemsProperty.asDiscovery;

  List _toResponse(List<D> listObject) {
    return listObject.map(_itemsProperty._toResponse).toList();
  }

  List<D> _fromRequest(List encodedList) {
    return encodedList.map<D>(_itemsProperty._fromRequest as D Function(Object)).toList();
  }
}

class MapProperty<D> extends ApiConfigSchemaProperty<Map<String, D>, Map> {
  final ApiConfigSchemaProperty _additionalProperty;

  MapProperty(
      String name, String description, bool required, this._additionalProperty)
      : super(name, description, required, null, null, null);

  discovery.JsonSchema get typeAsDiscovery =>
      new discovery.JsonSchema()..type = 'object';

  discovery.JsonSchema get asDiscovery =>
      super.asDiscovery..additionalProperties = _additionalProperty.asDiscovery;

  Map _toResponse(Map<String, D> mapObject) {
    var result = {};
    mapObject.forEach((String key, D object) {
      result[key] = _additionalProperty._toResponse(object);
    });
    return result;
  }

  Map<String, D> _fromRequest(Map encodedMap) {
    // Map from String to the type of the additional property.
    var result = <String, D>{};
    encodedMap.forEach((key, encodedObject) {
      result[key] = _additionalProperty._fromRequest(encodedObject);
    });
    return result;
  }
}

# HaikunatorDART

[![Build Status](https://img.shields.io/travis/Atrox/haikunatordart.svg?style=flat-square)](https://travis-ci.org/Atrox/haikunatordart)
[![Latest Version](https://img.shields.io/pub/v/haikunator.svg?style=flat-square)](https://pub.dartlang.org/packages/haikunator)

Generate Heroku-like random names to use in your dart applications.

## Installation

Add the following to your `pubspec.yaml` and run `pub get`:

```yaml
dependencies:
  haikunator: any
```

## Usage

Haikunator is pretty simple.

```dart
import 'package:haikunator/haikunator.dart';

// default usage
Haikunator.haikunate() // => "wispy-dust-1337"

// custom length (default=4)
Haikunator.haikunate(tokenLength: 6) // => "patient-king-887265"

// use hex instead of numbers
Haikunator.haikunate(tokenHex: true) // => "purple-breeze-98e1"

// use custom chars instead of numbers/hex
Haikunator.haikunate(tokenChars: "HAIKUNATE") // => "summer-atom-IHEA"

// don't include a token
Haikunator.haikunate(tokenLength: 0) // => "cold-wildflower"

// use a different delimiter
Haikunator.haikunate(delimiter: ".") // => "restless.sea.7976"

// no token, space delimiter
Haikunator.haikunate(tokenLength: 0, delimiter: " ") // => "delicate haze"

// no token, empty delimiter
Haikunator.haikunate(tokenLength: 0, delimiter: "") // => "billowingleaf"
```

## Options

The following options are available:

```dart
Haikunator.haikunate(
  delimiter: "-",
  tokenLength: 4,
  tokenHex: false,
  tokenChars: "0123456789"
);
```
*If ```tokenHex``` is true, it overrides any tokens specified in ```tokenChars```*

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/Atrox/haikunatordart/issues)
- Fix bugs and [submit pull requests](https://github.com/Atrox/haikunatordart/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

## Other Languages

Haikunator is also available in other languages. Check them out:

- Node: https://github.com/Atrox/haikunatorjs
- PHP: https://github.com/Atrox/haikunatorphp
- Python: https://github.com/Atrox/haikunatorpy
- Ruby: https://github.com/usmanbashir/haikunator
- Go: https://github.com/yelinaung/go-haikunator
// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common;

import 'dart:io';

const kMainDart = 'main.dart';
const kBootstrapDart = 'bootstrap.dart';

/// This code should be kept up-to-date with WebEntrypointTarget.build() from
/// flutter_tools: https://github.com/flutter/flutter/blob/169020719bc5882e746b836629721644633b6c8a/packages/flutter_tools/lib/src/build_system/targets/web.dart#L137
const kBootstrapFlutterCode = r'''
import 'dart:ui' as ui;
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'generated_plugin_registrant.dart';
import 'main.dart' as entrypoint;

Future<void> main() async {
  registerPlugins(webPluginRegistrar);
  await ui.webOnlyInitializePlatform();
  entrypoint.main();
}
''';

const kBootstrapDartCode = r'''
import 'main.dart' as user_code;

void main() {
  user_code.main();
}
''';

const sampleCode = '''
void main() {
  print("hello");
}
''';

const sampleCodeWeb = """
import 'dart:html';

void main() {
  print("hello");
  querySelector('#foo')?.text = 'bar';
}
""";

const sampleCodeFlutter = '''
import 'package:flutter/material.dart';

void main() async {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Hey there, boo!'),
        ),
        body: const Center(
          child: Text(
            'You are pretty okay.',
          ),
        ),
      ),
    ),
  );
}
''';

// From https://gist.github.com/johnpryan/1a28bdd9203250d3226cc25d512579ec
const sampleCodeFlutterCounter = r'''
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
''';

// From https://gist.github.com/RedBrogdon/e0a2e942e85fde2cd39b2741ff0c49e5
const sampleCodeFlutterSunflower = r'''
import 'dart:math' as math;
import 'package:flutter/material.dart';

const Color primaryColor = Colors.orange;
const TargetPlatform platform = TargetPlatform.android;

void main() {
  runApp(Sunflower());
}

class SunflowerPainter extends CustomPainter {
  static const seedRadius = 2.0;
  static const scaleFactor = 4;
  static const tau = math.pi * 2;

  static final phi = (math.sqrt(5) + 1) / 2;

  final int seeds;

  SunflowerPainter(this.seeds);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width / 2;

    for (var i = 0; i < seeds; i++) {
      final theta = i * tau / phi;
      final r = math.sqrt(i) * scaleFactor;
      final x = center + r * math.cos(theta);
      final y = center - r * math.sin(theta);
      final offset = Offset(x, y);
      if (!size.contains(offset)) {
        continue;
      }
      drawSeed(canvas, x, y);
    }
  }

  @override
  bool shouldRepaint(SunflowerPainter oldDelegate) {
    return oldDelegate.seeds != seeds;
  }

  // Draw a small circle representing a seed centered at (x,y).
  void drawSeed(Canvas canvas, double x, double y) {
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.fill
      ..color = primaryColor;
    canvas.drawCircle(Offset(x, y), seedRadius, paint);
  }
}

class Sunflower extends StatefulWidget {
  @override
  State<Sunflower> createState() {
    return _SunflowerState();
  }
}

class _SunflowerState extends State<Sunflower> {
  double seeds = 100.0;

  int get seedCount => seeds.floor();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData().copyWith(
        platform: platform,
        brightness: Brightness.dark,
        sliderTheme: SliderThemeData.fromPrimaryColors(
          primaryColor: primaryColor,
          primaryColorLight: primaryColor,
          primaryColorDark: primaryColor,
          valueIndicatorTextStyle: const DefaultTextStyle.fallback().style,
        ),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text("Sunflower")),
        drawer: Drawer(
            child: ListView(
          children: const [
            DrawerHeader(
              child: Center(
                child: Text(
                  "Sunflower 🌻",
                  style: TextStyle(fontSize: 32),
                ),
              ),
            ),
          ],
        )),
        body: Container(
          constraints: const BoxConstraints.expand(),
          decoration:
              BoxDecoration(border: Border.all(color: Colors.transparent)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.transparent)),
                child: SizedBox(
                  width: 400,
                  height: 400,
                  child: CustomPaint(
                    painter: SunflowerPainter(seedCount),
                  ),
                ),
              ),
              Text("Showing $seedCount seeds"),
              ConstrainedBox(
                constraints: const BoxConstraints.tightFor(width: 300),
                child: Slider.adaptive(
                  min: 20,
                  max: 2000,
                  value: seeds,
                  onChanged: (newValue) {
                    setState(() {
                      seeds = newValue;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
''';

// https://gist.github.com/johnpryan/5e28c5273c2c1a41d30bad9f9d11da56
const sampleCodeFlutterDraggableCard = '''
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PhysicsCardDragDemo(),
    ),
  );
}

class PhysicsCardDragDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('A draggable card!'),
      ),
      body: const DraggableCard(
        child: FlutterLogo(
          size: 128,
        ),
      ),
    );
  }
}

class DraggableCard extends StatefulWidget {
  final Widget child;
  const DraggableCard({required this.child});

  @override
  State<DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends State<DraggableCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Alignment _dragAlignment = Alignment.center;
  Animation<Alignment>? _animation;

  void _runAnimation(Offset pixelsPerSecond, Size size) {
    _animation = _controller!.drive(
      AlignmentTween(
        begin: _dragAlignment,
        end: Alignment.center,
      ),
    );

    final unitsPerSecondX = pixelsPerSecond.dx / size.width;
    final unitsPerSecondY = pixelsPerSecond.dy / size.height;
    final unitsPerSecond = Offset(unitsPerSecondX, unitsPerSecondY);
    final unitVelocity = unitsPerSecond.distance;

    const spring = SpringDescription(
      mass: 30,
      stiffness: 1,
      damping: 1,
    );

    final simulation = SpringSimulation(spring, 0, 1, -unitVelocity);

    _controller!.animateWith(simulation);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);

    _controller!.addListener(() {
      setState(() {
        _dragAlignment = _animation!.value;
      });
    });
  }

  @override
  void dispose() {
    _controller!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return GestureDetector(
      onPanDown: (details) {
        _controller!.stop();
      },
      onPanUpdate: (details) {
        setState(() {
          _dragAlignment += Alignment(
            details.delta.dx / (size.width / 2),
            details.delta.dy / (size.height / 2),
          );
        });
      },
      onPanEnd: (details) {
        _runAnimation(details.velocity.pixelsPerSecond, size);
      },
      child: Align(
        alignment: _dragAlignment,
        child: Card(
          child: widget.child,
        ),
      ),
    );
  }
}
''';

// From https://gist.github.com/johnpryan/289ecf8480ad005f01faeace70bd529a
const sampleCodeFlutterImplicitAnimations = '''
import 'dart:math';
import 'package:flutter/material.dart';

class DiscData {
  static final _rng = Random();

  final double size;
  final Color color;
  final Alignment alignment;

  DiscData()
      : size = _rng.nextDouble() * 40 + 10,
        color = Color.fromARGB(
          _rng.nextInt(200),
          _rng.nextInt(255),
          _rng.nextInt(255),
          _rng.nextInt(255),
        ),
        alignment = Alignment(
          _rng.nextDouble() * 2 - 1,
          _rng.nextDouble() * 2 - 1,
        );
}

void main() async {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Container(
          color: const Color(0xFF15202D),
          child: const SizedBox.expand(
            child: VariousDiscs(50),
          ),
        ),
      ),
    ),
  );
}

class VariousDiscs extends StatefulWidget {
  final int numberOfDiscs;

  const VariousDiscs(this.numberOfDiscs);

  @override
  State<VariousDiscs> createState() => _VariousDiscsState();
}

class _VariousDiscsState extends State<VariousDiscs> {
  final _discs = <DiscData>[];

  @override
  void initState() {
    super.initState();
    _makeDiscs();
  }

  void _makeDiscs() {
    _discs.clear();
    for (int i = 0; i < widget.numberOfDiscs; i++) {
      _discs.add(DiscData());
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() {
        _makeDiscs();
      }),
      child: Stack(
        children: [
          const Center(
            child: Text(
              'Click a disc!',
              style: TextStyle(color: Colors.white, fontSize: 50),
            ),
          ),
          for (final disc in _discs)
            Positioned.fill(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                alignment: disc.alignment,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  decoration: BoxDecoration(
                    color: disc.color,
                    shape: BoxShape.circle,
                  ),
                  height: disc.size,
                  width: disc.size,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
''';

const sampleCodeMultiFoo = """
import 'bar.dart';

void main() {
  print(bar());
}
""";

const sampleCodeMultiBar = '''
bar() {
  return 4;
}
''';

const sampleCodeLibraryMultiFoo = """
library foofoo;

part 'bar.dart';

void main() {
  print(bar());
}
""";

const sampleCodePartMultiBar = '''
part of foofoo;

bar() {
  return 4;
}
''';

const sampleCodeAsync = """
import 'dart:html';

void main() async {
  print("hello");
  querySelector('#foo')?.text = 'bar';
  var foo = await HttpRequest.getString('http://www.google.com');
  print(foo);
}
""";

const sampleCodeError = '''
void main() {
  print("hello")
}
''';

const sampleCodeErrors = '''
void main() {
  print1("hello");
  print2("hello");
  print3("hello");
}
''';

const sampleDart2Error = '''
class Foo {
  final bool isAlwaysNull;
  Foo(this.isAlwaysNull) {}
}

void main(List<String> argv) {
  var x = new Foo(null);
  var y = 1;
  y = x;
}
''';

/// Code fragments for testing multi file compiling.
/// These fragments are taken from [sampleCodeFlutterImplicitAnimations] and
/// only separated and re-arranged to facilitate testing multi file tests.

const sampleCode3PartFlutterImplicitAnimationsImports = r'''
import 'dart:math';
import 'package:flutter/material.dart';
''';

const sampleCode3PartFlutterImplicitAnimationsMain = r'''

void main() async {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Container(
          color: const Color(0xFF15202D),
          child: const SizedBox.expand(
            child: VariousDiscs(50),
          ),
        ),
      ),
    ),
  );
}
''';

const sampleCode3PartFlutterImplicitAnimationsDiscData = r'''

class DiscData {
  static final _rng = Random();

  final double size;
  final Color color;
  final Alignment alignment;

  DiscData()
      : size = _rng.nextDouble() * 40 + 10,
        color = Color.fromARGB(
          _rng.nextInt(200),
          _rng.nextInt(255),
          _rng.nextInt(255),
          _rng.nextInt(255),
        ),
        alignment = Alignment(
          _rng.nextDouble() * 2 - 1,
          _rng.nextDouble() * 2 - 1,
        );
}
''';

const sampleCode3PartFlutterImplicitAnimationsVarious = r'''

class VariousDiscs extends StatefulWidget {
  final int numberOfDiscs;

  const VariousDiscs(this.numberOfDiscs);

  @override
  State<VariousDiscs> createState() => _VariousDiscsState();
}

class _VariousDiscsState extends State<VariousDiscs> {
  final _discs = <DiscData>[];

  @override
  void initState() {
    super.initState();
    _makeDiscs();
  }

  void _makeDiscs() {
    _discs.clear();
    for (int i = 0; i < widget.numberOfDiscs; i++) {
      _discs.add(DiscData());
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() {
        _makeDiscs();
      }),
      child: Stack(
        children: [
          const Center(
            child: Text(
              'Click a disc!',
              style: TextStyle(color: Colors.white, fontSize: 50),
            ),
          ),
          for (final disc in _discs)
            Positioned.fill(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                alignment: disc.alignment,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  decoration: BoxDecoration(
                    color: disc.color,
                    shape: BoxShape.circle,
                  ),
                  height: disc.size,
                  width: disc.size,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
''';

/// Create 2 files for multi file testing using imports.
const sampleCode2PartImportMain = '''
$sampleCode3PartFlutterImplicitAnimationsImports
import 'various.dart';
$sampleCode3PartFlutterImplicitAnimationsMain
''';

const sampleCode2PartImportVarious = '''
$sampleCode3PartFlutterImplicitAnimationsImports
$sampleCode3PartFlutterImplicitAnimationsDiscData
$sampleCode3PartFlutterImplicitAnimationsVarious
''';

/// Create 3 separate files for multi file testing using imports.
/// Here main.dart will be importing 'various.dart' and 'discdata.dart',
/// and 'various.dart' importing 'discdata.dart'.
const sampleCode3PartImportMain = '''
$sampleCode3PartFlutterImplicitAnimationsImports
import 'various.dart';
import 'discdata.dart';
$sampleCode3PartFlutterImplicitAnimationsMain
''';

const sampleCode3PartImportDiscData = '''
$sampleCode3PartFlutterImplicitAnimationsImports
$sampleCode3PartFlutterImplicitAnimationsDiscData
''';

const sampleCode3PartImportVarious = '''
$sampleCode3PartFlutterImplicitAnimationsImports
import 'discdata.dart';
$sampleCode3PartFlutterImplicitAnimationsVarious
''';

/// Create 2 file test using "part 'various.dart'" to bring in second file.
const sampleCode2PartLibraryMain = '''
library testanim;
$sampleCode3PartFlutterImplicitAnimationsImports
part 'various.dart';
$sampleCode3PartFlutterImplicitAnimationsMain
''';

const sampleCode2PartVariousAndDiscDataPartOfTestAnim = '''
part of testanim;
$sampleCode3PartFlutterImplicitAnimationsDiscData
$sampleCode3PartFlutterImplicitAnimationsVarious
''';

/// Create 3 file test using "part 'various.dart'" and "part 'discdata.dart'"
/// to bring in second and third files.
const sampleCode3PartLibraryMain = '''
library testanim;
$sampleCode3PartFlutterImplicitAnimationsImports
part 'discdata.dart';
part 'various.dart';
$sampleCode3PartFlutterImplicitAnimationsMain
''';

const sampleCode3PartDiscDataPartOfTestAnim = '''
part of testanim;
$sampleCode3PartFlutterImplicitAnimationsDiscData
''';

const sampleCode3PartVariousPartOfTestAnim = '''
part of testanim;
$sampleCode3PartFlutterImplicitAnimationsVarious
''';

class Lines {
  final List<int> _starts = <int>[];

  Lines(String source) {
    final units = source.codeUnits;
    for (var i = 0; i < units.length; i++) {
      if (units[i] == 10) _starts.add(i);
    }
  }

  /// Return the 0-based line number.
  int getLineForOffset(int offset) {
    for (var i = 0; i < _starts.length; i++) {
      if (offset <= _starts[i]) return i;
    }
    return _starts.length;
  }
}

/// Returns the version of the current Dart runtime.
///
/// The returned `String` is formatted as the [semver](http://semver.org) version
/// string of the current Dart runtime, possibly followed by whitespace and other
/// version and build details.
String get vmVersion => Platform.version;

/// If [str] has leading and trailing quotes, remove them.
String stripMatchingQuotes(String str) {
  if (str.length <= 1) return str;

  if (str.startsWith("'") && str.endsWith("'")) {
    str = str.substring(1, str.length - 1);
  } else if (str.startsWith('"') && str.endsWith('"')) {
    str = str.substring(1, str.length - 1);
  }
  return str;
}

class _SourcesGroupFile {
  String filename;
  String content;

  _SourcesGroupFile(this.filename, this.content);
}

///This RegExp matches a variety of possible `main` function definition formats
///Like:
/// - `Future<void> main(List<String> args) async {`
/// - `void main(List<String> args) async {`
/// - `void main() {`
/// - `void main( List < String >  args ) async {`
/// - `void main(Args arg) {`
/// - `main() {`
/// - `void main() {}`
/// - `void main() => runApp(MyApp());`
final RegExp mainFunctionDefinition = RegExp(
    r'''[\s]*(Future)?[\<]?(void)?[\>]?[\s]*main[\s]*\((\s*\w*\s*\<?\s*\w*\s*\>?\s*\w*\s*)?\)\s*(async)?\s*[\{|\=]+''');

/// Used to remove 2 or more '..' and any number of following slashes of '/' or '\'.
final RegExp sanitizeUpDirectories = RegExp(r'[\.]{2,}[\\\/]*');

/// Used to remove 'package:', 'dart:', 'http://', 'https://' etc.
final RegExp sanitizePackageDartHttp = RegExp(r'[\w]*[\:][\/]*');

/// Sanitizes [filename] by using the regular expressions
/// [sanitizeUpDirectories] and [sanitizePackageDartHttp] to remove
/// anything like 'package:', 'dart:' or 'http://', and then removing
/// runs of more than a single '.' (do not allow '..' up directories to
/// escape temp directory).
String _sanitizeFileName(String filename) {
  filename = filename.replaceAll(sanitizePackageDartHttp, '');
  filename = filename.replaceAll(sanitizeUpDirectories, '');
  return filename;
}

/// Goes through [sources] map of source files and sanitizes the filenames
/// and ensures that the file containing the main entry point that bootstrap
/// will be calling is called [kMainDart].
/// [sources] is a map containing the source files in the format
///   `{ "filename1":"sourcecode1" .. "filenameN":"sourcecodeN"}`.
/// [activeSourceName] is the name of the source file active in the editor.
/// Returns [activeSourceName] or a new name if sanitized or renamed.
String sanitizeAndCheckFilenames(Map<String, String> sources,
    [String activeSourceName = kMainDart]) {
  activeSourceName = _sanitizeFileName(activeSourceName);

  final List<_SourcesGroupFile> files =
      sources.entries.map((e) => _SourcesGroupFile(e.key, e.value)).toList();

  bool foundKMain = false;
  // Check for kMainDart file and also sanitize filenames.
  for (final sourceFile in files) {
    sourceFile.filename = _sanitizeFileName(sourceFile.filename);
    if (sourceFile.filename == kMainDart) {
      foundKMain = true;
    }
  }
  // One of the files must be named kMainDart. This is the file that the
  // bootstrap dart file will import and call main() on.
  if (!foundKMain && files.isNotEmpty) {
    // We need to rename the file containing the main() function to kMainDart.
    for (final sourceFile in files) {
      if (mainFunctionDefinition.hasMatch(sourceFile.content)) {
        // This file has a main() function, rename it to kMainDart
        // and also change activeSourceName if that is the file being
        // renamed.
        if (sourceFile.filename == activeSourceName) {
          activeSourceName = kMainDart;
        }
        sourceFile.filename = kMainDart;
        foundKMain = true;
        break;
      }
    }
    if (!foundKMain) {
      // No kMainDart was found so just change the first file to be kMainDart.
      if (files[0].filename == activeSourceName) {
        activeSourceName = kMainDart;
      }
      files[0].filename = kMainDart;
    }
  }

  // Take our files list and create a new files {filename:content} map.
  sources.clear();
  for (final sourceFiles in files) {
    sources[sourceFiles.filename] = sourceFiles.content;
  }

  return activeSourceName;
}

/// Count the total lines across all files in [sources] file map.
int countLines(Map<String, String> sources) {
  int totalLines = 0;
  for (final filename in sources.keys) {
    totalLines += countLinesInString(sources[filename]!);
  }
  return totalLines;
}

// Character constants.
const int _lf = 10;
const int _cr = 13;

/// Count lines in string (CR, LF or CR-LF can be line separators).
/// (Gives correct result as opposed to .split('\n').length, which
/// reports 1 extra line in many cases, and this does so without the
/// extra work .split() would do by creating the list of copied strings).
int countLinesInString(String str) {
  final List<int> data = str.codeUnits;
  int lines = 0;
  final int end = data.length;
  int sliceStart = 0;
  int char = 0;
  for (int i = 0; i < end; i++) {
    final int previousChar = char;
    char = data[i];
    if (char != _cr) {
      if (char != _lf) continue;
      if (previousChar == _cr) {
        sliceStart = i + 1;
        continue;
      }
    }
    lines++;
    sliceStart = i + 1;
  }
  if (sliceStart < end) {
    lines++;
  }
  return lines;
}

import 'dart:io';
import 'package:path/path.dart' as path;

const String packageName = 'mdc_web_sass';

main() async {
  print('npm i material-components-web');
  var result = await Process.run('npm', ['install', 'material-components-web']);
  if (result.stdout != null) {
    stdout.write(result.stdout);
  }
  if (result.stderr != null) {
    stderr.write(result.stderr);
  }

  var entrypoint =
      File('node_modules/material-components-web/material-components-web.scss');
  var entrypointContents = await entrypoint.readAsString();
  var entrypointTarget = File('lib/material-components-web.scss');
  var f = await entrypointTarget
      .writeAsString(dartifyImports(entrypointContents));
  await copyMaterialSassFiles();
  stdout.writeln('$f written');
  await Directory('node_modules').delete(recursive: true);
  stdout.writeln('node_modules deleted');
  await File('package-lock.json').delete();
  stdout.writeln('package-lock.json deleted');
}

Future copyMaterialSassFiles() async {
  var parent = Directory('node_modules/@material/');
  await for (var entity in parent.list()) {
    if (entity is Directory) {
      for (var f in entity.listSync(recursive: true)) {
        if (f is File && path.extension(f.path) == '.scss') {
          var components = path.split(f.path);
          var start = components.indexOf('@material') + 1;
          var relativePath = components.sublist(start);
          var newPath = path.joinAll(['lib', 'src', ...relativePath]);
          var newFile = await File(newPath).create(recursive: true);
          await newFile.writeAsString(dartifyImports(await f.readAsString()));
          stdout.writeln('$newFile written');
        }
      }
    }
  }
}

/// Changes `@import "@material/elevation/mixins";` to `@import
/// "package:mdc_web_sass/src/elevation/mixins";`
String dartifyImports(String contents) {
  var buf = StringBuffer();
  for (var line in contents.split('\n')) {
    buf.writeln(line.replaceAll('@material/', 'package:$packageName/src/'));
  }
  return buf.toString();
}


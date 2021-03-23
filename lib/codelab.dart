import 'dart:html';

import 'package:dart_pad/util/query_params.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:split/split.dart';

import 'codelabs/codelabs.dart';
import 'core/modules.dart';
import 'modules/codemirror_module.dart';
import 'modules/dart_pad_module.dart';
import 'modules/dartservices_module.dart';

CodelabUi _codelabUi;

CodelabUi get codelabUi => _codelabUi;

void init() {
  _codelabUi = CodelabUi();
}

class CodelabUi {
  Splitter splitter;
  Splitter rightSplitter;

  CodelabUi() {
    _init();
  }

  Future<void> _init() async {
    _initSplitters();
    var codelab = await _loadCodelab();
    _initHeader(codelab.name);
    _initStepsPanel(codelab);
    await _initModules();

  }

  Future<void> _initModules() async {
    var modules = ModuleManager();

    modules.register(DartPadModule());
    modules.register(DartServicesModule());
    modules.register(CodeMirrorModule());

    await modules.start();
  }

  Future<Codelab> _loadCodelab() async {
    var fetcher = await _getFetcher();
    return await fetcher.getCodelab();
  }

  void _initSplitters() {
    var stepsPanel = querySelector('#steps-panel');
    var rightPanel = querySelector('#right-panel');
    var editorPanel = querySelector('#editor-panel');
    var outputPanel = querySelector('#output-panel');
    splitter = flexSplit(
      [stepsPanel, rightPanel],
      horizontal: true,
      gutterSize: 6,
      sizes: const [50, 50],
      minSize: [100, 100],
    );
    rightSplitter = flexSplit(
      [editorPanel, outputPanel],
      horizontal: false,
      gutterSize: 6,
      sizes: const [50, 50],
      minSize: [100, 100],
    );
  }

  void _initHeader(String name) {
    querySelector('#codelab-name').text = name;
  }

  void _initStepsPanel(Codelab codelab) {
    var div = querySelector('#steps-panel');
    div.innerHtml = markdown.markdownToHtml(codelab.steps.first.instructions);
  }

  Future<CodelabFetcher> _getFetcher() async {
    var webServer = queryParams.webServer;
    if (webServer != null && webServer.isNotEmpty) {
      var uri = Uri.parse(webServer);
      return WebServerCodelabFetcher(uri);
    }
    var ghOwner = queryParams.githubOwner;
    var ghRepo = queryParams.githubRepo;
    var ghRef = queryParams.githubRef;
    var ghPath = queryParams.githubPath;
    if (ghOwner != null &&
        ghOwner.isNotEmpty &&
        ghRepo != null &&
        ghRepo.isNotEmpty &&
        ghRef != null &&
        ghRef.isNotEmpty &&
        ghPath != null &&
        ghPath.isNotEmpty) {
      return GithubCodelabFetcher(
        owner: ghOwner,
        repo: ghRepo,
        ref: ghRef,
        path: ghPath,
      );
    }
    throw ('Invalid parameters provided. Use either "webserver" or '
        '"gh_owner", "gh_repo", "gh_ref", and "gh_path"');
  }
}

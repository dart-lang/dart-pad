// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library playground;

import 'dart:async';
import 'dart:convert' show json;
import 'dart:html' hide Console;
import 'dart:math';

import 'package:encrypt/encrypt.dart';
import 'package:http/http.dart' as http;
import 'package:mdc_web/mdc_web.dart';
import 'package:stream_transform/stream_transform.dart';

import 'dart_pad.dart';
import 'elements/analysis_results_controller.dart';
import 'elements/button.dart';
import 'elements/elements.dart';
import 'playground.dart';
import 'sharing/gists.dart';
import 'sharing/mutable_gist.dart';

class GitHubUIController {
  final Playground _playground;
  late final GitHubAuthenticationController _githubAuthController;

  final LIElement _githubMenuItemLogin =
      querySelector('#github-login-item') as LIElement;
  final LIElement _githubMenuItemCreatePublic =
      querySelector('#github-createpublic-item') as LIElement;
  final LIElement _githubMenuItemCreatePrivate =
      querySelector('#github-createprivate-item') as LIElement;
  final LIElement _githubMenuItemFork =
      querySelector('#github-fork-item') as LIElement;
  final LIElement _githubMenuItemUpdate =
      querySelector('#github-update-item') as LIElement;
  final LIElement _githubMenuItemStar =
      querySelector('#github-star-item') as LIElement;
  final LIElement _githubMenuItemOpenOnGithub =
      querySelector('#github-open-on-github-item') as LIElement;
  final LIElement _githubMenuItemLogout =
      querySelector('#github-logout-item') as LIElement;
  final SpanElement _starUnstarButton =
      querySelector('#gist_star_button') as SpanElement;
  final Element _starIconHolder = querySelector('#gist_star_inner_icon')!;
  final Element _starMenuIconHolder =
      querySelector('#github-star-item .mdc-select__icon')!;
  final SpanElement _starMenuItemText =
      querySelector('#github-star-item .mdc-list-item__text') as SpanElement;
  final DElement _titleElement =
      DElement(querySelector('header .header-gist-name')!);
  final ButtonElement _myGistsDropdownButton =
      querySelector('#my-gists-dropdown-button') as ButtonElement;
  final ButtonElement _starredGistsDropdownButton =
      querySelector('#starred-gists-dropdown-button') as ButtonElement;

  // Get the base URL to use for the GH Authorization request from environment
  //   (this is set in build.yaml)
  static const String _googleCloudRunUrl =
      String.fromEnvironment('GH_AUTH_INIT_BASE_URL');

  MDCMenu? _starredGistsMenu;
  MDCMenu? _myGistsMenu;

  bool _prevAuthenticationState = false;

  bool _inGithubAuthStateChangeHandler = false;

  String _gistIdOfLastStarredReport = '';
  bool _starredStateOfLastStarReport = false;

  GitHubUIController(this._playground) {
    window.console.log(
        'pre GitHubLoginController() window URL =${window.location.toString()}  win.loc.href=${window.location.href}');
    _githubAuthController = GitHubAuthenticationController(
        Uri.parse(window.location.toString()), _playground.snackbar);
    initGitHubMenu();
    setupGithubGistListeners();

    window.console
        .log('We are READY, asking GitHubLoginController() to post event!');

    _githubAuthController.postCreationFireAutheticatedStateChangeEvent();
  }

  void initGitHubMenu() {
    final githubMenuButton =
        querySelector('#github-menu-button') as ButtonElement;
    final githubMenu = MDCMenu(querySelector('#github-menu'))
      ..setAnchorCorner(AnchorCorner.bottomLeft)
      ..setAnchorElement(githubMenuButton)
      ..hoistMenuToBody();
    MDCButton(githubMenuButton, isIcon: true)
        .onClick
        .listen((_) => Playground.toggleMenu(githubMenu));
    githubMenu.listen('MDCMenu:selected', (e) {
      final idx = (e as CustomEvent).detail['index'] as int?;
      switch (idx) {
        case 0: // login
          _attempToAquireGitHubToken();
          break;
        case 1: // create public gist
          _saveGist();
          break;
        case 2: // create private gist
          _saveGist(public: false);
          break;
        case 3: // fork gists
          _forkGist();
          break;
        case 4: //update gists
          _updateGist();
          break;
        case 5: //star gists
          _starredButtonClickHandler(null);
          break;
        case 6: //open on github
          window.open('https://gist.github.com/${_playground.mutableGist.id}',
              '_blank');
          // and in 10 seconds check with github and update our my gists and starred menus
          // This is just another wait to force a check with github to sync
          // our menus up.  (the long delay in starred API results updating can be frustrating)
          _githubAuthController.updateUsersGistAndStarredGistsList(starredCheckDelay:10000);
          break;
        case 7: //logout
          _githubAuthController.logoutUnauthenticate();
          break;
      }
    });
  }

  void setUnsavedLocalEdits([bool unsavedLocalEdits=false]) {
    final SpanElement unsavedLocalEditsSpan =
        querySelector('#unsaved-local-edit') as SpanElement;
    unsavedLocalEdits = unsavedLocalEdits || _playground.mutableGist.dirty;
    if (unsavedLocalEdits) {
      unsavedLocalEditsSpan.removeAttribute('hidden');
    } else {
      unsavedLocalEditsSpan.setAttribute('hidden', true);
    }
  }

  void setupGithubGistListeners() {
    _playground.mutableGist.onChanged
        .debounce(Duration(milliseconds: 100))
        .listen((_) {
      window.console
          .log('setupGithubGistListeners mutableGist On Changed FIRED');
      setUnsavedLocalEdits();
    });
    _playground.mutableGist.property('id').onChanged!.listen((_) {
      window.console.log('setupGithubGistListeners gist ID On Changed FIRED');
      // the gist Id has changed
      _setGithubMenuItemStates(_githubAuthController, _playground.mutableGist);
    });
    _githubAuthController.onAuthStateChanged.listen((authenticated) {
      window.console.log('GitHub Authentication State Changed FIRED');

      _setGithubMenuItemStates(_githubAuthController, _playground.mutableGist);
      _handleGithubAuthStateChange(authenticated);
    });
    _githubAuthController.onMyGistListChanged.listen((authenticated) {
      window.console.log('My Gist List Changed FIRED');
      _updateMyGistMenuState();
    });
    _githubAuthController.onStarredGistListChanged.listen((authenticated) {
      window.console.log('Starred Gist List Changed FIRED');
      _updateStarredGistMenuState();
    });
    _starUnstarButton.onClick
        .debounce(Duration(milliseconds: 100))
        .listen(_starredButtonClickHandler);

    // this will only happen when we make 'contenteditable' true while authenticated
    _titleElement.element.onInput
        .debounce(Duration(milliseconds: 100))
        .listen((_) {
      window.console.log('Title edited input event ${_titleElement.text}');
      _playground.mutableGist.description = _titleElement.text;
      setUnsavedLocalEdits();
    });
  }

  void _setGithubMenuItemStates(GitHubAuthenticationController githubController,
      MutableGist mutableGist) {
    final bool hasId = mutableGist.hasId;
    final bool loggedIn = githubController.userLogin.isNotEmpty;

    window.console
        .log('setGithubMenuItemStates  hasId=$hasId loggedIn=$loggedIn');

    _setMenuItemState(_githubMenuItemLogin, !loggedIn);
    _setMenuItemState(_githubMenuItemLogout, loggedIn);

    _setMenuItemState(_githubMenuItemCreatePublic,
        loggedIn /*&& !hasId*/); // now let them create public without forking
    _setMenuItemState(_githubMenuItemCreatePrivate,
        loggedIn); // let then create private gist without forking
    _setMenuItemState(_githubMenuItemFork, loggedIn && hasId);
    _setMenuItemState(_githubMenuItemUpdate, loggedIn && hasId);
    _setMenuItemState(_githubMenuItemStar, loggedIn && hasId);
    _setMenuItemState(_githubMenuItemOpenOnGithub, loggedIn && hasId);
  }

  void _updateMyGistMenuState() {
    final DivElement myGists = querySelector('#my-gists') as DivElement;
    if (_githubAuthController.myGistList.isEmpty) {
      // hide the starred gist menu
      myGists.setAttribute('hidden', true);
    } else {
      myGists.removeAttribute('hidden');
    }
    final bool firstTime = (_myGistsMenu == null);
    _myGistsMenu = _buildOrUpdateMyGistsMenu(_myGistsMenu);
    if (firstTime) {
      MDCButton(_myGistsDropdownButton)
          .onClick
          .listen((e) => Playground.toggleMenu(_myGistsMenu));
    }
  }

  void _updateStarredGistMenuState() {
    final DivElement starredGists =
        querySelector('#starred-gists') as DivElement;
    if (_githubAuthController.starredGistList.isEmpty) {
      // hide the starred gist menu
      starredGists.setAttribute('hidden', true);
    } else {
      starredGists.removeAttribute('hidden');
    }
    final bool firstTime = (_starredGistsMenu == null);
    _starredGistsMenu = _buildOrUpdateStarredGistsMenu(_starredGistsMenu);
    if (firstTime) {
      MDCButton(_starredGistsDropdownButton)
          .onClick
          .listen((e) => Playground.toggleMenu(_starredGistsMenu));
    }
  }

  void _handleGithubAuthStateChange(bool authenticated) {
    window.console.log('entering _handleGithubAuthStateChange()');

    if (_inGithubAuthStateChangeHandler) {
      window.console
          .log('ALREADY IN _handleGithubAuthStateChange() - SKIPPING !!!!');
      return;
    }
    _inGithubAuthStateChangeHandler = true;

    final String avUrl = _githubAuthController.avatarUrl;
    final String loginUser = _githubAuthController.userLogin;

    if (!_prevAuthenticationState && loginUser.isNotEmpty) {
      _playground.snackbar
          .showMessage('You are now logged into GitHub as $loginUser');
    }

    final ImageElement avatarImg =
        querySelector('#github-avatar') as ImageElement;
    if (avUrl.isNotEmpty) {
      avatarImg.src = avUrl;
      avatarImg.removeAttribute('hidden');
    } else {
      avatarImg.removeAttribute('src');
      avatarImg.setAttribute('hidden', true);
    }

    final LIElement loggedInAsLi = querySelector('#logged_in_as') as LIElement;
    final SpanElement loggedInAsText =
        querySelector('#logged_in_as_text') as SpanElement;
    if (loginUser.isNotEmpty) {
      loggedInAsText.innerText = 'Logged in as $loginUser';
      loggedInAsLi.removeAttribute('hidden');
    } else {
      loggedInAsLi.setAttribute('hidden', true);
    }

    // if we have logged out then update the gists menus (remove items/hide them)
    if (_prevAuthenticationState && !authenticated) {
      _updateStarredGistMenuState();
      _updateMyGistMenuState();
    }

    if (authenticated) {
      getStarReportOnLoadingGist(_playground.mutableGist.id ?? '');
      _titleElement.setAttr('contenteditable', 'true');
    } else {
      hideGistStarredButton();
      _titleElement.clearAttr('contenteditable');
    }

    _prevAuthenticationState = loginUser.isNotEmpty;
    _inGithubAuthStateChangeHandler = false;

    window.console.log('leaving _handleGithubAuthStateChange()');
  }

  void _attempToAquireGitHubToken() {
    // remember all of our current query params
    final Uri curUrl = Uri.parse(window.location.toString());
    final params = Map<String, String?>.from(curUrl.queryParameters);
    final String jsonParams = json.encode(params);

    window.console.log('encopded json = `$jsonParams`');

    window.localStorage['gh_pre_auth_query_params'] = jsonParams;

    // now figure out where we are going
    late final String baseUrl;
    final String ourHref = window.location.toString().toLowerCase();

    window.console.log('_attempToAquireGitHubToken  ourHref=$ourHref');

    if (ourHref.contains('localhost')) {
      // debug environment
      baseUrl = 'https://localhost:8080/initiate/';
    } else {
      baseUrl = '$_googleCloudRunUrl/initiate/';
    }
    final String redirectUrl =
        _githubAuthController.makeRandomSecureAuthInitiationUrl(baseUrl);

    window.console.log('_attempToAquireGitHubToken  redirectUrl=$redirectUrl');

    // set our window to the redirect URL and get on our way to github OAuth
    window.location.href = redirectUrl;
  }

  void _saveGist({bool public = true}) {
    final String token = _githubAuthController.githubOAuthAccessToken;
    if (token.isNotEmpty) {
      gistLoader
          .createGist(_playground.mutableGist.createGist(), public, token)
          .then((String createdGistId) {
        window.console.log('Got created Gist ID =$createdGistId');
        _playground.showOutput('Got created Gist ID =$createdGistId');
        //queryParams.gistId = createdGistId;
        _reloadPageWithNewGistId(createdGistId);
        setUnsavedLocalEdits();
        // now update our menus to reflect new gist
        _githubAuthController.updateUsersGistAndStarredGistsList();
      });
    } else {
      _playground.showSnackbar(
          'Must be authenticated with GitHub in order to save gist');
    }
  }

  void _updateGist() {
    final String token = _githubAuthController.githubOAuthAccessToken;
    if (token.isNotEmpty) {
      final Gist clonedGist = _playground.mutableGist.createGist();
      gistLoader
          .updateGist(clonedGist, token)
          .then((String updatedGistId) {
        //window.console.log('Got Updated Gist ID =$updatedGistId');
        //_playground.showOutput('Got Updated Gist ID =$updatedGistId');
        setUnsavedLocalEdits();
        _playground.showSnackbar('Gist successfully updated');
        //queryParams.gistId = forkedGistId;
        //_reloadPageWithNewGistId(updatedGistId);

        // update the backing gist because it is now in github
        _playground.mutableGist.setBackingGist(clonedGist);

        // now update our menus to reflect new gist (description could have changed)
        _githubAuthController.updateUsersGistAndStarredGistsList();
      });
    } else {
      _playground.showSnackbar(
          'Must be authenticated with GitHub in order to fork gist');
    }
  }

  void _forkGist() {
    final String token = _githubAuthController.githubOAuthAccessToken;
    final bool unsavedLocalEdits = _playground.mutableGist.dirty;
    if (token.isNotEmpty) {
      gistLoader
          .forkGist(_playground.mutableGist.createGist(), unsavedLocalEdits, token)
          .then((String forkedGistId) {

        if(forkedGistId=='GIST_ALREADY_FORK') {
          _playground.showSnackbar('Failed to fork gist - already a fork');
          return;
        } else if (forkedGistId=='GIST_NOT_FOUND') {
          _playground.showSnackbar('Failed to fork gist - gist not found');
          return;        
        }

        //window.console.log('Got Forked Gist ID =$forkedGistId');
        //_playground.showOutput('Got forked Gist ID =$forkedGistId');
        setUnsavedLocalEdits();

        _playground.showSnackbar(
           unsavedLocalEdits ? 'Gist successfully forked and updated with local edits' : 'Gist successfully forked'); // This wont have time to show KLUDGE

        //queryParams.gistId = forkedGistId;
        _reloadPageWithNewGistId(forkedGistId);

        // now update our menus to reflect new gist
        _githubAuthController.updateUsersGistAndStarredGistsList();
      });
    } else {
      _playground.showSnackbar(
          'Must be authenticated with GitHub in order to fork gist');
    }
  }

  void _reloadPageWithNewGistId(String gistId) {
    var url = Uri.parse(window.location.toString());
    final params = Map<String, String?>.from(url.queryParameters);
    params['id'] = gistId;
    url = url.replace(queryParameters: params);
    window.location.href = url.toString();
  }

  void _setMenuItemState(LIElement menuitem, bool enabled) {
    if (enabled) {
      menuitem.classes.remove('mdc-list-item--disabled');
    } else {
      menuitem.classes.add('mdc-list-item--disabled');
    }
  }

  String _truncateWithEllipsis(String text, int maxlength,
      {String ellipsis = '...'}) {
    return (text.length < maxlength)
        ? text
        : text.replaceRange(maxlength, text.length, ellipsis);
  }

  void _myGistMenuHandler(Event e) {
    final index = (e as CustomEvent).detail['index'] as int;
    window.console.log('My Gist #$index of ${_githubAuthController.myGistList.length} selected');
    final List<Gist> mygists = _githubAuthController.myGistList;
    if (index >= 0 && index <= mygists.length) {
      final gistId = mygists.elementAt(index).id!;
      _playground.showGist(gistId);
    }
  }

  MDCMenu _buildOrUpdateMyGistsMenu(MDCMenu? existingMenu) {
    window.console.log('_buildOrUpdateMyGistsMenu() entered');
    existingMenu?.destroy();

    final element = querySelector('#my-gists-menu')!;
    element.children.clear();

    final List<Gist> mygists = _githubAuthController.myGistList;

    if (mygists.isNotEmpty) {
      final listElement = _mdcList();
      element.children.add(listElement);

      for (final gist in mygists) {
        String menuTitle = gist.description ?? 'no description';
        if (menuTitle.isEmpty) menuTitle = gist.files[0].name;
        final menuElement = _mdcListItem(children: [
          SpanElement()
            ..classes.add('mdc-list-item__text')
            ..setAttribute('title', '$menuTitle (${gist.id})')
            ..text = _truncateWithEllipsis(menuTitle, 24),
        ]);
        listElement.children.add(menuElement);
      }
    }

    final mygistsMenu = MDCMenu(element)
      ..setAnchorCorner(AnchorCorner.bottomLeft)
      ..setAnchorElement(_myGistsDropdownButton)
      ..hoistMenuToBody();

    if (existingMenu == null) {
      // only add the first time, tried unlisten() at top of each creation 
      // but it did not work and resulted in multiple handlers
      mygistsMenu.listen('MDCMenu:selected', _myGistMenuHandler);
    }
    return mygistsMenu;
  }

  void _starredGistMenuHandler(Event e) {
    final index = (e as CustomEvent).detail['index'] as int;
    window.console.log('starred Gist #$index of ${_githubAuthController.starredGistList.length} selected');
    final List<Gist> starredGists = _githubAuthController.starredGistList;
    if (index >= 0 && index <= starredGists.length) {
      final gistId = starredGists.elementAt(index).id!;
      _playground.showGist(gistId);
    }
  }

  MDCMenu _buildOrUpdateStarredGistsMenu(MDCMenu? existingMenu) {
    window.console.log('_buildOrUpdateStarredGistsMenu() entered');
    existingMenu?.destroy();
    final element = querySelector('#starred-gists-menu')!;
    element.children.clear();

    final List<Gist> starredGists = _githubAuthController.starredGistList;

    if (starredGists.isNotEmpty) {
      final listElement = _mdcList();
      element.children.add(listElement);

      for (final gist in starredGists) {
        String menuTitle = gist.description ?? 'no description';
        if (menuTitle.isEmpty) menuTitle = gist.files[0].name;
        final menuElement = _mdcListItem(children: [
          SpanElement()
            ..classes.add('mdc-list-item__text')
            ..setAttribute('title', '$menuTitle (${gist.id})')
            ..text = _truncateWithEllipsis(menuTitle, 24),
        ]);
        listElement.children.add(menuElement);
        window.console.log('Added starred item $menuTitle');
      }
    }

    final starredGistsMenu = MDCMenu(element)
      ..setAnchorCorner(AnchorCorner.bottomLeft)
      ..setAnchorElement(_starredGistsDropdownButton)
      ..hoistMenuToBody();

    if (existingMenu == null) {
      // only add the first time, tried unlisten() at top of each creation 
      // but it did not work and resulted in multiple handlers
      starredGistsMenu.listen('MDCMenu:selected', _starredGistMenuHandler);
    }
    return starredGistsMenu;
  }

  /// This hides the star/not starred indicator (and toggle button)
  /// This is called by playground when loading a new gist with no-known state
  /// and it will reappear once correct state is known
  void hideGistStarredButton() {
    final SpanElement starUnstarButton =
        querySelector('#gist_star_button') as SpanElement;
    starUnstarButton.hidden = true;
  }

  void _starredButtonClickHandler(_) {
    window.console.log('Star Unstar clicked!');
    if (_starUnstarButton.hidden ||
        !_playground.mutableGist.hasId ||
        _gistIdOfLastStarredReport.isEmpty ||
        _gistIdOfLastStarredReport != _playground.mutableGist.id) {
      // do nothing, don't know state of current gist
      return;
    }
    final String gistIdWeAreToggling = _gistIdOfLastStarredReport;
    // clear until we report back (prevents another click until done)
    _gistIdOfLastStarredReport = '';
    if (!_starredStateOfLastStarReport) {
      // immediately set state to where we think it's going, and we will update after we get
      // verification from API
      _setStateOfStarredButton(true);
      gistLoader
          .starGist(
              gistIdWeAreToggling, _githubAuthController.githubOAuthAccessToken)
          .then((_) {
        window.console.log('starGist.then()...');
        getStarReportOnLoadingGist(gistIdWeAreToggling, true);
        // now update our menus to reflect change in starred gists
        _githubAuthController.updateUsersGistAndStarredGistsList(starredCheckDelay:60000);
      });
    } else {
      // immediately set state to where we think it's going, and we will update after we get
      // verification from API
      _setStateOfStarredButton(false);
      gistLoader
          .unstarGist(
              gistIdWeAreToggling, _githubAuthController.githubOAuthAccessToken)
          .then((_) {
        window.console.log('unstarGist.then()...');
        getStarReportOnLoadingGist(gistIdWeAreToggling, true);
        // now update our menus to reflect change in starred gists
        _githubAuthController.updateUsersGistAndStarredGistsList(starredCheckDelay:60000);
      });
    }
  }

  void _setStateOfStarredButton(bool starred) {
    _starUnstarButton.hidden = false;
    if (starred) {
      // title bar gist star indicator
      _starIconHolder.innerText = 'star';
      _starUnstarButton.title = 'Click to Unstar this gist';
      // menu item star gist action
      _starMenuIconHolder.innerText = 'star_outline';
      _starMenuItemText.innerText = 'Unstar Gist';
    } else {
      // title bar gist star indicator
      _starIconHolder.innerText = 'star_outline';
      _starUnstarButton.title = 'Click to Star this gist';
      // menu item star gist action
      _starMenuIconHolder.innerText = 'star';
      _starMenuItemText.innerText = 'Star Gist';
    }
  }

  /// Request a report on the state of this Gist's star status for the
  /// currently authenticated user, updates UI once known
  void getStarReportOnLoadingGist(String gistId,
      [bool dontHideStarButton = false]) {
    if (!dontHideStarButton) hideGistStarredButton();
    if (_githubAuthController.githubOAuthAccessToken.isNotEmpty &&
        gistId.isNotEmpty) {
      _gistIdOfLastStarredReport = '';
      gistLoader
          .checkIfGistIsStarred(
              gistId, _githubAuthController.githubOAuthAccessToken)
          .then((starred) {
        window.console.log(
            'check of STAR RETURNED On THEN  gistId=$gistId starred=$starred');
        _gistIdOfLastStarredReport = gistId;
        _starredStateOfLastStarReport = starred;
        _setStateOfStarredButton(starred);
      });
    }
  }

  UListElement _mdcList() => UListElement()
    ..classes.add('mdc-list')
    ..attributes.addAll({
      'aria-hidden': 'true',
      'aria-orientation': 'vertical',
      'tabindex': '-1'
    });

  LIElement _mdcListItem({List<Element> children = const []}) {
    final element = LIElement()
      ..classes.add('mdc-list-item')
      ..attributes.addAll({'role': 'menuitem'});
    for (final child in children) {
      element.children.add(child);
    }
    return element;
  }
}

/// This handles interacting with our authentication initiation endpoint and
/// interacting with GitHub API endpoints for getting user info.
/// (The process of initiating and interacting with GitHub OAuth server
/// must happen from the server.  Known secrets must be preserved there
/// and cannot exist on the client side).
class GitHubAuthenticationController {
  static const String _githubApiUrl = 'https://api.github.com';
  final Uri launchUri;
  late final http.Client _client;
  final MDCSnackbar snackbar;

  final _authenticatedStateChangeController =
      StreamController<bool>.broadcast();
  final _myGistListUpdateController = StreamController.broadcast();
  final _starredGistListUpdateController = StreamController.broadcast();
  final _gistStarredCheckerReportController = StreamController.broadcast();

  Stream<bool> get onAuthStateChanged =>
      _authenticatedStateChangeController.stream;

  Stream get onMyGistListChanged => _myGistListUpdateController.stream;
  Stream get onStarredGistListChanged =>
      _starredGistListUpdateController.stream;
  Stream get onGistStarredCheckerReport =>
      _gistStarredCheckerReportController.stream;

  final List<Gist> _myGistList = [];
  final List<Gist> _starredGistList = [];

  List<Gist> get myGistList => _myGistList;
  List<Gist> get starredGistList => _starredGistList;

  String? _pendingUserInfoRequest;
  String? _pendingUserGistRequest;
  String? _pendingUserStarredGistRequest;

  GitHubAuthenticationController(this.launchUri, this.snackbar,
      {http.Client? client}) {
    // check for parameters in rui
    _client = client ?? http.Client();

    final params = Map<String, String?>.from(launchUri.queryParameters);
    final String ghTokenFromUrl = params['gh'] ?? '';
    final String ghScope = params['scope'] ?? '';

    // debug
    window.console
        .log('GitHubLoginController() Launch URI  ${launchUri.toString()}');
    params.forEach((key, value) {
      window.console.log('  param $key = "$value"');
    });

    if (ghTokenFromUrl.isNotEmpty) {
      final String perAuthParamsJson =
          window.localStorage['gh_pre_auth_query_params'] ?? '';

      window.console.log('from localStorage param json = `$perAuthParamsJson`');

      try {
        final jdec = json.decode(perAuthParamsJson);

        window.console.log('jdec = ${jdec.toString()}');
      } catch (e) {
        window.console.log('Caught exception ${e.toString()}');
      }
      try {
        final restoreParams = Map<String, String?>.from(
            json.decode(perAuthParamsJson) as Map<dynamic, dynamic>);

        final Uri restoredUrl =
            launchUri.replace(queryParameters: restoreParams);
        window.history.replaceState({}, 'DartPad', restoredUrl.toString());

        window.console.log('Restored URL is now ${restoredUrl.toString()}');
      } catch (e) {
        window.console
            .log('Caught doing restoreParams exception ${e.toString()}');
      }

      if (ghTokenFromUrl == 'noauth' || ghTokenFromUrl == 'authfailed') {
        // ERROR was encountered during trip to GH auth
        snackbar.showMessage('Error encountered during GitHub OAuth Request');
        return;
      }
      if (!ghScope.contains('gists')) {
        // give error message but continue in this case
        snackbar.showMessage(
            'Error: The scope "gists" was not included with the GitHub OAuth Token');
      }

      // now decrypt the GH token and try and init user
      final String ghAuthToken =
          decryptAuthTokenFromReturnedSecureAuthToken(ghTokenFromUrl);

      window.console.log('Post decrypt the ghAuthToken=$ghAuthToken');

      // set provided a gh token, if new this will do query on user info
      githubOAuthAccessToken = ghAuthToken;
    } else {
      // There was no gh token in the window URL, but we may have STORED GH authorization
      // in local storage...
      // so trigger an authentication state change anyway
      window.console.log(
          'No GH query param but do we have a STORED local storage token ?');
      window.console.log('githubOAuthAccessToken = $githubOAuthAccessToken');
    }
  }

  void postCreationFireAutheticatedStateChangeEvent() {
    _authenticatedStateChangeController.add(githubOAuthAccessToken != '');
    updateUsersGistAndStarredGistsList();
  }


  Timer? starGistsChecklDelayTimer;

  void updateUsersGistAndStarredGistsList({int starredCheckDelay=100}) {
    // Now go and get the lists of user's gists and starred gists
    window.console.log('updateUsersGistAndStarredGistsList calling getUsersGists');
    getUsersGists();

    // Github takes a while to update the returned list of starred gists
    // after a star/unstar operation, so in those cases we wait
    // and extra amount of time - 60seconds ? long enough?
    starGistsChecklDelayTimer?.cancel();
    starGistsChecklDelayTimer = Timer(Duration(milliseconds: starredCheckDelay), () {
        window.console.log('updateUsersGistAndStarredGistsList calling getUsersStarredGists after waiting $starredCheckDelay milliseconds');
        getUsersStarredGists();
      });
  }

  void logoutUnauthenticate() {
    _myGistList.clear();
    _starredGistList.clear();
    avatarUrl = '';
    userLogin = '';
    // set auth token last as it will fire event
    githubOAuthAccessToken = '';
    _authenticatedStateChangeController.add(false);
  }

  bool get authenticated {
    return (githubOAuthAccessToken != '');
  }

  /*
    GET /user

    Parameters
    Name      Type      In      Description
    accept   string   header    Setting toapplication/vnd.github.v3+json is recommended.

    https://docs.github.com/en/rest/reference/users#get-the-authenticated-user

    example of PUBLIC returned data
    {
      "login": "octocat",
      "id": 1,
      "node_id": "MDQ6VXNlcjE=",
      "avatar_url": "https://github.com/images/error/octocat_happy.gif",
      "gravatar_id": "",
      "url": "https://api.github.com/users/octocat",
      ....
      "type": "User",
      "site_admin": false,
      "name": "monalisa octocat",
      "company": "GitHub",
      "blog": "https://github.com/blog",
      "location": "San Francisco",
      "email": "octocat@github.com",
      "hireable": false,
      "bio": "There once was...",
      "twitter_username": "monatheoctocat",
      "public_repos": 2,
      "public_gists": 1,
      "followers": 20,
      "following": 0,
      "created_at": "2008-01-14T04:33:35Z",
      "updated_at": "2008-01-14T04:33:35Z"
    }
  */
  Future<void> getUserInfo() async {
    final String accessToken = githubOAuthAccessToken;

    window.console.log('getUserInfo  accessToken=$accessToken');

    if (accessToken.isEmpty) return;

    if (_pendingUserInfoRequest == accessToken) {
      // already processing a request
      window.console.log('getUserInfo DUPLICATE - skipping');
      return;
    }
    _pendingUserInfoRequest = accessToken;

    // Load the gist using the github gist API:
    // https://developer.github.com/v3/gists/#get-a-single-gist.
    return _client.get(Uri.parse('$_githubApiUrl/user'), headers: {
      'accept': 'application/vnd.github.v3+json',
      'Authorization': 'token $accessToken'
    }).then((response) {
      _pendingUserInfoRequest = null;
      window.console.log('getUserInfo() get reponsestatusCode=${response.statusCode}');

      if (response.statusCode == 404) {
        throw const GistLoaderException(GistLoaderFailureType.contentNotFound);
      } else if (response.statusCode == 403) {
        throw const GistLoaderException(
            GistLoaderFailureType.rateLimitExceeded);
      } else if (response.statusCode != 200) {
        throw const GistLoaderException(GistLoaderFailureType.unknown);
      } else {
        // statusCode 200
        final user = json.decode(response.body) as Map<String, dynamic>;

        window.console.log('user data ${user.toString()}');
        window.console.log('avatarURL= ${user['avatar_url']}');

        if (user.containsKey('avatar_url')) {
          avatarUrl = user['avatar_url'] as String;
        }
        if (user.containsKey('login')) {
          userLogin = user['login'] as String;
        }
        _authenticatedStateChangeController.add(true);
      }
    });
  }

  /*
      GET /gists

      Parameters
      Name      Type      In        Description
      accept   string    header     Setting toapplication/vnd.github.v3+json is recommended.
      since    string    query      Only show notifications updated after the given time. This is a timestamp in ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ.
      per_page integer   query      Results per page (max 100)   Default: 30
      page     integer   query      Page number of the results to fetch.  Default: 1

      https://docs.github.com/en/rest/reference/gists#list-gists-for-the-authenticated-user

      Example Return:
      [
        {
          "url": "https://api.github.com/gists/aa5a315d61ae9438b18d",
          ....
          "id": "aa5a315d61ae9438b18d",
          ....
          "files": {
            "hello_world.rb": {
              "filename": "hello_world.rb",
              "type": "application/x-ruby",
              "language": "Ruby",
              "raw_url": "https://gist.githubusercontent.com/octocat/6cad326836d38bd3a7ae/raw/db9c55113504e46fa076e7df3a04ce592e2e86d8/hello_world.rb",
              "size": 167
            }
          },
          "public": true,
          "created_at": "2010-04-14T02:15:15Z",
          "updated_at": "2011-06-20T11:34:15Z",
          "description": "Hello World Examples",
          "comments": 0,
          "user": null,
          "comments_url": "https://api.github.com/gists/aa5a315d61ae9438b18d/comments/",
          "owner": {
            ....
          },
          "truncated": false
        }
      ]
  */
  Future<void> getUsersGists() async {
    final String accessToken = githubOAuthAccessToken;

    window.console.log('getUsersGists  accessToken=$accessToken');

    if (accessToken.isEmpty) return;

    if (_pendingUserGistRequest == accessToken) {
      // already processing a request
      window.console.log('getUsersGists DUPLICATE - skipping');
      return;
    }
    _pendingUserGistRequest = accessToken;

    // Load the gist using the github gist API:
    // https://developer.github.com/v3/gists/#get-a-single-gist.
    return _client
        .get(Uri.parse('$_githubApiUrl/gists?per_page=100'), headers: {
      'accept': 'application/vnd.github.v3+json',
      'Authorization': 'token $accessToken'
    }).then((response) {
      _pendingUserGistRequest = null;
      window.console.log('getUsersGists() reponsestatusCode=${response.statusCode}');

      if (response.statusCode == 404) {
        throw const GistLoaderException(GistLoaderFailureType.contentNotFound);
      } else if (response.statusCode == 403) {
        throw const GistLoaderException(
            GistLoaderFailureType.rateLimitExceeded);
      } else if (response.statusCode != 200) {
        throw const GistLoaderException(GistLoaderFailureType.unknown);
      } else {
        // statusCode 200
        //window.console.log('raw gistList JSON ${response.body}');
        _myGistList.clear();
        final List<dynamic> gistslist =
            json.decode(response.body) as List<dynamic>;

        //window.console.log('SUCCESS gist list gistslist.length ${gistslist.length}');
        if (gistslist.isNotEmpty) {
          //window.console.log('gist list data ${gistslist.toString()}');
          for (int i = 0; i < gistslist.length; i++) {
            // Now decode each one
            //window.console.log('GIST #$i');
            //window.console.log('gistslist[i]=${gistslist[i].toString()}');
            final gist = Gist.fromMap(gistslist[i] as Map<String, dynamic>);

            //window.console.log('CREATED OBJECT GIST #$i ::::');
            //window.console.log('${gist.toJson()}');
            if (gist.hasDartContent()) {
              _myGistList.add(gist);
            }
          }
          window.console.log('Gist WITH DART = _myGistList.length ${_myGistList.length}');
        }
        _myGistListUpdateController.add(null);
      }
    });
  }

  /*
    List the authenticated user's starred gists:

    GET /gists/starred

    (otherwise this api entry point works same as get user's gists)

    https://docs.github.com/en/rest/reference/gists#list-starred-gists
  */
  Future<void> getUsersStarredGists() async {
    final String accessToken = githubOAuthAccessToken;

    window.console.log('getUsersStarredGists  accessToken=$accessToken');

    if (accessToken.isEmpty) return;

    if (_pendingUserStarredGistRequest == accessToken) {
      // already processing a request
      window.console.log('getUsersStarredGists DUPLICATE - skipping');
      return;
    }
    _pendingUserStarredGistRequest = accessToken;

    // Load the gist using the github gist API:
    // https://developer.github.com/v3/gists/#get-a-single-gist.
    return _client
        .get(Uri.parse('$_githubApiUrl/gists/starred?per_page=100'), headers: {
      'accept': 'application/vnd.github.v3+json',
      'Authorization': 'token $accessToken'
    }).then((response) {
      _pendingUserStarredGistRequest = null;
      window.console.log('getUsersStarredGists() reponsestatusCode=${response.statusCode}');

      if (response.statusCode == 404) {
        throw const GistLoaderException(GistLoaderFailureType.contentNotFound);
      } else if (response.statusCode == 403) {
        throw const GistLoaderException(
            GistLoaderFailureType.rateLimitExceeded);
      } else if (response.statusCode != 200) {
        throw const GistLoaderException(GistLoaderFailureType.unknown);
      } else {
        // statusCode 200
        //window.console.log('raw gistList JSON ${response.body}');
        _starredGistList.clear();
        final List<dynamic> gistslist =
            json.decode(response.body) as List<dynamic>;

        //window.console.log('SUCCESS starred gist list gistslist.length ${gistslist.length}');
        if (gistslist.isNotEmpty) {
          //window.console.log('starred gist list data ${gistslist.toString()}');

          for (int i = 0; i < gistslist.length; i++) {
            // Now decode each one
            //window.console.log('STARRED GIST #$i');

            //window.console.log('gistslist[i]=${gistslist[i].toString()}');

            final gist = Gist.fromMap(gistslist[i] as Map<String, dynamic>);

            //window.console.log('CREATED OBJECT GIST #$i ::::');
            //window.console.log('${gist.toJson()}');

            if (gist.hasDartContent()) {
              _starredGistList.add(gist);
            }
          }
          window.console.log('STARRED Gist WITH DART = _starredGistList.length ${_starredGistList.length}');
        }
        _starredGistListUpdateController.add(null);
      }
    });
  }

  set githubOAuthAccessToken(String newtoken) {
    window.console.log('Setting access token to $newtoken');
    if (window.localStorage['github_oauth_token'] != newtoken) {
      if (newtoken.isNotEmpty) {
        window.console.log('putting into local storage');
        window.localStorage['github_oauth_token'] = newtoken;
        // get the user info for this token
        window.console.log('calling getUserInfo');
        getUserInfo();
      } else {
        window.localStorage.remove('github_oauth_token');
        avatarUrl = '';
        userLogin = '';
      }
    }
  }

  String get githubOAuthAccessToken =>
      window.localStorage['github_oauth_token'] ?? '';

  set avatarUrl(String url) {
    window.console.log('setting avatar url to $url');
    if (url.isNotEmpty) {
      window.localStorage['github_avatar_url'] = url;
    } else {
      window.localStorage.remove('github_avatar_url');
    }
  }

  String get avatarUrl => window.localStorage['github_avatar_url'] ?? '';

  set userLogin(String login) {
    window.console.log('setting login to $login');
    if (login.isNotEmpty) {
      window.localStorage['github_user_login'] = login;
    } else {
      window.localStorage.remove('github_user_login');
    }
    //KLUDGE//_authenticatedStateChangeController.add(login.isNotEmpty);
  }

  String get userLogin => window.localStorage['github_user_login'] ?? '';

  static const _chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  final Random _rnd = Random.secure();

  String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  String makeRandomSecureAuthInitiationUrl(String baseUrl) {
    // create random state string which will be used by GH OAuth and then by
    // us to encrypt returned gh auth token
    final String state = getRandomString(40);

    // Store state in localStorage, because we are going to need it to Decrypt
    // the returned authorization token
    window.localStorage['github_random_state'] = state;

    if (baseUrl.endsWith('/')) {
      return '$baseUrl$state';
    } else {
      return '$baseUrl/$state';
    }
  }

  String decryptAuthTokenFromReturnedSecureAuthToken(
      String encryptedBase64AuthToken) {
    // retrieve the random state string we made for the original request in
    // makeRandomSecureAuthInitiationUrl().  Our auth token was encrypted using
    // this before sending it back to us, so use it to decrypt
    final String randomStateWeSent =
        window.localStorage['github_random_state'] ?? '';

    try {
      if (randomStateWeSent.isEmpty) {
        return 'ERROR-no stored initial state';
      }

      final iv = IV.fromUtf8(randomStateWeSent.substring(0, 8));
      final key = Key.fromUtf8(randomStateWeSent.substring(8, 40));
      final sasla = Salsa20(key);
      final encrypter = Encrypter(sasla);

      final encryptedToken =
          Encrypted.from64(Uri.decodeComponent(encryptedBase64AuthToken));

      final decryptedAuthToken = encrypter.decrypt(encryptedToken, iv: iv);

      return decryptedAuthToken;
    } catch (e) {
      window.console.log('CAUGHT EXCEPTION e=${e.toString()}');
    }
    return 'ERROR';
  }
}

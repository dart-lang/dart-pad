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

const localStorageKeyForGitHubRandomState = 'github_random_state';
const localStorageKeyForGitHubAvatarUrl = 'github_avatar_url';
const localStorageKeyForQueryParamsPreOAuthRequest = 'gh_pre_auth_query_params';
const localStorageKeyForGitHubOAuthToken = 'github_oauth_token';
const localStorageKeyForGitHubUserLogin = 'github_user_login';

class GitHubUIController {
  static const entryPointGitHubOAuthInitiate = 'github_oauth_initiate';

  final Playground _playground;
  late final GitHubAuthenticationController _githubAuthController;

  final _githubMenuItemLogin = querySelector('#github-login-item') as LIElement;
  final _githubMenuItemCreatePublic =
      querySelector('#github-createpublic-item') as LIElement;
  final _githubMenuItemCreatePrivate =
      querySelector('#github-createprivate-item') as LIElement;
  final _githubMenuItemFork = querySelector('#github-fork-item') as LIElement;
  final _githubMenuItemUpdate =
      querySelector('#github-update-item') as LIElement;
  final _githubMenuItemStar = querySelector('#github-star-item') as LIElement;
  final _githubMenuItemOpenOnGithub =
      querySelector('#github-open-on-github-item') as LIElement;
  final _githubMenuItemLogout =
      querySelector('#github-logout-item') as LIElement;
  final _starUnstarButton = querySelector('#gist_star_button') as SpanElement;
  final Element _starIconHolder = querySelector('#gist_star_inner_icon')!;
  final Element _starMenuIconHolder =
      querySelector('#github-star-item .mdc-select__icon')!;
  final _starMenuItemText =
      querySelector('#github-star-item .mdc-list-item__text') as SpanElement;
  final _titleElement = DElement(querySelector('header .header-gist-name')!);
  final _myGistsDropdownButton =
      querySelector('#my-gists-dropdown-button') as ButtonElement;
  final _starredGistsDropdownButton =
      querySelector('#starred-gists-dropdown-button') as ButtonElement;

  MDCMenu? _starredGistsMenu;
  MDCMenu? _myGistsMenu;

  bool _prevAuthenticationState = false;

  bool _inGithubAuthStateChangeHandler = false;

  String _gistIdOfLastStarredReport = '';
  bool _starredStateOfLastStarReport = false;

  GitHubUIController(this._playground) {
    _githubAuthController = GitHubAuthenticationController(
        Uri.parse(window.location.toString()), _playground.snackbar);
    initGitHubMenu();
    setupGithubGistListeners();

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
          _attemptToAquireGitHubToken();
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
          // And in 10 seconds check with github and update our my gists and starred menus.
          // This is just another wait to force a check with github to sync
          // our menus up.  (The long delay in starred API results updating can be frustrating
          // on the client end waiting for the github server to report the change).
          _githubAuthController.updateUsersGistAndStarredGistsList(
              starredCheckDelay: 10000);
          break;
        case 7: //logout
          _githubAuthController.logoutUnauthenticate();
          break;
      }
    });
  }

  void setUnsavedLocalEdits([bool unsavedLocalEdits = false]) {
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
      setUnsavedLocalEdits();
    });
    _playground.mutableGist.property('id').onChanged!.listen((_) {
      // The gist Id has changed.
      _setGithubMenuItemStates(_githubAuthController, _playground.mutableGist);
    });
    _githubAuthController.onAuthStateChanged.listen((authenticated) {
      _setGithubMenuItemStates(_githubAuthController, _playground.mutableGist);
      _handleGithubAuthStateChange(authenticated);
    });
    _githubAuthController.onMyGistListChanged.listen((authenticated) {
      _updateMyGistMenuState();
    });
    _githubAuthController.onStarredGistListChanged.listen((authenticated) {
      _updateStarredGistMenuState();
    });
    _starUnstarButton.onClick
        .debounce(Duration(milliseconds: 100))
        .listen(_starredButtonClickHandler);

    // This will only happen when we make 'contenteditable' true while authenticated.
    _titleElement.element.onInput
        .debounce(Duration(milliseconds: 100))
        .listen((_) {
      _playground.mutableGist.description = _titleElement.text;
      setUnsavedLocalEdits();
    });
  }

  void _setGithubMenuItemStates(GitHubAuthenticationController githubController,
      MutableGist mutableGist) {
    final bool hasId = mutableGist.hasId;
    final bool loggedIn = githubController.userLogin.isNotEmpty;

    _setMenuItemState(_githubMenuItemLogin, !loggedIn);
    _setMenuItemState(_githubMenuItemLogout, loggedIn);

    _setMenuItemState(_githubMenuItemCreatePublic,
        loggedIn /*&& !hasId*/); // Now let them create public without forking, uncomment `** hasId` for force forking.
    _setMenuItemState(_githubMenuItemCreatePrivate,
        loggedIn); // Let then create private gist without forking.
    _setMenuItemState(_githubMenuItemFork, loggedIn && hasId);
    _setMenuItemState(_githubMenuItemUpdate, loggedIn && hasId);
    _setMenuItemState(_githubMenuItemStar, loggedIn && hasId);
    _setMenuItemState(_githubMenuItemOpenOnGithub, loggedIn && hasId);
  }

  void _updateMyGistMenuState() {
    final DivElement myGists = querySelector('#my-gists') as DivElement;
    if (_githubAuthController.myGistList.isEmpty) {
      // Hide the starred gist menu.
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
      // Hide the starred gist menu.
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
    if (_inGithubAuthStateChangeHandler) {
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

    // If we have logged out then update the gists menus (remove items/hide them).
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
  }

  void _attemptToAquireGitHubToken() {
    // Remember all of our current query params.
    final Uri curUrl = Uri.parse(window.location.toString());
    final params = Map<String, String?>.from(curUrl.queryParameters);
    final String jsonParams = json.encode(params);

    window.localStorage[localStorageKeyForQueryParamsPreOAuthRequest] =
        jsonParams;

    // Use current dartServices root url and add the GitHub OAuth initiation
    // end point to it.
    final String baseUrl =
        '${dartServices.rootUrl}$entryPointGitHubOAuthInitiate/';

    final String redirectUrl =
        _githubAuthController.makeRandomSecureAuthInitiationUrl(baseUrl);
    // Set our window to the redirect URL and get on our way to github OAuth.
    window.location.href = redirectUrl;
  }

  void _saveGist({bool public = true}) {
    final String token = _githubAuthController.githubOAuthAccessToken;
    if (token.isNotEmpty) {
      gistLoader
          .createGist(_playground.mutableGist.createGist(), public, token)
          .then((String createdGistId) {
        _reloadPageWithNewGistId(createdGistId);
        setUnsavedLocalEdits();
        // Now update our menus to reflect new gist.
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
      gistLoader.updateGist(clonedGist, token).then((String updatedGistId) {
        setUnsavedLocalEdits();
        _playground.showSnackbar('Gist successfully updated');

        // Update the backing gist because it is now in github.
        _playground.mutableGist.setBackingGist(clonedGist);

        // Now update our menus to reflect new gist (description could have changed).
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
          .forkGist(
              _playground.mutableGist.createGist(), unsavedLocalEdits, token)
          .then((String forkedGistId) {
        if (forkedGistId == GistLoader.gistAlreadyForked) {
          _playground.showSnackbar('Failed to fork gist - already a fork');
          return;
        } else if (forkedGistId == GistLoader.gistNotFound) {
          _playground.showSnackbar('Failed to fork gist - gist not found');
          return;
        }

        setUnsavedLocalEdits();

        _playground.showSnackbar(unsavedLocalEdits
            ? 'Gist successfully forked and updated with local edits'
            : 'Gist successfully forked'); // This wont have time to show KLUDGE

        _reloadPageWithNewGistId(forkedGistId);

        // Now update our menus to reflect new gist.
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
    final mygists = _githubAuthController.myGistList;
    if (index >= 0 && index <= mygists.length) {
      final gistId = mygists.elementAt(index).id!;
      _playground.showGist(gistId);
    }
  }

  MDCMenu _buildOrUpdateMyGistsMenu(MDCMenu? existingMenu) {
    existingMenu?.destroy();

    final element = querySelector('#my-gists-menu')!;
    element.children.clear();

    final List<Gist> mygists = _githubAuthController.myGistList;

    if (mygists.isNotEmpty) {
      final listElement = _mdcList();
      element.children.add(listElement);

      for (final gist in mygists) {
        var menuTitle = gist.description ?? 'no description';
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
      // Only add the first time, tried unlisten() at top of each creation
      // but it did not work and resulted in multiple handlers.
      mygistsMenu.listen('MDCMenu:selected', _myGistMenuHandler);
    }
    return mygistsMenu;
  }

  void _starredGistMenuHandler(Event e) {
    final index = (e as CustomEvent).detail['index'] as int;
    final List<Gist> starredGists = _githubAuthController.starredGistList;
    if (index >= 0 && index <= starredGists.length) {
      final gistId = starredGists.elementAt(index).id!;
      _playground.showGist(gistId);
    }
  }

  MDCMenu _buildOrUpdateStarredGistsMenu(MDCMenu? existingMenu) {
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
      }
    }

    final starredGistsMenu = MDCMenu(element)
      ..setAnchorCorner(AnchorCorner.bottomLeft)
      ..setAnchorElement(_starredGistsDropdownButton)
      ..hoistMenuToBody();

    if (existingMenu == null) {
      // Only add the first time, tried unlisten() at top of each creation
      // but it did not work and resulted in multiple handlers.
      starredGistsMenu.listen('MDCMenu:selected', _starredGistMenuHandler);
    }
    return starredGistsMenu;
  }

  /// This hides the star/not starred indicator (and toggle button).
  /// This is called by playground when loading a new gist with no-known state
  /// and it will reappear once correct state is known.
  void hideGistStarredButton() {
    final SpanElement starUnstarButton =
        querySelector('#gist_star_button') as SpanElement;
    starUnstarButton.hidden = true;
  }

  void _starredButtonClickHandler(_) {
    if (_starUnstarButton.hidden ||
        !_playground.mutableGist.hasId ||
        _gistIdOfLastStarredReport.isEmpty ||
        _gistIdOfLastStarredReport != _playground.mutableGist.id) {
      // Do nothing, don't know state of current gist.
      return;
    }
    final String gistIdWeAreToggling = _gistIdOfLastStarredReport;
    // Clear until we report back (prevents another click until done).
    _gistIdOfLastStarredReport = '';
    if (!_starredStateOfLastStarReport) {
      // Immediately set state to where we think it's going, and we will update
      // after we get verification from API.
      _setStateOfStarredButton(true);
      gistLoader
          .starGist(
              gistIdWeAreToggling, _githubAuthController.githubOAuthAccessToken)
          .then((_) {
        getStarReportOnLoadingGist(gistIdWeAreToggling, true);
        // Now update our menus to reflect change in starred gists.
        _githubAuthController.updateUsersGistAndStarredGistsList(
            starredCheckDelay: 60000);
      });
    } else {
      // Immediately set state to where we think it's going, and we will update
      // after we get verification from API.
      _setStateOfStarredButton(false);
      gistLoader
          .unstarGist(
              gistIdWeAreToggling, _githubAuthController.githubOAuthAccessToken)
          .then((_) {
        getStarReportOnLoadingGist(gistIdWeAreToggling, true);
        // Now update our menus to reflect change in starred gists.
        _githubAuthController.updateUsersGistAndStarredGistsList(
            starredCheckDelay: 60000);
      });
    }
  }

  void _setStateOfStarredButton(bool starred) {
    _starUnstarButton.hidden = false;
    if (starred) {
      // Title bar gist star indicator.
      _starIconHolder.innerText = 'star';
      _starUnstarButton.title = 'Click to Unstar this gist';
      // Menu item star gist action.
      _starMenuIconHolder.innerText = 'star_outline';
      _starMenuItemText.innerText = 'Unstar Gist';
    } else {
      // Title bar gist star indicator.
      _starIconHolder.innerText = 'star_outline';
      _starUnstarButton.title = 'Click to Star this gist';
      // Menu item star gist action.
      _starMenuIconHolder.innerText = 'star';
      _starMenuItemText.innerText = 'Star Gist';
    }
  }

  /// Request a report on the state of this Gist's star status for the
  /// currently authenticated user, updates UI once known.
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
  static const int maxNumberOfGistToLoad = 100;
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
    // Check for parameters in query uri.
    _client = client ?? http.Client();

    final params = Map<String, String?>.from(launchUri.queryParameters);
    final String ghTokenFromUrl = params['gh'] ?? '';
    final String ghScope = params['scope'] ?? '';

    if (ghTokenFromUrl.isNotEmpty) {
      final String perAuthParamsJson =
          window.localStorage[localStorageKeyForQueryParamsPreOAuthRequest] ??
              '';

      try {
        final restoreParams = Map<String, String?>.from(
            json.decode(perAuthParamsJson) as Map<dynamic, dynamic>);

        final Uri restoredUrl =
            launchUri.replace(queryParameters: restoreParams);
        window.history.replaceState({}, 'DartPad', restoredUrl.toString());
      } catch (e) {
        window.console
            .log('Caught doing restoreParams exception ${e.toString()}');
      }

      if (ghTokenFromUrl == 'noauth' || ghTokenFromUrl == 'authfailed') {
        // ERROR was encountered during trip to GH auth.
        snackbar.showMessage('Error encountered during GitHub OAuth Request');
        return;
      }
      if (!ghScope.contains('gists')) {
        // Give error message but continue in this case.
        snackbar.showMessage(
            'Error: The scope "gists" was not included with the GitHub OAuth Token');
      }

      // Now decrypt the GH token and try and init user.
      final String ghAuthToken =
          decryptAuthTokenFromReturnedSecureAuthToken(ghTokenFromUrl);

      // Set provided a gh token, if new this will do query on user info.
      githubOAuthAccessToken = ghAuthToken;
    } else {
      // There was no gh token in the window URL, but we may have STORED GH
      // authorization in local storage... so we trigger an authentication state change anyway.
    }
  }

  void postCreationFireAutheticatedStateChangeEvent() {
    _authenticatedStateChangeController.add(githubOAuthAccessToken != '');
    updateUsersGistAndStarredGistsList();
  }

  Timer? starGistsChecklDelayTimer;

  void updateUsersGistAndStarredGistsList({int starredCheckDelay = 100}) {
    // Now go and get the lists of user's gists and starred gists.
    getUsersGists();

    // Github takes a while to update the returned list of starred gists
    // after a star/unstar operation, so in those cases we wait
    // and extra amount of time... - 60seconds ? long enough?
    starGistsChecklDelayTimer?.cancel();
    starGistsChecklDelayTimer =
        Timer(Duration(milliseconds: starredCheckDelay), () {
      getUsersStarredGists();
    });
  }

  void logoutUnauthenticate() {
    _myGistList.clear();
    _starredGistList.clear();
    avatarUrl = '';
    userLogin = '';
    // Set auth token last as it will fire event.
    githubOAuthAccessToken = '';
    _authenticatedStateChangeController.add(false);
  }

  bool get authenticated {
    return (githubOAuthAccessToken != '');
  }

  /*
    Request user info from GitHub API.
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

    if (accessToken.isEmpty) return;

    if (_pendingUserInfoRequest == accessToken) {
      // Already processing a request.
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

      if (response.statusCode == 404) {
        throw const GistLoaderException(GistLoaderFailureType.contentNotFound);
      } else if (response.statusCode == 403) {
        throw const GistLoaderException(
            GistLoaderFailureType.rateLimitExceeded);
      } else if (response.statusCode != 200) {
        throw const GistLoaderException(GistLoaderFailureType.unknown);
      } else {
        // statusCode 200.
        final user = json.decode(response.body) as Map<String, dynamic>;
        if (user.containsKey('avatar_url')) {
          avatarUrl = user['avatar_url'] as String;
        }
        if (user.containsKey('login')) {
          userLogin = user['login'] as String;
        }
        _authenticatedStateChangeController.add(true);
      }
    }).catchError((e) {
      window.console.log('getUserInfo Exception ${e.toString()}');
    });
  }

  /*
      Request user's gist info from GitHub API.
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

    if (accessToken.isEmpty) return;

    if (_pendingUserGistRequest == accessToken) {
      // Already processing a request.
      return;
    }
    _pendingUserGistRequest = accessToken;

    // Load the gist using the github gist API:
    // https://developer.github.com/v3/gists/#get-a-single-gist.
    return _client.get(
        Uri.parse('$_githubApiUrl/gists?per_page=$maxNumberOfGistToLoad'),
        headers: {
          'accept': 'application/vnd.github.v3+json',
          'Authorization': 'token $accessToken'
        }).then((response) {
      _pendingUserGistRequest = null;

      if (response.statusCode == 404) {
        throw const GistLoaderException(GistLoaderFailureType.contentNotFound);
      } else if (response.statusCode == 403) {
        throw const GistLoaderException(
            GistLoaderFailureType.rateLimitExceeded);
      } else if (response.statusCode != 200) {
        throw const GistLoaderException(GistLoaderFailureType.unknown);
      } else {
        // StatusCode 200.
        _myGistList.clear();
        final List<dynamic> gistslist =
            json.decode(response.body) as List<dynamic>;

        if (gistslist.isNotEmpty) {
          for (int i = 0; i < gistslist.length; i++) {
            // Now decode each one.
            final gist = Gist.fromMap(gistslist[i] as Map<String, dynamic>);
            if (gist.hasDartContent()) {
              _myGistList.add(gist);
            }
          }
        }
        _myGistListUpdateController.add(null);
      }
    }).catchError((e) {
      window.console.log('getUsersGists Exception ${e.toString()}');
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

    if (accessToken.isEmpty) return;

    if (_pendingUserStarredGistRequest == accessToken) {
      // Already processing a request.
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

      if (response.statusCode == 404) {
        throw const GistLoaderException(GistLoaderFailureType.contentNotFound);
      } else if (response.statusCode == 403) {
        throw const GistLoaderException(
            GistLoaderFailureType.rateLimitExceeded);
      } else if (response.statusCode != 200) {
        throw const GistLoaderException(GistLoaderFailureType.unknown);
      } else {
        // StatusCode 200.
        _starredGistList.clear();
        final List<dynamic> gistslist =
            json.decode(response.body) as List<dynamic>;
        if (gistslist.isNotEmpty) {
          for (int i = 0; i < gistslist.length; i++) {
            // Now decode each one.
            final gist = Gist.fromMap(gistslist[i] as Map<String, dynamic>);
            if (gist.hasDartContent()) {
              _starredGistList.add(gist);
            }
          }
        }
        _starredGistListUpdateController.add(null);
      }
    }).catchError((e) {
      window.console.log('getUsersStarredGists Exception ${e.toString()}');
    });
  }

  set githubOAuthAccessToken(String newtoken) {
    if (window.localStorage[localStorageKeyForGitHubOAuthToken] != newtoken) {
      if (newtoken.isNotEmpty) {
        window.localStorage[localStorageKeyForGitHubOAuthToken] = newtoken;
        // Get the user info for this token.
        getUserInfo();
      } else {
        window.localStorage.remove(localStorageKeyForGitHubOAuthToken);
        avatarUrl = '';
        userLogin = '';
      }
    }
  }

  String get githubOAuthAccessToken =>
      window.localStorage[localStorageKeyForGitHubOAuthToken] ?? '';

  set avatarUrl(String url) {
    if (url.isNotEmpty) {
      window.localStorage[localStorageKeyForGitHubAvatarUrl] = url;
    } else {
      window.localStorage.remove(localStorageKeyForGitHubAvatarUrl);
    }
  }

  String get avatarUrl =>
      window.localStorage[localStorageKeyForGitHubAvatarUrl] ?? '';

  set userLogin(String login) {
    if (login.isNotEmpty) {
      window.localStorage[localStorageKeyForGitHubUserLogin] = login;
    } else {
      window.localStorage.remove(localStorageKeyForGitHubUserLogin);
    }
  }

  String get userLogin =>
      window.localStorage[localStorageKeyForGitHubUserLogin] ?? '';

  static const _chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  final Random _rnd = Random.secure();

  String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  String makeRandomSecureAuthInitiationUrl(String baseUrl) {
    // Create random state string which will be used by GH OAuth and then by
    // us to encrypt returned gh auth token.
    final String state = getRandomString(40);

    // Store state in localStorage, because we are going to need it to Decrypt
    // the returned authorization token.
    window.localStorage[localStorageKeyForGitHubRandomState] = state;

    if (baseUrl.endsWith('/')) {
      return '$baseUrl$state';
    } else {
      return '$baseUrl/$state';
    }
  }

  String decryptAuthTokenFromReturnedSecureAuthToken(
      String encryptedBase64AuthToken) {
    // Retrieve the random state string we made for the original request in
    // makeRandomSecureAuthInitiationUrl().  Our auth token was encrypted using
    // this before sending it back to us, so use it to decrypt.
    final String randomStateWeSent =
        window.localStorage[localStorageKeyForGitHubRandomState] ?? '';

    try {
      if (randomStateWeSent.isEmpty) {
        throw Exception(
            'ERROR - decryptAuthTokenFromReturnedSecureAuthToken() found no stored initial state.');
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
      window.console.log(
          'decryptAuthTokenFromReturnedSecureAuthToken Exception e=${e.toString()}');
    }
    throw Exception(
        'ERROR - decryptAuthTokenFromReturnedSecureAuthToken() general decryption exception.');
  }
}

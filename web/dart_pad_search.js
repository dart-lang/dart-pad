// Define search commands and interface for our Dart layer above us
// This includes the ability to call BACK to the dart layer when we
// are asynchronously re-evaluating the changed editor text and
// re-annotating the highlight text and the scrollbar

(function(mod) {
  if (typeof exports == "object" && typeof module == "object") // CommonJS
    mod(require("../../lib/codemirror"), require("./searchcursor"), require("../dialog/dialog"));
  else if (typeof define == "function" && define.amd) // AMD
    define(["../../lib/codemirror", "./searchcursor", "../dialog/dialog"], mod);
  else // Plain browser env
    mod(CodeMirror);
})(function(CodeMirror) {
  "use strict";

  // default search panel location
  CodeMirror.defineOption("dart_pad_search", {});

  function searchOverlay(query, caseInsensitive) {
    if (typeof query == "string")
      query = new RegExp(query.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&"), caseInsensitive ? "gi" : "g");
    else if (!query.global)
      query = new RegExp(query.source, query.ignoreCase ? "gi" : "g");

    return {token: function(stream) {
      query.lastIndex = stream.pos;
      var match = query.exec(stream.string);
      if (match && match.index == stream.pos) {
        stream.pos += match[0].length || 1;
        return "searching";
      } else if (match) {
        stream.pos = match.index;
      } else {
        stream.skipToEnd();
      }
    }};
  }

  function findMatches(cm,state) {
    var pastLastLine = cm.lastLine() + 1;
    var matches = [];
    var i=0;
    var cursor = cm.getSearchCursor(state.query, CodeMirror.Pos(cm.firstLine(), 0));
    var maxMatches = MAX_MATCHES;
    while (cursor.findNext()) {
      var match = {from: cursor.from(), to: cursor.to()};
      matches.splice(i++, 0, match);
      if (matches.length > maxMatches) break;
    }
    return matches;
  };

  function SearchState() {
    this.posFrom = this.posTo = this.lastQuery = this.query = null;
    this.overlay = null;
  }

  function getSearchState(cm) {
    return cm.state.search || (cm.state.search = new SearchState());
  }

  /// All of our query strings will be regular expressions, and we only
  ///    return true here if it is marked as being case insensitive ('/i' or '/gi')
  function queryCaseInsensitive(query) {
    if(typeof query == "object") {
      query = query.toString();
    }
    var isRE = query.match(/^\/(.*)\/([a-z]*)$/);
    if (isRE) {
      return isRE[2].indexOf("i") != -1;
    } else {
      //if it is not a regular expression we return false, no string searching
      return (typeof query == "string") && query == query.toLowerCase();
    }
  }

  function getSearchCursor(cm, query, pos) {
    // Heuristic: if the query string is all lowercase, do a case insensitive search.
    return cm.getSearchCursor(query, pos, {caseFold: queryCaseInsensitive(query), multiline: true});
  }

  function parseString(string) {
    return string.replace(/\\([nrt\\])/g, function(match, ch) {
      if (ch == "n") return "\n"
      if (ch == "r") return "\r"
      if (ch == "t") return "\t"
      if (ch == "\\") return "\\"
      return match
    })
  }

  function parseQuery(query) {
    if( typeof query == "object") return query; // it is already a regex
    var isRE = query.match(/^\/(.*)\/([a-z]*)$/);
    if (isRE) {
      try { query = new RegExp(isRE[1], isRE[2].indexOf("i") == -1 ? "" : "i"); }
      catch(e) {} // Not a regular expression after all, do a string search
    } else {
      query = parseString(query)
    }
    if (typeof query == "string" ? query == "" : query.test(""))
      query = /x^/;
    return query;
  }

  function startSearch(cm, state, query) {
    state.queryText = (typeof query == "object") ? query.toString() : query;
    state.query = parseQuery(query);
    cm.removeOverlay(state.overlay, queryCaseInsensitive(state.query));
    state.overlay = searchOverlay(state.query, queryCaseInsensitive(state.query));
    cm.addOverlay(state.overlay, { priority: -5} ); // priority>0 so search highlights over others (like selection highlighting for example)
    if (cm.showMatchesOnScrollbar) {
      if (state.annotate) { state.annotate.clear(); state.annotate = null; }
      state.annotate = cm.showMatchesOnScrollbar(state.query, queryCaseInsensitive(state.query));
      if( state.annotate ) {
        /*
            HERE is where we insert a hook into the SearchAnnotation() object of
            matchesonscrollbar.s (which uses annotatescrollbar.js)
            This is how we call our callback to dart when codemirror is re-evaluating
            the query against the text and updating the onscreen annotations.
            (and then we can update our dialog with 'X of Y'..(or '? of Y'))
        */
        if( state.annotate.origUpdateAfterChange==undefined ) {
          state.annotate.origUpdateAfterChange = state.annotate.updateAfterChange;
          state.annotate.ourDartChangeHook = function() {
            this.origUpdateAfterChange();
            // Now try and call our dart code!
            cm.storedForDartAnnotationMatches = this.matches;
            CodeMirror.commands.ourSearchQueryUpdatedCallback(cm);
          }
          state.annotate.updateAfterChange = state.annotate.ourDartChangeHook;
        }
      }
    }
  }

  function doSearch(cm, query, rev, highlightOnly) {
    var queryText = (typeof query == "object") ? query.toString() : query;
    if( typeof query != "object" ) query = parseQuery(query);

    var state = getSearchState(cm);
    if (queryText != state.queryText) {
      startSearch(cm, state, query);
      state.posFrom = state.posTo = cm.getCursor();
    }
    if (state.query) {
      if( highlightOnly ) return getSearchResultInfoObject(cm,state);
      return findNext(cm, rev);
    }
    var q = cm.getSelection() || state.lastQuery;
    if (q instanceof RegExp && q.source == "x^") q = null

    if (query && !state.query) return cm.operation(function() {
      startSearch(cm, state, query);
      state.posFrom = state.posTo = cm.getCursor();
      return findNext(cm, rev);
    });
  }

  function findNext(cm, rev, callback) {
    return cm.operation(function() {
      var state = getSearchState(cm);
      if(rev) {
        // move cursor back 1 character so when going in reverse we don't find this match again
        state.posFrom.ch--;
      }
      var cursor = getSearchCursor(cm, state.query, rev ? state.posFrom : state.posTo);
      if (!cursor.find(rev)) {
        cursor = getSearchCursor(cm, state.query, rev ? CodeMirror.Pos(cm.lastLine()) : CodeMirror.Pos(cm.firstLine(), 0));
        if (!cursor.find(rev)) return getSearchResultInfoObject(cm,state);
      }
      cm.setSelection(cursor.from(), cursor.to());
      cm.scrollIntoView({from: cursor.from(), to: cursor.to()}, 20);
      state.posFrom = cursor.from(); state.posTo = cursor.to();
      if (callback) callback(cursor.from(), cursor.to())
      return getSearchResultInfoObject(cm,state);
  });}

  function clearSearch(cm) {cm.operation(function() {
    var state = getSearchState(cm);
    state.lastQuery = state.query;
    if (!state.query) return;
    state.query = state.queryText = null;
    cm.removeOverlay(state.overlay);
    if (state.annotate) { state.annotate.clear(); state.annotate = null; }
  });}

  
  function doReplace(cm, query, replaceText) {
    // get our query as regular expression
    query = parseQuery( query );

    clearSearch(cm);
    var cursor = getSearchCursor(cm, query, cm.getCursor("from"));

    var doReplace = function(match) {
      cursor.replace(typeof query == "string" ? replaceText :
            replaceText.replace(/\$(\d)/g, function(_, i) {return match[i];}));
      return advance(true);  // AFTER we replace to DO NOT ADVANCE AGAIN
    };
    var advance = function( noReplacingAfterAdvance ) {
      var start = cursor.from(), match;
      if (!(match = cursor.findNext())) {
        cursor = getSearchCursor(cm, query);
        if (!(match = cursor.findNext()) ||
            (start && cursor.from().line == start.line &&
                  cursor.from().ch == start.ch)) {
          return;
        }
      }
      cm.setSelection(cursor.from(), cursor.to());
      cm.scrollIntoView({from: cursor.from(), to: cursor.to()});
      if(noReplacingAfterAdvance==true) {
        // We need to figure out where we are in the scheme of things
        return;
      } else {
        // call and do ACTUAL replacing
        return doReplace(match);
      }
    };
    return advance();
  }

  function replaceAll(cm, query, text) {
    // make sure our query is regular expression
    query = parseQuery( query );

    cm.operation(function() {
      for (var cursor = getSearchCursor(cm, query); cursor.findNext();) {
        if (typeof query != "string") {
          var match = cm.getRange(cursor.from(), cursor.to()).match(query);
          cursor.replace(text.replace(/\$(\d)/g, function(_, i) {return match[i];}));
        } else cursor.replace(text);
      }
    });
  }

  function getSearchResultInfoObject(cm,state) {
    var matches;
    if( state.annotate ) {
      matches = state.annotate.matches;      
    } else {
      // we need to make a matches array
      matches = findMatches( cm, state.query )
    }
    return getSearchResultInfoObjectFromMatches( cm, matches );
  }
  
  // escapes all regex meaningful characters
  function escapeRegExp(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); // $& means the whole matched string
  }

  // To escape a replacement string:
  function escapeReplacement(string) {
    return string.replace(/\$/g, '$$$$');
  }

  /// We escape regular expression characters if not regExp searching
  //    is set from the UI coming in
  function makeOurRegExQuery(queryMayBeRegExSyntaxFromUser,  matchCase, wholeWord, regEx) {
	  if( queryMayBeRegExSyntaxFromUser=='' ) {
		  // don't allow empty string, make nonmatchable regex
		  queryMayBeRegExSyntaxFromUser = '/x^/';
	  }
    var isRE = queryMayBeRegExSyntaxFromUser.match(/^\/(.*)\/([a-z]*)$/);
    var queryRegEx=undefined;
    if (isRE) {
      // it already head regex syntax - we stripped it OFF
      var ingoreCaseInRegEx = (isRE[2].indexOf("i") != -1);
      var reStr = isRE[1];
	    if( reStr=='' ) reStr='x^'; // don't allow empty regex
      if( wholeWord ) {
        // add reg ex word boundries
        reStr = "\\b" + reStr + "\\b";
      }
      try {
        queryRegEx = new RegExp(reStr, (ingoreCaseInRegEx || !matchCase) ? "i" : ""); 
      }
      catch(e) {} // Not a regular expression after all, do a string search
    } else {
      // The didn't have /xxxxx/ but do they want a reged ?
      if( regEx ) {
        var reStr = queryMayBeRegExSyntaxFromUser;
        if( wholeWord ) {
          // add reg ex word boundries
          reStr = "\\b" + reStr + "\\b";
        }
        try {
          queryRegEx = new RegExp(reStr, !matchCase ? "i" : ""); 
        }
        catch(e) {} 
      } else {
	      // we need to ESCAPE regular expression stuff out
	      var reStr = escapeRegExp(queryMayBeRegExSyntaxFromUser);
        if( wholeWord ) {
          // add reg ex word boundries
          reStr = "\\b" + reStr + "\\b";
        }
        try {
          queryRegEx = new RegExp( reStr, !matchCase ? "i" : ""); 
        }
        catch(e) {} 
      }
    }
    if( queryRegEx==undefined ) {
      // something went wrong, default to unmatchable..
      return /x^/;
    }
    return queryRegEx;
  }

  CodeMirror.defineExtension("searchFromDart", function(query, reverse, highlightOnly, matchCase, wholeWord, regEx) {
     clearSearch(this);

     var queryToSend = makeOurRegExQuery(query, matchCase, wholeWord, regEx);

     return doSearch( this, queryToSend, reverse, highlightOnly )
  });

  CodeMirror.defineExtension("replaceAllFromDart", function(query, replaceText, matchCase, wholeWord, regEx) {
     clearSearch(this);

     var queryToSend = makeOurRegExQuery(query, matchCase, wholeWord, regEx);

     replaceAll( this, queryToSend, replaceText );

     // and end with a SEARCH to re-highlight orginal query
     return doSearch( this, queryToSend, false );
  });

  /// replace next form dart, currenly UI does it themselves..
  CodeMirror.defineExtension("replaceNextFromDart", function(query, replaceText, matchCase, wholeWord, regEx) {
     clearSearch(this);

     var queryToSend = makeOurRegExQuery(query, matchCase, wholeWord, regEx);

     // and end with a SEARCH to re-highlight orginal query
     return doReplace( this, queryToSend, replaceText );
  });

  CodeMirror.defineExtension("getTokenWeAreOnOrNear", function( regExStr ) {
    if (!this.somethingSelected()) {
      var re = regExStr==undefined ? /[\w$]/ : regExStr;
      var cur = this.getCursor(), line = this.getLine(cur.line), start = cur.ch, end = start;
      while (start && re.test(line.charAt(start - 1))) --start;
      while (end < line.length && re.test(line.charAt(end))) ++end;
      if (start < end) {
        return line.slice(start, end);
      }
      return null;
    }
  });

  CodeMirror.defineExtension("clearActiveSearch", function( regExStr ) {
    clearSearch(this);
  });

  /// This returns the matches that we stored before calling the 'SearchQueryUpdatedCallback'
  CodeMirror.defineExtension("getMatchesFromSearchQueryUpdatedCallback", function() {
    var matches = (this.storedForDartAnnotationMatches!=undefined) ?
                              this.storedForDartAnnotationMatches : [];
    return getSearchResultInfoObjectFromMatches( this, matches );
  });

  function getSearchResultInfoObjectFromMatches(cm, matches) {
    var cursorAtFrom = cm.getCursor("from");
    var numMatches = matches.length;
    var hitWeAreOn = -1; // we might not find it
    if( matches && matches.length>0) {
      var cursorLine = cursorAtFrom.line;
      var cursorCh = cursorAtFrom.ch;
      numMatches = matches.length;
      var m=0;
      for(;m<numMatches;m++) {
        var fromPos = matches[m].from;
        var toPos = matches[m].to;
        // Once we are AT or just PAST the last match then THAT is our match that
        //   we are 'on', it is the closest match we are at least at or past
        if( (fromPos.line==cursorLine && fromPos.ch<=cursorCh) &&
                  ((cursorCh<=toPos.ch && cursorLine==toPos.line) ||
                                        toPos.line>cursorLine) ) {
          // we are in/on this one
          hitWeAreOn = m;
          break;
        } else if( cursorLine<fromPos.line ||
                          (cursorLine==fromPos.line && cursorCh<fromPos.ch) ) {
          // we are PAST (BEFORE) this one
          hitWeAreOn = m-1;
          break;
        }
      }
      if( m>=numMatches ) {
        hitWeAreOn = numMatches-1;
      }
    }
    return { 'matches':matches, 'total':numMatches, 'curMatchNum':hitWeAreOn };
  }


});

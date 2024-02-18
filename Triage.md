## Bug triage priorities

Each issue in the tracker will be assigned a priority based on the impact to
users when the issue appears and the number of users impacted (widespread or
rare).

Some examples of likely triage priorities:

* P0
    *   Broken internal/external navigation links within DartPad
    *   JavaScript console errors indicating problems with DartPad functionality in many cases, widespread.
    *   App is down / not loading
    *   Interface bugs preventing all or almost all uses of the application
    *   Unable to compile or analyze valid Flutter/Dart code (widespread and/or with error messages that aren't retryable)
* P1
    *   Unable to compile or analyze valid Flutter/Dart code in edge cases only, and/or retryable
    *   Incorrect or not up-to-date warning information for invalid Flutter/Dart code (widespread)
    *   Interface bugs interfering with common uses of the application, widespread
    *   JavaScript console errors indicating problems with DartPad functionality (edge cases / not widespread)
    *   Enhancements that have significant data around them indicating they are a big win
    *   User performance problem (e.g. app loading / run / analysis), widespread
* P2
    *   Incorrect or not up-to-date warning information for invalid Flutter/Dart code (edge cases / not widespread)
    *   JavaScript errors not resulting in visible problems outside of the console (widespread)
    *   Interface bugs interfering with the use of the application in edge cases.
    *   User interface and display warts that are not significantly impacting functionality, widespread
    *   Enhancements that are agreed to be a good idea even if they don't have data around them indicating they are a big win
    *   User performance problem (for example, app loading / run analysis), edge cases / not widespread
* P3
    *   Minor user interface warts not significantly impacting functionality, on edge cases only.
    *   JavaScript errors not resulting in visible problems outside of the console (edge cases)
    *   Enhancements that are speculative or where we are unsure of impacts/tradeoffs

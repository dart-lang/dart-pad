module.exports = function(config) {
  config.set({
    //logLevel: config.LOG_DEBUG,
    basePath: '.',
    frameworks: ['dart-unittest'],

    // list of files / patterns to load in the browser
    // all tests must be 'included', but all other libraries must be 'served' and
    // optionally 'watched' only.
    files: [
      'test/*.dart',
      {pattern: '**/*.dart', watched: true, included: false, served: true},
      'packages/browser/dart.js',
      'packages/browser/interop.js'
    ],

    autoWatch: false,

    // If browser does not capture in given timeout [ms], kill it
    captureTimeout: 120000,
    // Time for dart2js to run on Travis... [ms]
    browserNoActivityTimeout: 1500000,

    plugins: [
        'karma-dart',
        'karma-chrome-launcher',
        'karma-firefox-launcher',
        'karma-script-launcher',
        'karma-sauce-launcher',
        'karma-junit-reporter'
    ],


    customLaunchers: {
        'SL_Chrome': {
            base: 'SauceLabs',
            browserName: 'chrome',
            version: '35'
        },
        'SL_Firefox': {
            base: 'SauceLabs',
            browserName: 'firefox',
            version: '30'
        }
    },

    junitReporter: {
      outputFile: 'test/out/unit.xml',
      suite: 'unit'
    },

    sauceLabs: {
        testName: 'RouteDart',
        tunnelIdentifier: process.env.TRAVIS_JOB_NUMBER,
        startConnect: false,
        options:  {
            'selenium-version': '2.41.0',
            'max-duration': 2700
        }
    }
  });
};

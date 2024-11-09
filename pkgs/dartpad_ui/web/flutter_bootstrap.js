{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load();

const splash = document.querySelector('#splash');

_initSplashTheme();

window.addEventListener('flutter-first-frame', () => {
  splash.classList.add('done');

  setTimeout(() => splash.remove(), 500);
});

async function _initSplashTheme() {
  const queryParams = new URLSearchParams(window.location.search);
  let theme = queryParams.get('theme');

  theme ??= window.matchMedia('(prefers-color-scheme: dark)').matches
    ? 'dark'
    : 'light';

  splash.classList.add(theme);
}
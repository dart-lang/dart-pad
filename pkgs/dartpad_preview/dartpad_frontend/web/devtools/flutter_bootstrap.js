(()=>{var C={blink:!0,gecko:!1,webkit:!1,unknown:!1},P=()=>navigator.vendor==="Google Inc."||navigator.userAgent.includes("Edg/")?"blink":navigator.vendor==="Apple Computer, Inc."?"webkit":navigator.vendor===""&&navigator.userAgent.includes("Firefox")?"gecko":"unknown",S=P(),A=()=>typeof ImageDecoder>"u"?!1:S==="blink",x=()=>typeof Intl.v8BreakIterator<"u"&&typeof Intl.Segmenter<"u",R=()=>typeof window.TextCluster<"u",j=()=>{let n=[0,97,115,109,1,0,0,0,1,5,1,95,1,120,0];return WebAssembly.validate(new Uint8Array(n))},K=()=>{let n=document.createElement("canvas");return n.width=1,n.height=1,n.getContext("webgl2")!=null?2:n.getContext("webgl")!=null?1:-1},B=()=>window.chrome&&chrome.runtime&&chrome.runtime.id,f={browserEngine:S,hasImageCodecs:A(),hasChromiumBreakIterators:x(),hasTextCluster:R(),supportsWasmGC:j(),crossOriginIsolated:window.crossOriginIsolated,webGLVersion:K(),isChromeExtension:B()};function p(...n){return new URL(_(...n),document.baseURI).toString()}function _(...n){return n.filter(e=>!!e).map((e,s)=>s===0?L(e):F(L(e))).filter(e=>e.length).join("/")}function F(n){let e=0;for(;e<n.length&&n.charAt(e)==="/";)e++;return n.substring(e)}function L(n){let e=n.length;for(;e>0&&n.charAt(e-1)==="/";)e--;return n.substring(0,e)}function T(n,e){return n.canvasKitBaseUrl?n.canvasKitBaseUrl:e.engineRevision&&!e.useLocalCanvasKit?_("https://www.gstatic.com/flutter-canvaskit",e.engineRevision):"canvaskit"}var g=class{constructor(){this._scriptLoaded=!1}setTrustedTypesPolicy(e){this._ttPolicy=e}async loadEntrypoint(e){let{entrypointUrl:s=p("main.dart.js"),onEntrypointLoaded:t,nonce:r}=e||{};return this._loadJSEntrypoint(s,t,r)}async load(e,s,t,r,i){i??=a=>{a.initializeEngine(t).then(d=>d.runApp())};let{entrypointBaseUrl:o}=t,{entryPointBaseUrl:l}=t;if(!o&&l&&(console.warn("[deprecated] `entryPointBaseUrl` is deprecated and will be removed in a future release. Use `entrypointBaseUrl` instead."),o=l),e.compileTarget==="dart2wasm")return this._loadWasmEntrypoint(e,s,o,i);{let a=e.mainJsPath??"main.dart.js",d=p(o,a);return this._loadJSEntrypoint(d,i,r)}}didCreateEngineInitializer(e){typeof this._didCreateEngineInitializerResolve=="function"&&(this._didCreateEngineInitializerResolve(e),this._didCreateEngineInitializerResolve=null,delete _flutter.loader.didCreateEngineInitializer),typeof this._onEntrypointLoaded=="function"&&this._onEntrypointLoaded(e)}_loadJSEntrypoint(e,s,t){let r=typeof s=="function";if(!this._scriptLoaded){this._scriptLoaded=!0;let i=this._createScriptTag(e,t);if(r)console.debug("Injecting <script> tag. Using callback."),this._onEntrypointLoaded=s,document.head.append(i);else return new Promise((o,l)=>{console.debug("Injecting <script> tag. Using Promises. Use the callback approach instead!"),this._didCreateEngineInitializerResolve=o,i.addEventListener("error",l),document.head.append(i)})}}async _loadWasmEntrypoint(e,s,t,r){if(!this._scriptLoaded){this._scriptLoaded=!0,this._onEntrypointLoaded=r;let{mainWasmPath:i,jsSupportRuntimePath:o}=e,l=p(t,i),a=p(t,o);this._ttPolicy!=null&&(a=this._ttPolicy.createScriptURL(a));let c=(await import(a)).compileStreaming(fetch(l)),u;e.renderer==="skwasm"?u=(async()=>{let y=await s.skwasm;return window._flutter_skwasmInstance=y,{skwasm:y.wasmExports,skwasmWrapper:y,ffi:{memory:y.wasmMemory}}})():u=Promise.resolve({}),await(await(await c).instantiate(await u)).invokeMain()}}_createScriptTag(e,s){let t=document.createElement("script");t.type="application/javascript",s&&(t.nonce=s);let r=e;return this._ttPolicy!=null&&(r=this._ttPolicy.createScriptURL(e)),t.src=r,t}};async function E(n,e,s){if(e<0)return n;let t,r=new Promise((i,o)=>{t=setTimeout(()=>{o(new Error(`${s} took more than ${e}ms to resolve. Moving on.`,{cause:E}))},e)});return Promise.race([n,r]).finally(()=>{clearTimeout(t)})}var h=class{setTrustedTypesPolicy(e){this._ttPolicy=e}loadServiceWorker(e){if(!e||!("serviceWorker"in navigator))return Promise.resolve();let s=()=>{console.warn(`Loading the service worker using Flutter bootstrap is deprecated and will stop working in a future release.
For more details, see: https://github.com/flutter/flutter/issues/156910`)},t=()=>{let{serviceWorkerVersion:r,serviceWorkerUrl:i=p(`flutter_service_worker.js?v=${r}`),timeoutMillis:o=4e3}=e,l=i;this._ttPolicy!=null&&(l=this._ttPolicy.createScriptURL(l));let a=navigator.serviceWorker.register(l).then(d=>this._getNewServiceWorker(d,r)).then(this._waitForServiceWorkerActivation);return E(a,o,"prepareServiceWorker")};return e.serviceWorkerUrl!=null?(s(),t()):navigator.serviceWorker.getRegistration().then(r=>r?t():Promise.resolve())}async _getNewServiceWorker(e,s){if(!e.active&&(e.installing||e.waiting))return console.debug("Installing/Activating first service worker."),e.installing||e.waiting;if(e.active.scriptURL.endsWith(s))return console.debug("Loading from existing service worker."),e.active;{let t=await e.update();return console.debug("Updating service worker."),t.installing||t.waiting||t.active}}async _waitForServiceWorkerActivation(e){if(!e||e.state==="activated")if(e){console.debug("Service worker already active.");return}else throw new Error("Cannot activate a null service worker!");return new Promise((s,t)=>{e.addEventListener("statechange",()=>{e.state==="activated"&&(console.debug("Activated new service worker."),s())})})}};var v=class{constructor(e,s="flutter-js"){let t=e||[/\.js$/,/\.mjs$/];window.trustedTypes&&(this.policy=trustedTypes.createPolicy(s,{createScriptURL:function(r){if(r.startsWith("blob:"))return r;let i=new URL(r,window.location),o=i.pathname.split("/").pop();if(t.some(a=>a.test(o)))return i.toString();console.error("URL rejected by TrustedTypes policy",s,":",r,"(download prevented)")}}))}};var k=(n,e)=>{let s=window._flutter?.buildConfig?.wasmHashes,t=s?.[e];if(!t&&e.includes("/")){let a=e.split("/").pop();t=s?.[a]}let r="crossOriginStorage"in navigator&&"requestFileHandles"in navigator.crossOriginStorage;r&&console.log("Cross-Origin Storage is supported. See https://wicg.github.io/cross-origin-storage/ for more details.");let i=async a=>{let d={algorithm:"SHA-256",value:a};try{let[c]=await navigator.crossOriginStorage.requestFileHandles([d]),u=await c.getFile();return new Response(u,{headers:{"Content-Type":"application/wasm"}})}catch(c){c.name==="NotAllowedError"?console.warn(`Not allowed to retrieve ${e} (hash: ${a}).`):c.name!=="NotFoundError"&&console.warn(`Unexpected error during retrieval of ${e} (hash: ${a}).`,c)}},o=async()=>{if(r&&t){let d=await i(t);if(d)return d}let a=await fetch(n);if(r&&t&&a.ok){let d={algorithm:"SHA-256",value:t},c=a.clone();(async()=>{try{let u=await c.blob(),[w]=await navigator.crossOriginStorage.requestFileHandles([d],{create:!0}),m=await w.createWritable();await m.write(u),await m.close()}catch(u){console.warn(`Error storing ${e} (hash: ${t}):`,u)}})()}return a},l=WebAssembly.compileStreaming(o());return(a,d)=>((async()=>{let c=await l,u=await WebAssembly.instantiate(c,a);d(u,c)})(),{})};var W=(n,e,s,t)=>(window.flutterCanvasKitLoaded=(async()=>{if(window.flutterCanvasKit)return window.flutterCanvasKit;let r=s.hasChromiumBreakIterators&&s.hasImageCodecs;if(!r&&e.canvasKitVariant=="chromium")throw"Chromium CanvasKit variant specifically requested, but unsupported in this browser";let i=r&&e.canvasKitVariant!=="full",o=i&&e.preferWebParagraph&&s.hasTextCluster,l=t;o?l=p(l,"webparagraph"):i&&(l=p(l,"chromium"));let a=p(l,"canvaskit.js");n.flutterTT.policy&&(a=n.flutterTT.policy.createScriptURL(a));let d="canvaskit.wasm";o?d="webparagraph/canvaskit.wasm":i&&(d="chromium/canvaskit.wasm");let c=k(p(l,"canvaskit.wasm"),d),u=await import(a);return window.flutterCanvasKit=await u.default({instantiateWasm:c}),window.flutterCanvasKit})(),window.flutterCanvasKitLoaded);var I=async(n,e,s,t)=>{let i=!s.hasImageCodecs||!s.hasChromiumBreakIterators?"skwasm_heavy":e.enableWimp?"wimp":"skwasm",o=p(t,`${i}.js`),l=o;n.flutterTT.policy&&(l=n.flutterTT.policy.createScriptURL(l));let a=k(p(t,`${i}.wasm`),`${i}.wasm`);return await(await import(l)).default({skwasmSingleThreaded:e.enableWimp||!s.crossOriginIsolated||s.isChromeExtension||e.forceSingleThreadedSkwasm,instantiateWasm:a,locateFile:(c,u)=>c.endsWith(".ww.js")?URL.createObjectURL(new Blob([`
"use strict";

let eventListener;
eventListener = (message) => {
    const pendingMessages = [];
    const data = message.data;
    data["instantiateWasm"] = (info,receiveInstance) => {
        const instance = new WebAssembly.Instance(data["wasm"], info);
        return receiveInstance(instance, data["wasm"])
    };
    import(data.js).then(async (skwasm) => {
        await skwasm.default(data);

        removeEventListener("message", eventListener);
        for (const message of pendingMessages) {
            dispatchEvent(message);
        }
    });
    removeEventListener("message", eventListener);
    eventListener = (message) => {

        pendingMessages.push(message);
    };

    addEventListener("message", eventListener);
};
addEventListener("message", eventListener);
`],{type:"application/javascript"})):p(t,c),mainScriptUrlOrBlob:o})};var U=f.supportsWasmGC,$=U&&f.webGLVersion>0,b=class{async loadEntrypoint(e){let{serviceWorker:s,...t}=e||{},r=new v,i=new h;i.setTrustedTypesPolicy(r.policy),await i.loadServiceWorker(s).catch(l=>{console.warn("Exception while loading service worker:",l)});let o=new g;return o.setTrustedTypesPolicy(r.policy),this.didCreateEngineInitializer=o.didCreateEngineInitializer.bind(o),o.loadEntrypoint(t)}async load({serviceWorkerSettings:e,onEntrypointLoaded:s,nonce:t,config:r}={}){r??={};let i=_flutter.buildConfig;if(!i)throw"FlutterLoader.load requires _flutter.buildConfig to be set";let o=r.wasmAllowList?.[f.browserEngine]??C[f.browserEngine],l=m=>{switch(m){case"skwasm":return $&&o;default:return!0}},a=m=>m.compileTarget==="dart2wasm"&&!U||r.renderer&&r.renderer!=m.renderer?!1:l(m.renderer),d=i.builds.find(a);if(!d)throw"FlutterLoader could not find a build compatible with configuration and environment.";let c={};c.flutterTT=new v,e&&(c.serviceWorkerLoader=new h,c.serviceWorkerLoader.setTrustedTypesPolicy(c.flutterTT.policy),await c.serviceWorkerLoader.loadServiceWorker(e).catch(m=>{console.warn("Exception while loading service worker:",m)}));let u=T(r,i);d.renderer==="canvaskit"?c.canvasKit=W(c,r,f,u):d.renderer==="skwasm"&&(c.skwasm=I(c,r,f,u));let w=new g;return w.setTrustedTypesPolicy(c.flutterTT.policy),this.didCreateEngineInitializer=w.didCreateEngineInitializer.bind(w),w.load(d,c,r,t,s)}};window._flutter||(window._flutter={});window._flutter.loader||(window._flutter.loader=new b);})();
//# sourceMappingURL=flutter.js.map

if (!window._flutter) {
  window._flutter = {};
}
_flutter.buildConfig = {"engineRevision":"ad80825c24d770a19e33f67800fc0338a3b89ec7","wasmHashes":{"webparagraph/canvaskit.wasm":"d32fa4acc3c280b213c147f7d2ba1259214d06fa74a75fda8bdaac66118af0dd","chromium/canvaskit.wasm":"9a3ab16d04942282f771ab1204dee279def1b076ec718d885195f25bbd25cb5f","skwasm.wasm":"17c6ea326bae65d0e3e04fcb8a7e653b2ea4bc94984dcb60ee846cb560e6468e","skwasm_heavy.wasm":"a03415969934e8c6316431c2abd1f97716887d125a711f7e051f09e90ef5e2ea","wimp.wasm":"3ad93468b9464843ec5ebd1123a6943b5c2fe9cc0ed2ba599854218f89071fe3","canvaskit.wasm":"6f8003ed949d195743ab376a8a54ad030ea5f08778051558f97ac2fe1aaa6c41"},"builds":[{"compileTarget":"dart2wasm","renderer":"skwasm","mainWasmPath":"main.dart.wasm","jsSupportRuntimePath":"main.dart.mjs"},{"compileTarget":"dart2js","renderer":"canvaskit","mainJsPath":"main.dart.js"}]};


// Unregister the old custom DevTools service worker (if it exists). It was
// removed in: https://github.com/flutter/devtools/pull/5331
function unregisterDevToolsServiceWorker() {
  if ('serviceWorker' in navigator) {
    const DEVTOOLS_SW = 'service_worker.js';
    const FLUTTER_SW = 'flutter_service_worker.js';
    navigator.serviceWorker.getRegistrations().then(function(registrations) {
        for (let registration of registrations) {
            const activeWorker = registration.active;
            if (activeWorker != null) {
                const url = activeWorker.scriptURL;
                if (url.includes(DEVTOOLS_SW) && !url.includes(FLUTTER_SW)) {
                    registration.unregister();
                }
            }
        }
    });
  }
}

// This query parameter must match the String value specified by
// `DevToolsQueryParameters.compilerKey`. See
// devtools/packages/devtools_app/lib/src/shared/query_parameters.dart
const compilerQueryParameterKey = 'compiler';

// Returns the value for the given search param.
function getSearchParam(searchParamKey) {
  const searchParams = new URLSearchParams(window.location.search);
  return searchParams.get(searchParamKey);
}

// Calls the DevTools server API to read the user's wasm preference.
async function getDevToolsWasmOptOutPreference() {
  // Note: when the DevTools server is running on a different port than the
  // DevTools web app, this request path will be incorrect and the request
  // will fail. This is okay because DevTools cannot be built with WASM when
  // running from `flutter run` anyway.
  const request = 'api/getPreferenceValue?key=experiment.wasmOptOut';
  try {
    const response = await fetch(request);
    if (!response.ok) {
      console.warn(`[${response.status} response] ${request}`);
      return false;
    }

    // The response text should be an encoded boolean value ("true" or "false").
    const isOptedOut = JSON.parse(await response.text());
    return isOptedOut === true || isOptedOut === 'true';
  } catch (error) {
    console.error('Error fetching experiment.wasmOptOut preference value:', error);
    return false;
  }
}

// The query parameter compiler=js gives us an escape hatch we can offer users if their
// dart2wasm app fails to load.
const forceUseJs = () => getSearchParam(compilerQueryParameterKey) === 'js';

// Returns whether DevTools should be loaded with the skwasm renderer based on the
// value of the 'wasm' query parameter or the wasm setting from the DevTools
// preference file.
async function shouldUseSkwasm() {
  // If dart2js has specifically been requested via query parameter, then do not try to
  // use skwasm (even if the local setting is for wasm).
  if (forceUseJs()) {
    return false;
  }

  const wasmEnabledFromQueryParameter = getSearchParam(compilerQueryParameterKey) === 'wasm';
  if (wasmEnabledFromQueryParameter) {
    return true;
  }

  const userHasOptedOut = await getDevToolsWasmOptOutPreference();
  if (userHasOptedOut) {
    return false;
  }
  
  return true;
}

// Sets or removes the 'wasm' query parameter based on whether DevTools should
// be loaded with the skwasm renderer.
//
// Note: In the case of the legacy-formatted URL, this adds the query parameter
// in the wrong place. We fix this in the Dart mapLegacyUrl function. Details:
// https://github.com/flutter/devtools/issues/9612
function updateWasmQueryParameter(useSkwasm) {
  const url = new URL(window.location.href);
  if (useSkwasm) {
    url.searchParams.set(compilerQueryParameterKey, 'wasm');
  } else {
    url.searchParams.delete(compilerQueryParameterKey);
  }
  // Update the browser's history without reloading. This is a no-op if the wasm
  // query parameter does not actually need to be updated.
  window.history.pushState({}, '', url);
}

// Bootstrap app for 3P environments:
async function bootstrapAppFor3P() {
  const useSkwasm = await shouldUseSkwasm();

  if (!forceUseJs()) {
    // Ensure the 'wasm' query parameter in the URL is accurate for the renderer
    // DevTools will be loaded with.
    updateWasmQueryParameter(useSkwasm);
  }

  const rendererForLog = useSkwasm ? 'skwasm' : 'canvaskit';
  console.log('Attempting to load DevTools with ' + rendererForLog + ' renderer.');

  const rendererConfig = useSkwasm ? {} : { renderer: 'canvaskit' };
  _flutter.loader.load({
    serviceWorkerSettings: {
      serviceWorkerVersion: "1900899552" /* Flutter's service worker is deprecated and will be removed in a future Flutter release. */,
    },
    config: {
      canvasKitBaseUrl: 'canvaskit/',
      ...rendererConfig,
    }
  });
}

// Bootstrap app for 1P environments:
function bootstrapAppFor1P() {
  _flutter.loader.load();
}

unregisterDevToolsServiceWorker();
bootstrapAppFor3P();

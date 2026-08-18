// Compiles a dart2wasm-generated main module from `source` which can then
// be instantiated via the `instantiate` method.
//
// `source` needs to be a `Response` object (or promise thereof) e.g. created
// via the `fetch()` JS API.
export async function compileStreaming(source) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(
      await WebAssembly.compileStreaming(source, builtins), builtins);
}

// Compiles a dart2wasm-generated wasm module from `bytes` which is then
// instantiable via the `instantiate` method.
export async function compile(bytes) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(await WebAssembly.compile(bytes, builtins), builtins);
}

class CompiledApp {
  constructor(module, builtins) {
    this.module = module;
    this.builtins = builtins;
  }

  // The second argument is an options object containing:
  // `loadDeferredModules` is a JS function that takes an array of module names
  //   matching wasm files produced by the dart2wasm compiler. It also takes a
  //   callback that should be invoked for each loaded module with 2 arguments:
  //   (1) the module name, (2) the loaded module in a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`. The callback
  //   returns a Promise that resolves when the module is instantiated.
  //   loadDeferredModules should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  // `loadDeferredId` is a JS function that takes load ID produced by the
  //   compiler when the `use-load-ids` option is passed. Each load ID maps to
  //   one or more wasm files as specified in the emitted JSON file. It also
  //   takes a callback that should be invoked for each loaded module with 2
  //   arguments: (1) the module name, (2) the loaded module in a format
  //   supported by `WebAssembly.compile` or `WebAssembly.compileStreaming`.
  //   The callback returns a Promise that resolves when the module is
  //   instantiated.
  //   loadDeferredId should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  async instantiate(additionalImports, {loadDeferredModules, loadDeferredId} = {}) {
    let dartInstance;

    // Prints to the console
    function printToConsole(value) {
      if (typeof dartPrint == "function") {
        dartPrint(value);
        return;
      }
      if (typeof console == "object" && typeof console.log != "undefined") {
        console.log(value);
        return;
      }
      if (typeof print == "function") {
        print(value);
        return;
      }

      throw "Unable to print message: " + value;
    }

    // A special symbol attached to functions that wrap Dart functions.
    const jsWrappedDartFunctionSymbol = Symbol("JSWrappedDartFunction");

    function finalizeWrapper(dartFunction, wrapped) {
      wrapped.dartFunction = dartFunction;
      wrapped[jsWrappedDartFunctionSymbol] = true;
      return wrapped;
    }

    // Imports
    const dart2wasm = {
            AB: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      AC: Function.prototype.call.bind(DataView.prototype.setInt16),
      AD: x0 => x0.height,
      AE: x0 => x0.languages,
      AF: x0 => x0.deltaX,
      AG: x0 => x0.url,
      AH: x0 => x0.arrayBuffer(),
      AI: x0 => x0.click(),
      AJ: (x0,x1,x2,x3) => x0.removeEventListener(x1,x2,x3),
      AK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      AL: () => new XMLHttpRequest(),
      AM: x0 => x0.history,
      AN: x0 => x0.repeat,
      B: s => printToConsole(s),
      BB: b => !!b,
      BC: Function.prototype.call.bind(DataView.prototype.setUint16),
      BD: x0 => x0.width,
      BE: (x0,x1) => x0.observe(x1),
      BF: x0 => x0.wheelDeltaY,
      BG: x0 => x0.status,
      BH: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof ArrayBuffer) return 1;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 2;
        }
        return 3;
      },
      BI: (x0,x1) => x0.getElementsByClassName(x1),
      BJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      BK: (x0,x1,x2) => x0.addEventListener(x1,x2),
      BL: x0 => x0.input,
      BM: (x0,x1) => { x0.backgroundColor = x1 },
      BN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      C: Function.prototype.call.bind(Number.prototype.toString),
      CB: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      CC: Function.prototype.call.bind(DataView.prototype.setUint8),
      CD: x0 => x0.screen,
      CE: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      CF: x0 => x0.wheelDeltaX,
      CG: x0 => x0.getReader(),
      CH: (x0,x1) => x0.fetch(x1),
      CI: (x0,x1) => x0.dispatchEvent(x1),
      CJ: (x0,x1) => { x0.dropEffect = x1 },
      CK: x0 => x0.preventDefault(),
      CL: () => globalThis.window.navigator.userAgent,
      CM: x0 => x0.origin,
      CN: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      D: Function.prototype.call.bind(BigInt.prototype.toString),
      DB: (x0,x1) => x0.focus(x1),
      DC: Function.prototype.call.bind(DataView.prototype.setInt8),
      DD: o => {
        if (o === null || o === undefined) return 0;
        if (typeof(o) === 'string') return 1;
        return 2;
      },
      DE: x0 => new ResizeObserver(x0),
      DF: x0 => x0.key,
      DG: x0 => x0.read(),
      DH: x0 => x0.fontFallbackBaseUrl,
      DI: (x0,x1) => x0.createEvent(x1),
      DJ: x0 => x0.offsetY,
      DK: x0 => x0.createRange(),
      DL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      DM: x0 => x0.appVersion,
      DN: (x0,x1) => x0.appendChild(x1),
      E: (exn) => {
        let stackString = exn.toString();
        let frames = stackString.split('\n');
        let drop = 4;
        if (frames[0].startsWith('Error')) {
            drop += 1;
        }
        return frames.slice(drop).join('\n');
      },
      EB: () => ({}),
      EC: Function.prototype.call.bind(DataView.prototype.getInt8),
      ED: x0 => x0.tabIndex,
      EE: (x0,x1) => x0.getPropertyValue(x1),
      EF: x0 => x0.pressure,
      EG: x0 => x0.value,
      EH: (x0,x1,x2,x3) => x0.pushState(x1,x2,x3),
      EI: (x0,x1,x2,x3) => x0.initEvent(x1,x2,x3),
      EJ: x0 => x0.offsetX,
      EK: (x0,x1) => x0.selectNode(x1),
      EL: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      EM: x0 => x0.platform,
      EN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      F: () => new Error().stack,
      FB: (o, p, v) => o[p] = v,
      FC: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int8Array) return 1;
        return 2;
      },
      FD: (x0,x1) => x0.contains(x1),
      FE: x0 => globalThis.parseFloat(x0),
      FF: x0 => x0.tiltY,
      FG: x0 => x0.done,
      FH: x0 => x0.history,
      FI: x0 => x0.readText(),
      FJ: x0 => x0.body,
      FK: x0 => x0.getSelection(),
      FL: (x0,x1) => x0.closest(x1),
      FM: (x0,x1) => x0.querySelectorAll(x1),
      FN: x0 => x0.message,
      G: s => JSON.stringify(s),
      GB: () => [],
      GC: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      GD: x0 => x0.activeElement,
      GE: (x0,x1) => x0.getComputedStyle(x1),
      GF: x0 => x0.tiltX,
      GG: x0 => x0.cancel(),
      GH: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      GI: x0 => x0.clipboard,
      GJ: () => globalThis.document,
      GK: x0 => x0.removeAllRanges(),
      GL: x0 => x0.blur(),
      GM: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      GN: x0 => x0.files,
      H: Function.prototype.call.bind(Number.prototype.toString),
      HB: (a, i) => a.push(i),
      HC: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      HD: x0 => x0.parentNode,
      HE: x0 => x0.documentElement,
      HF: x0 => x0.pointerType,
      HG: x0 => x0.body,
      HH: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      HI: (x0,x1) => x0.writeText(x1),
      HJ: x0 => x0.naturalHeight,
      HK: (x0,x1) => x0.addRange(x1),
      HL: x0 => x0.activeElement,
      HM: (x0,x1) => x0.forEach(x1),
      HN: (x0,x1) => { x0.multiple = x1 },
      I: Function.prototype.call.bind(String.prototype.indexOf),
      IB: x0 => new Int8Array(x0),
      IC: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      ID: x0 => x0.tagName,
      IE: x0 => x0.computedStyleMap(),
      IF: x0 => x0.pointerId,
      IG: x0 => x0.headers,
      IH: o => Object.keys(o),
      II: x0 => x0.unlock(),
      IJ: x0 => x0.naturalWidth,
      IK: () => globalThis.window,
      IL: x0 => x0.bytes,
      IM: x0 => x0.key,
      IN: (x0,x1) => { x0.accept = x1 },
      J: (s, p, i) => s.lastIndexOf(p, i),
      JB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI8ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      JC: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
      JD: x0 => x0.target,
      JE: (x0,x1) => x0.get(x1),
      JF: x0 => x0.getCoalescedEvents(),
      JG: x0 => x0.signal,
      JH: x0 => x0.state,
      JI: (x0,x1) => x0.lock(x1),
      JJ: (x0,x1) => x0.createElement(x1),
      JK: (x0,x1) => { x0.innerText = x1 },
      JL: x0 => x0.measureUserAgentSpecificMemory(),
      JM: x0 => x0.metaKey,
      JN: (x0,x1) => { x0.type = x1 },
      K: o => o,
      KB: x0 => new Uint8Array(x0),
      KC: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      KD: x0 => x0.clientY,
      KE: (o, p) => p in o,
      KF: (x0,x1) => x0.getModifierState(x1),
      KG: (handle) => clearInterval(handle),
      KH: x0 => x0.state,
      KI: x0 => x0.orientation,
      KJ: (x0,x1) => { x0.pointerEvents = x1 },
      KK: x0 => x0.offsetY,
      KL: x0 => x0.performance,
      KM: x0 => x0.shiftKey,
      KN: (x0,x1) => x0.querySelector(x1),
      L: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'number') return 1;
        return 2;
      },
      LB: x0 => new Uint8ClampedArray(x0),
      LC: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
      LD: x0 => x0.clientX,
      LE: (x0,x1) => { x0.textContent = x1 },
      LF: s => s.trimLeft(),
      LG: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      LH: (x0,x1) => x0.go(x1),
      LI: (x0,x1) => x0.querySelector(x1),
      LJ: (x0,x1) => { x0.height = x1 },
      LK: x0 => x0.offsetX,
      LL: x0 => x0.crossOriginIsolated,
      LM: x0 => x0.repeat,
      LN: x0 => x0.length,
      M: x0 => x0.index,
      MB: x0 => new Int16Array(x0),
      MC: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      MD: (x0,x1,x2) => x0.setAttribute(x1,x2),
      ME: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      MF: s => s.toUpperCase(),
      MG: () => Date.now(),
      MH: x0 => x0.hash,
      MI: (x0,x1) => { x0.title = x1 },
      MJ: (x0,x1) => { x0.width = x1 },
      MK: x0 => x0.button,
      ML: x0 => x0.isSecureContext,
      MM: x0 => x0.location,
      MN: x0 => x0.getReader(),
      N: o => String(o),
      NB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI16ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      NC: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
      ND: x0 => x0.getBoundingClientRect(),
      NE: x0 => x0.matches,
      NF: x0 => x0.pop(),
      NG: () => typeof dartUseDateNowForTicks !== "undefined",
      NH: x0 => x0.location,
      NI: (x0,x1) => x0.vibrate(x1),
      NJ: x0 => x0.style,
      NK: x0 => x0.classList,
      NL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      NM: x0 => x0.isComposing,
      NN: x0 => x0.value,
      O: o => o === undefined,
      OB: x0 => new Uint16Array(x0),
      OC: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      OD: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      OE: (x0,x1) => x0.matchMedia(x1),
      OF: x0 => x0.flags,
      OG: () => Date.now(),
      OH: x0 => x0.search,
      OI: x0 => x0.content,
      OJ: (x0,x1) => { x0.src = x1 },
      OK: x0 => x0.sheet,
      OL: x0 => x0.pathname,
      OM: x0 => x0.ctrlKey,
      ON: x0 => x0.done,
      P: (x0,x1) => x0.exec(x1),
      PB: x0 => new Int32Array(x0),
      PC: (x0,x1) => x0.querySelector(x1),
      PD: s => new Date(s * 1000).getTimezoneOffset() * 60,
      PE: x0 => x0.matches,
      PF: (a, s) => a.join(s),
      PG: () => 1000 * performance.now(),
      PH: x0 => x0.pathname,
      PI: x0 => x0.document,
      PJ: () => globalThis.document,
      PK: x0 => x0.head,
      PL: x0 => x0.contentWindow,
      PM: x0 => x0.code,
      PN: x0 => x0.read(),
      Q: (x0,x1) => { x0.lastIndex = x1 },
      QB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      QC: (x0,x1) => x0.item(x1),
      QD: Date.now,
      QE: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      QF: (x0,x1) => x0.error(x1),
      QG: (x0,x1) => x0.requestAnimationFrame(x1),
      QH: x0 => x0.parentElement,
      QI: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      QJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      QK: (x0,x1,x2) => x0.postMessage(x1,x2),
      QL: (x0,x1) => { x0.width = x1 },
      QM: x0 => x0.altKey,
      QN: x0 => x0.body,
      R: o => o,
      RB: x0 => new Uint32Array(x0),
      RC: x0 => x0.length,
      RD: (handle) => clearTimeout(handle),
      RE: f => f.dartFunction,
      RF: () => globalThis.console,
      RG: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      RH: (x0,x1) => x0.querySelectorAll(x1),
      RI: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      RJ: (x0,x1,x2) => x0.addEventListener(x1,x2),
      RK: x0 => x0.parent,
      RL: (x0,x1) => { x0.height = x1 },
      RM: (x0,x1) => x0.execCommand(x1),
      RN: (x0,x1) => new OffscreenCanvas(x0,x1),
      S: (s, m) => {
        try {
          return new RegExp(s, m);
        } catch (e) {
          return String(e);
        }
      },
      SB: x0 => new Float32Array(x0),
      SC: (x0,x1) => x0.querySelectorAll(x1),
      SD: (a, l) => a.length = l,
      SE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      SF: s => s.trimRight(),
      SG: x0 => x0.now(),
      SH: (x0,x1) => x0.removeProperty(x1),
      SI: (o, start, length) => new BigInt64Array(o.buffer, o.byteOffset + start, length),
      SJ: x0 => x0.firstElementChild,
      SK: () => globalThis.window,
      SL: (x0,x1) => { x0.border = x1 },
      SM: x0 => x0.keyCode,
      SN: x0 => x0.assetBase,
      T: o => o instanceof RegExp,
      TB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      TC: (x0,x1) => x0.getAttribute(x1),
      TD: (x0,x1) => x0.closest(x1),
      TE: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      TF: x0 => x0.blur(),
      TG: x0 => x0.performance,
      TH: (x0,x1) => x0.add(x1),
      TI: (a, i) => a.splice(i, 1)[0],
      TJ: x0 => x0.src,
      TK: (a, l) => a.length = l,
      TL: x0 => x0.style,
      TM: (x0,x1) => x0.getItem(x1),
      TN: x0 => x0.loader,
      U: (string, times) => string.repeat(times),
      UB: x0 => new Float64Array(x0),
      UC: x0 => x0.remove(),
      UD: x0 => x0.bottom,
      UE: (p, s, f) => p.then(s, (e) => f(e, e === undefined)),
      UF: x0 => x0.button,
      UG: x0 => new Uint8Array(x0),
      UH: x0 => x0.data,
      UI: (map, o) => map.get(o),
      UJ: (x0,x1) => x0.revokeObjectURL(x1),
      UK: x0 => x0.protocol,
      UL: (x0,x1) => { x0.allow = x1 },
      UM: x0 => x0.localStorage,
      UN: () => globalThis._flutter,
      V: o => o,
      VB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF64ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      VC: (x0,x1) => x0.appendChild(x1),
      VD: x0 => x0.top,
      VE: (o, i) => o[i],
      VF: x0 => x0.innerHeight,
      VG: (x0,x1,x2) => x0.slice(x1,x2),
      VH: (x0,x1) => { x0.scrollTop = x1 },
      VI: () => new WeakMap(),
      VJ: (x0,x1) => { x0.src = x1 },
      VK: (x0,x1,x2) => x0.close(x1,x2),
      VL: (x0,x1) => { x0.src = x1 },
      VM: (x0,x1,x2) => x0.setItem(x1,x2),
      W: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'boolean') return 1;
        return 2;
      },
      WB: x0 => new ArrayBuffer(x0),
      WC: (x0,x1) => x0.append(x1),
      WD: x0 => x0.right,
      WE: o => o.length,
      WF: x0 => x0.innerWidth,
      WG: (x0,x1) => x0.decode(x1),
      WH: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      WI: x0 => new WeakRef(x0),
      WJ: (x0,x1,x2,x3,x4) => globalThis.createImageBitmap(x0,x1,x2,x3,x4),
      WK: x0 => x0.close(),
      WL: (x0,x1) => x0.createElement(x1),
      WM: x0 => ({body: x0}),
      X: x0 => x0.dotAll,
      XB: (x0,x1,x2) => new Uint8Array(x0,x1,x2),
      XC: (x0,x1,x2,x3) => x0.setProperty(x1,x2,x3),
      XD: x0 => x0.left,
      XE: o => {
        if (o === undefined) return 1;
        var type = typeof o;
        if (type === 'boolean') return 2;
        if (type === 'number') return 3;
        if (type === 'string') return 4;
        if (o instanceof Array) return 5;
        if (ArrayBuffer.isView(o)) {
          if (o instanceof Int8Array) return 6;
          if (o instanceof Uint8Array) return 7;
          if (o instanceof Uint8ClampedArray) return 8;
          if (o instanceof Int16Array) return 9;
          if (o instanceof Uint16Array) return 10;
          if (o instanceof Int32Array) return 11;
          if (o instanceof Uint32Array) return 12;
          if (o instanceof Float32Array) return 13;
          if (o instanceof Float64Array) return 14;
          if (o instanceof DataView) return 15;
        }
        if (o instanceof ArrayBuffer) return 16;
        // Feature check for `SharedArrayBuffer` before doing a type-check.
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
            return 17;
        }
        if (o instanceof Promise) return 18;
        return 19;
      },
      XF: x0 => x0.height,
      XG: (x0,x1) => x0.adoptText(x1),
      XH: (x0,x1) => { x0.value = x1 },
      XI: x0 => x0.deref(),
      XJ: x0 => x0.naturalHeight,
      XK: (x0,x1) => x0.send(x1),
      XL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      XM: (x0,x1) => new Notification(x0,x1),
      Y: x0 => x0.unicode,
      YB: (x0,x1,x2) => new DataView(x0,x1,x2),
      YC: x0 => x0.style,
      YD: x0 => x0.clientY,
      YE: x0 => x0.language,
      YF: x0 => x0.width,
      YG: x0 => x0.first(),
      YH: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      YI: () => globalThis.WeakRef,
      YJ: x0 => x0.naturalWidth,
      YK: () => new Array(),
      YL: x0 => x0.userAgent,
      YM: x0 => x0.close(),
      Z: x0 => x0.ignoreCase,
      ZB: (o, p) => o[p],
      ZC: x0 => x0.debugShowSemanticsNodes,
      ZD: x0 => x0.clientX,
      ZE: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      ZF: x0 => x0.clientHeight,
      ZG: x0 => x0.next(),
      ZH: (x0,x1) => { x0.value = x1 },
      ZI: (x0,x1,x2) => x0.insertBefore(x1,x2),
      ZJ: x0 => x0.decode(),
      ZK: (x0,x1) => new WebSocket(x0,x1),
      ZL: x0 => x0.navigator,
      ZM: () => globalThis.Notification.requestPermission(),
      a: x0 => x0.multiline,
      aB: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      aC: (x0,x1) => x0.warn(x1),
      aD: x0 => x0.changedTouches,
      aE: () => globalThis.window.FinalizationRegistry,
      aF: x0 => x0.clientWidth,
      aG: x0 => x0.current(),
      aH: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      aI: x0 => x0.id,
      aJ: (x0,x1) => { x0.decoding = x1 },
      aK: x0 => x0.reason,
      aL: (x0,x1) => x0.readAsArrayBuffer(x1),
      aM: (x0,x1) => x0.removeChild(x1),
      b: (exn) => {
        if (exn instanceof Error) {
          return exn.stack;
        } else {
          return null;
        }
      },
      bB: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
      bC: x0 => x0.console,
      bD: x0 => x0.offsetY,
      bE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      bF: (x0,x1) => { x0.content = x1 },
      bG: (x0,x1) => new Intl.v8BreakIterator(x0,x1),
      bH: x0 => x0.value,
      bI: x0 => x0.offsetHeight,
      bJ: (x0,x1) => { x0.crossOrigin = x1 },
      bK: x0 => x0.code,
      bL: () => new XMLHttpRequest(),
      bM: x0 => x0.parentNode,
      c: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      cB: o => o.byteOffset,
      cC: () => globalThis.window,
      cD: x0 => x0.offsetX,
      cE: x0 => new window.FinalizationRegistry(x0),
      cF: (x0,x1) => { x0.name = x1 },
      cG: x0 => x0.v8BreakIterator,
      cH: x0 => x0.selectionDirection,
      cI: x0 => x0.offsetWidth,
      cJ: (x0,x1) => x0.createObjectURL(x1),
      cK: (o, t) => typeof o === t,
      cL: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      cM: x0 => x0.baseURI,
      d: (x0,x1) => x0.didCreateEngineInitializer(x1),
      dB: o => o.buffer,
      dC: (o, c) => o instanceof c,
      dD: x0 => x0.type,
      dE: (x0,x1) => x0.unregister(x1),
      dF: x0 => x0.head,
      dG: () => globalThis.Intl,
      dH: x0 => x0.selectionStart,
      dI: x0 => x0.stopPropagation(),
      dJ: x0 => x0.URL,
      dK: x0 => x0.data,
      dL: x0 => x0.send(),
      dM: (x0,x1) => x0.replace(x1),
      e: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      eB: Function.prototype.call.bind(DataView.prototype.getUint8),
      eC: (x0,x1) => x0[x1],
      eD: x0 => x0.maxTouchPoints,
      eE: (x0,x1) => x0.contains(x1),
      eF: (x0,x1) => x0.removeChild(x1),
      eG: (x0,x1) => x0.segment(x1),
      eH: x0 => x0.selectionEnd,
      eI: x0 => x0.disabled,
      eJ: x0 => new Blob(x0),
      eK: x0 => x0.readyState,
      eL: x0 => x0.type,
      eM: (x0,x1) => x0.warn(x1),
      f: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      fB: (b, o) => new DataView(b, o),
      fC: x0 => x0.length,
      fD: x0 => x0.platform,
      fE: (s) => +s,
      fF: x0 => x0.firstChild,
      fG: x0 => x0.index,
      fH: x0 => x0.value,
      fI: (x0,x1) => { x0.min = x1 },
      fJ: (x0,x1,x2,x3,x4) => ({type: x0,data: x1,premultiplyAlpha: x2,colorSpaceConversion: x3,preferAnimation: x4}),
      fK: (x0,x1) => { x0.binaryType = x1 },
      fL: x0 => x0.response,
      fM: (x0,x1) => x0.error(x1),
      g: (x0,x1) => ({initializeEngine: x0,autoStart: x1}),
      gB: (b, o, l) => new DataView(b, o, l),
      gC: (string, token) => string.split(token),
      gD: x0 => x0.body,
      gE: s => {
        if (!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(s)) {
          return NaN;
        }
        return parseFloat(s);
      },
      gF: x0 => x0.viewConstraints,
      gG: x0 => x0.next(),
      gH: x0 => x0.selectionDirection,
      gI: (x0,x1) => { x0.max = x1 },
      gJ: x0 => new window.ImageDecoder(x0),
      gK: x0 => ({withCredentials: x0}),
      gL: (x0,x1) => { x0.responseType = x1 },
      gM: (x0,x1) => x0.transferFromImageBitmap(x1),
      h: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      hB: Function.prototype.call.bind(DataView.prototype.getFloat64),
      hC: o => o instanceof Array,
      hD: () => globalThis.document,
      hE: s => s.trim(),
      hF: x0 => x0.hostElement,
      hG: x0 => x0.value,
      hH: x0 => x0.selectionStart,
      hI: (x0,x1) => { x0.disabled = x1 },
      hJ: x0 => x0.name,
      hK: (x0,x1) => new EventSource(x0,x1),
      hL: x0 => x0.vendor,
      hM: (x0,x1) => x0.getContext(x1),
      i: x0 => new Promise(x0),
      iB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float64Array) return 1;
        return 2;
      },
      iC: (a, i) => a[i],
      iD: (x0,x1,x2) => x0.addEventListener(x1,x2),
      iE: x0 => x0.classList,
      iF: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      iG: x0 => x0.done,
      iH: x0 => x0.selectionEnd,
      iI: (x0,x1) => { x0.scrollLeft = x1 },
      iJ: x0 => x0.repetitionCount,
      iK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      iL: x0 => x0.size,
      iM: (x0,x1) => { x0.height = x1 },
      j: (x0,x1,x2) => x0.call(x1,x2),
      jB: Function.prototype.call.bind(DataView.prototype.setFloat64),
      jC: a => a.length,
      jD: x0 => x0.hasFocus(),
      jE: x0 => x0.preventDefault(),
      jF: x0 => ({runApp: x0}),
      jG: (o, m, a) => o[m].apply(o, a),
      jH: x0 => x0.keyCode,
      jI: (x0,x1) => { x0.spellcheck = x1 },
      jJ: x0 => x0.frameCount,
      jK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      jL: (x0,x1) => x0.groupCollapsed(x1),
      jM: (x0,x1) => { x0.width = x1 },
      k: (constructor, args) => {
        const factoryFunction = constructor.bind.apply(
            constructor, [null, ...args]);
        return new factoryFunction();
      },
      kB: (t, s) => t.set(s),
      kC: (x0,x1) => x0.test(x1),
      kD: x0 => x0.relatedTarget,
      kE: x0 => x0.parent,
      kF: () => {
        return typeof process != "undefined" &&
               Object.prototype.toString.call(process) == "[object process]" &&
               process.platform == "win32"
      },
      kG: x0 => x0.iterator,
      kH: (x0,x1) => x0.scrollIntoView(x1),
      kI: (x0,x1) => { x0.disabled = x1 },
      kJ: x0 => x0.selectedTrack,
      kK: x0 => x0.close(),
      kL: (x0,x1) => x0.log(x1),
      kM: x0 => x0.height,
      l: x0 => new Array(x0),
      lB: Function.prototype.call.bind(DataView.prototype.setFloat32),
      lC: x0 => x0.userAgent,
      lD: x0 => x0.shiftKey,
      lE: x0 => x0.timeStamp,
      lF: () => {
        // On browsers return `globalThis.location.href`
        if (globalThis.location != null) {
          return globalThis.location.href;
        }
        return null;
      },
      lG: () => globalThis.Symbol,
      lH: x0 => x0.multiViewEnabled,
      lI: (a, i) => a.splice(i, 1),
      lJ: x0 => x0.completed,
      lK: (x0,x1,x2) => ({method: x0,body: x1,credentials: x2}),
      lL: x0 => x0.groupEnd(),
      lM: x0 => x0.width,
      m: o => [o],
      mB: Function.prototype.call.bind(DataView.prototype.getFloat32),
      mC: x0 => x0.navigator,
      mD: (decoder, codeUnits) => decoder.decode(codeUnits),
      mE: (x0,x1) => x0.hasAttribute(x1),
      mF: (o, p) => p in o,
      mG: (x0,x1) => new Intl.Segmenter(x0,x1),
      mH: (x0,x1) => x0.replaceWith(x1),
      mI: a => a.pop(),
      mJ: x0 => x0.ready,
      mK: (x0,x1,x2) => x0.fetch(x1,x2),
      mL: () => globalThis.console,
      mM: x0 => x0.rasterEndMilliseconds,
      n: (o0, o1) => [o0, o1],
      nB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float32Array) return 1;
        return 2;
      },
      nC: Function.prototype.call.bind(String.prototype.toLowerCase),
      nD: () => new TextDecoder("utf-8", {fatal: true}),
      nE: x0 => x0.buttons,
      nF: x0 => x0.groups,
      nG: x0 => x0.Segmenter,
      nH: (x0,x1) => { x0.type = x1 },
      nI: (map, o, v) => map.set(o, v),
      nJ: x0 => x0.tracks,
      nK: x0 => x0.location,
      nL: x0 => new Blob(x0),
      nM: x0 => x0.rasterStartMilliseconds,
      o: (o0, o1, o2) => [o0, o1, o2],
      oB: Function.prototype.call.bind(DataView.prototype.getUint32),
      oC: Object.is,
      oD: () => new TextDecoder("utf-8", {fatal: false}),
      oE: x0 => x0.ctrlKey,
      oF: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      oG: x0 => x0.buffer,
      oH: (x0,x1) => { x0.className = x1 },
      oI: x0 => x0.preventDefault(),
      oJ: x0 => x0.close(),
      oK: o => o.byteLength,
      oL: x0 => globalThis.URL.createObjectURL(x0),
      oM: x0 => x0.imageBitmaps,
      p: (o0, o1, o2, o3) => [o0, o1, o2, o3],
      pB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint32Array) return 1;
        return 2;
      },
      pC: x0 => x0.vendor,
      pD: (a, i, v) => a[i] = v,
      pE: x0 => x0.y,
      pF: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF64ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      pG: x0 => x0.wasmMemory,
      pH: (x0,x1) => { x0.tabIndex = x1 },
      pI: (x0,x1) => x0.item(x1),
      pJ: (x0,x1) => ({frameIndex: x0,completeFramesOnly: x1}),
      pK: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      pL: (x0,x1,x2) => x0.setAttribute(x1,x2),
      pM: x0 => x0.canvasKitMaximumSurfaces,
      q: (x0,x1,x2) => { x0[x1] = x2 },
      qB: Function.prototype.call.bind(DataView.prototype.getInt32),
      qC: (x0,x1) => x0.createTextNode(x1),
      qD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI8ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      qE: x0 => x0.x,
      qF: (a, b) => a == b ? 0 : (a > b ? 1 : -1),
      qG: () => globalThis.window._flutter_skwasmInstance,
      qH: (x0,x1) => { x0.name = x1 },
      qI: () => new FileReader(),
      qJ: (x0,x1) => x0.decode(x1),
      qK: (a, s, e) => a.slice(s, e),
      qL: (x0,x1) => x0.append(x1),
      qM: x0 => x0.nextSibling,
      r: (o, p) => o[p],
      rB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int32Array) return 1;
        return 2;
      },
      rC: (x0,x1) => { x0.id = x1 },
      rD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI16ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      rE: x0 => x0.scrollTop,
      rF: x0 => x0.abort(),
      rG: () => new TextDecoder(),
      rH: (x0,x1) => { x0.placeholder = x1 },
      rI: (x0,x1) => x0.readAsText(x1),
      rJ: x0 => x0.displayHeight,
      rK: x0 => x0.decode(),
      rL: x0 => x0.click(),
      rM: (x0,x1) => x0.debug(x1),
      s: () => globalThis,
      sB: o => o instanceof Uint16Array,
      sC: (x0,x1) => { x0.nonce = x1 },
      sD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      sE: x0 => x0.offsetTop,
      sF: () => new AbortController(),
      sG: (d, digits) => d.toFixed(digits),
      sH: (x0,x1) => { x0.autocomplete = x1 },
      sI: x0 => x0.lastModified,
      sJ: x0 => x0.displayWidth,
      sK: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      sL: x0 => x0.remove(),
      sM: x0 => x0.hostElement,
      t: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      tB: Function.prototype.call.bind(DataView.prototype.getUint16),
      tC: x0 => x0.nonce,
      tD: x0 => x0.visibilityState,
      tE: x0 => x0.scrollLeft,
      tF: (x0,x1,x2,x3,x4,x5) => ({method: x0,headers: x1,body: x2,credentials: x3,redirect: x4,signal: x5}),
      tG: x0 => x0.maxHeight,
      tH: (x0,x1) => { x0.name = x1 },
      tI: x0 => x0.name,
      tJ: x0 => x0.duration,
      tK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      tL: (x0,x1) => { x0.display = x1 },
      tM: x0 => x0.location,
      u: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      uB: o => o instanceof Int16Array,
      uC: () => globalThis.window.flutterConfiguration,
      uD: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      uE: x0 => x0.offsetLeft,
      uF: (x0,x1) => globalThis.fetch(x0,x1),
      uG: x0 => x0.maxWidth,
      uH: (x0,x1) => { x0.placeholder = x1 },
      uI: x0 => x0.result,
      uJ: x0 => x0.image,
      uK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      uL: x0 => x0.origin,
      uM: (x0,x1) => x0.getModifierState(x1),
      v: (x0,x1) => ({addView: x0,removeView: x1}),
      vB: Function.prototype.call.bind(DataView.prototype.getInt16),
      vC: (x0,x1) => x0.attachShadow(x1),
      vD: x0 => x0.disconnect(),
      vE: x0 => x0.offsetParent,
      vF: (x0,x1) => x0.get(x1),
      vG: x0 => x0.minHeight,
      vH: (x0,x1) => { x0.action = x1 },
      vI: x0 => x0.type,
      vJ: () => globalThis.window.ImageDecoder,
      vK: x0 => x0.send(),
      vL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      vM: x0 => x0.metaKey,
      w: (l, r) => l === r,
      wB: o => o instanceof Uint8ClampedArray,
      wC: (x0,x1) => x0.createElement(x1),
      wD: x0 => new Intl.Locale(x0),
      wE: (o, p, r) => o.replace(p, () => r),
      wF: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      wG: x0 => x0.minWidth,
      wH: (x0,x1) => { x0.method = x1 },
      wI: x0 => x0.length,
      wJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      wK: x0 => x0.status,
      wL: (d, precision) => d.toPrecision(precision),
      wM: x0 => x0.altKey,
      x: x0 => x0.random(),
      xB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint8Array) return 1;
        return 2;
      },
      xC: x0 => x0.scale,
      xD: x0 => x0.region,
      xE: (o, p, r) => o.replaceAll(p, () => r),
      xF: (x0,x1) => x0.forEach(x1),
      xG: x0 => x0.debugSkipFontRetryDelay,
      xH: (x0,x1) => { x0.noValidate = x1 },
      xI: x0 => x0.files,
      xJ: (x0,x1) => x0.append(x1),
      xK: x0 => x0.response,
      xL: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      xM: x0 => x0.ctrlKey,
      y: () => globalThis.Math,
      yB: Function.prototype.call.bind(DataView.prototype.setInt32),
      yC: x0 => x0.visualViewport,
      yD: x0 => x0.script,
      yE: x0 => x0.deltaMode,
      yF: x0 => x0.name,
      yG: x0 => x0.status,
      yH: (x0,x1) => x0.removeAttribute(x1),
      yI: x0 => x0.dataTransfer,
      yJ: (x0,x1,x2) => x0.insertRule(x1,x2),
      yK: (x0,x1,x2) => x0.setRequestHeader(x1,x2),
      yL: x0 => x0.reload(),
      yM: x0 => x0.isComposing,
      z: (x0,x1) => x0.prepend(x1),
      zB: Function.prototype.call.bind(DataView.prototype.setUint32),
      zC: x0 => x0.devicePixelRatio,
      zD: x0 => x0.language,
      zE: x0 => x0.deltaY,
      zF: x0 => x0.statusText,
      zG: (x0,x1,x2) => x0.set(x1,x2),
      zH: x0 => x0.isConnected,
      zI: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      zJ: (x0,x1) => x0.add(x1),
      zK: (x0,x1) => { x0.responseType = x1 },
      zL: x0 => x0.state,
      zM: x0 => x0.code,

    };

    const baseImports = {
      _: dart2wasm,
      Math: Math,
      Date: Date,
      Object: Object,
      Array: Array,
      Reflect: Reflect,
      WebAssembly: {
        JSTag: WebAssembly.JSTag,
      },
      "": new Proxy({}, { get(_, prop) { return prop; } }),

    };

    const jsStringPolyfill = {
      "charCodeAt": (s, i) => s.charCodeAt(i),
      "compare": (s1, s2) => {
        if (s1 < s2) return -1;
        if (s1 > s2) return 1;
        return 0;
      },
      "concat": (s1, s2) => s1 + s2,
      "equals": (s1, s2) => s1 === s2,
      "fromCharCode": (i) => String.fromCharCode(i),
      "length": (s) => s.length,
      "substring": (s, a, b) => s.substring(a, b),
      "fromCharCodeArray": (a, start, end) => {
        if (end <= start) return '';

        const read = dartInstance.exports.$wasmI16ArrayGet;
        let result = '';
        let index = start;
        const chunkLength = Math.min(end - index, 500);
        let array = new Array(chunkLength);
        while (index < end) {
          const newChunkLength = Math.min(end - index, 500);
          for (let i = 0; i < newChunkLength; i++) {
            array[i] = read(a, index++);
          }
          if (newChunkLength < chunkLength) {
            array = array.slice(0, newChunkLength);
          }
          result += String.fromCharCode(...array);
        }
        return result;
      },
      "intoCharCodeArray": (s, a, start) => {
        if (s === '') return 0;

        const write = dartInstance.exports.$wasmI16ArraySet;
        for (var i = 0; i < s.length; ++i) {
          write(a, start++, s.charCodeAt(i));
        }
        return s.length;
      },
      "test": (s) => typeof s == "string",
    };


    

    dartInstance = await WebAssembly.instantiate(this.module, {
      ...baseImports,
      ...additionalImports,
      
      "wasm:js-string": jsStringPolyfill,
    });

    return new InstantiatedApp(this, dartInstance);
  }
}

class InstantiatedApp {
  constructor(compiledApp, instantiatedModule) {
    this.compiledApp = compiledApp;
    this.instantiatedModule = instantiatedModule;
  }

  // Call the main function with the given arguments.
  invokeMain(...args) {
    this.instantiatedModule.exports.$invokeMain(args);
  }
}

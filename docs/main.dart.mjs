// Compiles a dart2wasm-generated main module from `source` which can then
// instantiatable via the `instantiate` method.
//
// `source` needs to be a `Response` object (or promise thereof) e.g. created
// via the `fetch()` JS API.
export async function compileStreaming(source) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(
      await WebAssembly.compileStreaming(source, builtins), builtins);
}

// Compiles a dart2wasm-generated wasm modules from `bytes` which is then
// instantiatable via the `instantiate` method.
export async function compile(bytes) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(await WebAssembly.compile(bytes, builtins), builtins);
}

// DEPRECATED: Please use `compile` or `compileStreaming` to get a compiled app,
// use `instantiate` method to get an instantiated app and then call
// `invokeMain` to invoke the main function.
export async function instantiate(modulePromise, importObjectPromise) {
  var moduleOrCompiledApp = await modulePromise;
  if (!(moduleOrCompiledApp instanceof CompiledApp)) {
    moduleOrCompiledApp = new CompiledApp(moduleOrCompiledApp);
  }
  const instantiatedApp = await moduleOrCompiledApp.instantiate(await importObjectPromise);
  return instantiatedApp.instantiatedModule;
}

// DEPRECATED: Please use `compile` or `compileStreaming` to get a compiled app,
// use `instantiate` method to get an instantiated app and then call
// `invokeMain` to invoke the main function.
export const invoke = (moduleInstance, ...args) => {
  moduleInstance.exports.$invokeMain(args);
}

class CompiledApp {
  constructor(module, builtins) {
    this.module = module;
    this.builtins = builtins;
  }

  // The second argument is an options object containing:
  // `loadDeferredModules` is a JS function that takes an array of module names
  //   matching wasm files produced by the dart2wasm compiler. It also takes a
  //   callback that should be invoked for each loaded module with 2 arugments:
  //   (1) the module name, (2) the loaded module in a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`. The callback
  //   returns a Promise that resolves when the module is instantiated.
  //   loadDeferredModules should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  // `loadDeferredId` is a JS function that takes load ID produced by the
  //   compiler when the `load-ids` option is passed. Each load ID maps to one
  //   or more wasm files as specified in the emitted JSON file. It also takes a
  //   callback that should be invoked for each loaded module with 2 arugments:
  //   (1) the module name, (2) the loaded module in a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`. The callback
  //   returns a Promise that resolves when the module is instantiated.
  //   loadDeferredModules should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  // `loadDynamicModule` is a JS function that takes two string names matching,
  //   in order, a wasm file produced by the dart2wasm compiler during dynamic
  //   module compilation and a corresponding js file produced by the same
  //   compilation. It also takes a callback that should be invoked with the
  //   loaded module in a format supported by `WebAssembly.compile` or
  //   `WebAssembly.compileStreaming` and the result of using the JS 'import'
  //   API on the js file path. It should return a Promise that resolves when
  //   all the modules have been loaded and the callback promises have resolved.
  async instantiate(additionalImports,
      {loadDeferredModules, loadDynamicModule, loadDeferredId} = {}) {
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
            _1: (decoder, codeUnits) => decoder.decode(codeUnits),
      _2: () => new TextDecoder("utf-8", {fatal: true}),
      _3: () => new TextDecoder("utf-8", {fatal: false}),
      _4: (s) => +s,
      _5: x0 => new Uint8Array(x0),
      _6: (x0,x1,x2) => x0.set(x1,x2),
      _7: (x0,x1) => x0.transferFromImageBitmap(x1),
      _8: x0 => x0.arrayBuffer(),
      _9: (x0,x1,x2) => x0.slice(x1,x2),
      _10: (x0,x1) => x0.decode(x1),
      _11: (x0,x1) => x0.segment(x1),
      _12: () => new TextDecoder(),
      _14: x0 => x0.buffer,
      _15: x0 => x0.wasmMemory,
      _16: () => globalThis.window._flutter_skwasmInstance,
      _17: x0 => x0.rasterStartMilliseconds,
      _18: x0 => x0.rasterEndMilliseconds,
      _19: x0 => x0.imageBitmaps,
      _135: (x0,x1) => x0.appendChild(x1),
      _166: (x0,x1,x2) => x0.addEventListener(x1,x2),
      _167: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      _168: (x0,x1) => new OffscreenCanvas(x0,x1),
      _169: x0 => x0.remove(),
      _170: (x0,x1) => x0.append(x1),
      _172: x0 => x0.unlock(),
      _173: x0 => x0.getReader(),
      _174: (x0,x1) => x0.item(x1),
      _175: x0 => x0.next(),
      _176: x0 => x0.now(),
      _177: (x0,x1) => x0.revokeObjectURL(x1),
      _178: x0 => x0.close(),
      _179: (x0,x1,x2,x3,x4) => ({type: x0,data: x1,premultiplyAlpha: x2,colorSpaceConversion: x3,preferAnimation: x4}),
      _180: x0 => new window.ImageDecoder(x0),
      _181: (x0,x1) => ({frameIndex: x0,completeFramesOnly: x1}),
      _182: (x0,x1) => x0.decode(x1),
      _183: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._183(f,arguments.length,x0) }),
      _184: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      _186: (x0,x1) => x0.getModifierState(x1),
      _187: x0 => x0.preventDefault(),
      _188: x0 => x0.stopPropagation(),
      _189: (x0,x1) => x0.removeProperty(x1),
      _190: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._190(f,arguments.length,x0) }),
      _191: x0 => new window.FinalizationRegistry(x0),
      _192: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      _194: (x0,x1) => x0.unregister(x1),
      _195: (x0,x1) => x0.prepend(x1),
      _196: x0 => new Intl.Locale(x0),
      _197: (x0,x1) => x0.observe(x1),
      _198: x0 => x0.disconnect(),
      _199: (x0,x1) => x0.getAttribute(x1),
      _200: (x0,x1) => x0.contains(x1),
      _201: (x0,x1) => x0.querySelector(x1),
      _202: (x0,x1) => x0.matchMedia(x1),
      _203: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._203(f,arguments.length,x0) }),
      _204: (x0,x1,x2) => x0.call(x1,x2),
      _205: x0 => x0.blur(),
      _206: x0 => x0.hasFocus(),
      _207: (x0,x1) => x0.removeAttribute(x1),
      _208: (x0,x1,x2) => x0.insertBefore(x1,x2),
      _209: (x0,x1) => x0.hasAttribute(x1),
      _210: (x0,x1) => x0.getModifierState(x1),
      _211: (x0,x1) => x0.createTextNode(x1),
      _212: x0 => x0.getBoundingClientRect(),
      _213: (x0,x1) => x0.replaceWith(x1),
      _214: (x0,x1) => x0.contains(x1),
      _215: (x0,x1) => x0.closest(x1),
      _653: x0 => new Uint8Array(x0),
      _656: () => globalThis.window.flutterConfiguration,
      _658: x0 => x0.assetBase,
      _663: x0 => x0.canvasKitMaximumSurfaces,
      _664: x0 => x0.debugShowSemanticsNodes,
      _665: x0 => x0.hostElement,
      _666: x0 => x0.multiViewEnabled,
      _667: x0 => x0.nonce,
      _669: x0 => x0.fontFallbackBaseUrl,
      _679: x0 => x0.console,
      _680: x0 => x0.devicePixelRatio,
      _681: x0 => x0.document,
      _682: x0 => x0.history,
      _683: x0 => x0.innerHeight,
      _684: x0 => x0.innerWidth,
      _685: x0 => x0.location,
      _686: x0 => x0.navigator,
      _687: x0 => x0.visualViewport,
      _688: x0 => x0.performance,
      _689: x0 => x0.parent,
      _691: x0 => x0.URL,
      _693: (x0,x1) => x0.getComputedStyle(x1),
      _694: x0 => x0.screen,
      _695: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._695(f,arguments.length,x0) }),
      _696: (x0,x1) => x0.requestAnimationFrame(x1),
      _700: (x0,x1) => x0.warn(x1),
      _703: x0 => globalThis.parseFloat(x0),
      _704: () => globalThis.window,
      _705: () => globalThis.Intl,
      _706: () => globalThis.Symbol,
      _707: (x0,x1,x2,x3,x4) => globalThis.createImageBitmap(x0,x1,x2,x3,x4),
      _709: x0 => x0.clipboard,
      _710: x0 => x0.maxTouchPoints,
      _711: x0 => x0.vendor,
      _712: x0 => x0.language,
      _713: x0 => x0.platform,
      _714: x0 => x0.userAgent,
      _715: (x0,x1) => x0.vibrate(x1),
      _716: x0 => x0.languages,
      _717: x0 => x0.documentElement,
      _718: (x0,x1) => x0.querySelector(x1),
      _719: (x0,x1) => x0.querySelectorAll(x1),
      _721: (x0,x1) => x0.createElement(x1),
      _724: (x0,x1) => x0.createEvent(x1),
      _725: x0 => x0.activeElement,
      _728: x0 => x0.head,
      _729: x0 => x0.body,
      _731: (x0,x1) => { x0.title = x1 },
      _734: x0 => x0.visibilityState,
      _735: () => globalThis.document,
      _736: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._736(f,arguments.length,x0) }),
      _737: (x0,x1) => x0.dispatchEvent(x1),
      _745: x0 => x0.target,
      _747: x0 => x0.timeStamp,
      _748: x0 => x0.type,
      _750: (x0,x1,x2,x3) => x0.initEvent(x1,x2,x3),
      _757: x0 => x0.firstChild,
      _761: x0 => x0.parentElement,
      _763: (x0,x1) => { x0.textContent = x1 },
      _764: x0 => x0.parentNode,
      _766: (x0,x1) => x0.removeChild(x1),
      _767: x0 => x0.isConnected,
      _775: x0 => x0.clientHeight,
      _776: x0 => x0.clientWidth,
      _777: x0 => x0.offsetHeight,
      _778: x0 => x0.offsetWidth,
      _779: x0 => x0.id,
      _780: (x0,x1) => { x0.id = x1 },
      _783: (x0,x1) => { x0.spellcheck = x1 },
      _784: x0 => x0.tagName,
      _785: x0 => x0.style,
      _787: (x0,x1) => x0.querySelectorAll(x1),
      _788: (x0,x1,x2) => x0.setAttribute(x1,x2),
      _789: x0 => x0.tabIndex,
      _790: (x0,x1) => { x0.tabIndex = x1 },
      _791: (x0,x1) => x0.focus(x1),
      _792: x0 => x0.scrollTop,
      _793: (x0,x1) => { x0.scrollTop = x1 },
      _794: (x0,x1) => { x0.scrollLeft = x1 },
      _795: x0 => x0.scrollLeft,
      _796: x0 => x0.classList,
      _797: (x0,x1) => x0.scrollIntoView(x1),
      _800: (x0,x1) => { x0.className = x1 },
      _802: (x0,x1) => x0.getElementsByClassName(x1),
      _803: x0 => x0.click(),
      _804: (x0,x1) => x0.attachShadow(x1),
      _807: x0 => x0.computedStyleMap(),
      _808: (x0,x1) => x0.get(x1),
      _814: (x0,x1) => x0.getPropertyValue(x1),
      _815: (x0,x1,x2,x3) => x0.setProperty(x1,x2,x3),
      _816: x0 => x0.offsetLeft,
      _817: x0 => x0.offsetTop,
      _818: x0 => x0.offsetParent,
      _820: (x0,x1) => { x0.name = x1 },
      _821: x0 => x0.content,
      _822: (x0,x1) => { x0.content = x1 },
      _826: (x0,x1) => { x0.src = x1 },
      _827: x0 => x0.naturalWidth,
      _828: x0 => x0.naturalHeight,
      _832: (x0,x1) => { x0.crossOrigin = x1 },
      _834: (x0,x1) => { x0.decoding = x1 },
      _835: x0 => x0.decode(),
      _840: (x0,x1) => { x0.nonce = x1 },
      _845: (x0,x1) => { x0.width = x1 },
      _847: (x0,x1) => { x0.height = x1 },
      _850: (x0,x1) => x0.getContext(x1),
      _918: x0 => x0.width,
      _919: x0 => x0.height,
      _921: (x0,x1) => x0.fetch(x1),
      _922: x0 => x0.status,
      _924: x0 => x0.body,
      _925: x0 => x0.arrayBuffer(),
      _928: x0 => x0.read(),
      _929: x0 => x0.value,
      _930: x0 => x0.done,
      _937: x0 => x0.name,
      _938: x0 => x0.x,
      _939: x0 => x0.y,
      _942: x0 => x0.top,
      _943: x0 => x0.right,
      _944: x0 => x0.bottom,
      _945: x0 => x0.left,
      _955: x0 => x0.height,
      _956: x0 => x0.width,
      _957: x0 => x0.scale,
      _958: (x0,x1) => { x0.value = x1 },
      _961: (x0,x1) => { x0.placeholder = x1 },
      _963: (x0,x1) => { x0.name = x1 },
      _964: x0 => x0.selectionDirection,
      _965: x0 => x0.selectionStart,
      _966: x0 => x0.selectionEnd,
      _969: x0 => x0.value,
      _971: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      _972: x0 => x0.readText(),
      _973: (x0,x1) => x0.writeText(x1),
      _975: x0 => x0.altKey,
      _976: x0 => x0.code,
      _977: x0 => x0.ctrlKey,
      _978: x0 => x0.key,
      _979: x0 => x0.keyCode,
      _980: x0 => x0.location,
      _981: x0 => x0.metaKey,
      _982: x0 => x0.repeat,
      _983: x0 => x0.shiftKey,
      _984: x0 => x0.isComposing,
      _986: x0 => x0.state,
      _987: (x0,x1) => x0.go(x1),
      _989: (x0,x1,x2,x3) => x0.pushState(x1,x2,x3),
      _990: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      _991: x0 => x0.pathname,
      _992: x0 => x0.search,
      _993: x0 => x0.hash,
      _997: x0 => x0.state,
      _1000: (x0,x1) => x0.createObjectURL(x1),
      _1002: x0 => new Blob(x0),
      _1012: x0 => x0.matches,
      _1016: x0 => x0.matches,
      _1020: x0 => x0.relatedTarget,
      _1022: x0 => x0.clientX,
      _1023: x0 => x0.clientY,
      _1024: x0 => x0.offsetX,
      _1025: x0 => x0.offsetY,
      _1028: x0 => x0.button,
      _1029: x0 => x0.buttons,
      _1030: x0 => x0.ctrlKey,
      _1034: x0 => x0.pointerId,
      _1035: x0 => x0.pointerType,
      _1036: x0 => x0.pressure,
      _1037: x0 => x0.tiltX,
      _1038: x0 => x0.tiltY,
      _1039: x0 => x0.getCoalescedEvents(),
      _1042: x0 => x0.deltaX,
      _1043: x0 => x0.deltaY,
      _1044: x0 => x0.wheelDeltaX,
      _1045: x0 => x0.wheelDeltaY,
      _1046: x0 => x0.deltaMode,
      _1053: x0 => x0.changedTouches,
      _1056: x0 => x0.clientX,
      _1057: x0 => x0.clientY,
      _1060: x0 => x0.data,
      _1063: (x0,x1) => { x0.disabled = x1 },
      _1065: (x0,x1) => { x0.type = x1 },
      _1066: (x0,x1) => { x0.max = x1 },
      _1067: (x0,x1) => { x0.min = x1 },
      _1068: x0 => x0.value,
      _1069: (x0,x1) => { x0.value = x1 },
      _1070: x0 => x0.disabled,
      _1071: (x0,x1) => { x0.disabled = x1 },
      _1073: (x0,x1) => { x0.placeholder = x1 },
      _1075: (x0,x1) => { x0.name = x1 },
      _1076: (x0,x1) => { x0.autocomplete = x1 },
      _1078: x0 => x0.selectionDirection,
      _1079: x0 => x0.selectionStart,
      _1081: x0 => x0.selectionEnd,
      _1084: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      _1085: (x0,x1) => x0.add(x1),
      _1087: (x0,x1) => { x0.noValidate = x1 },
      _1088: (x0,x1) => { x0.method = x1 },
      _1089: (x0,x1) => { x0.action = x1 },
      _1095: (x0,x1) => x0.getContext(x1),
      _1097: x0 => x0.convertToBlob(),
      _1114: x0 => x0.orientation,
      _1115: x0 => x0.width,
      _1116: x0 => x0.height,
      _1117: (x0,x1) => x0.lock(x1),
      _1136: x0 => new ResizeObserver(x0),
      _1139: (module,f) => finalizeWrapper(f, function(x0,x1) { return module.exports._1139(f,arguments.length,x0,x1) }),
      _1147: x0 => x0.length,
      _1148: x0 => x0.iterator,
      _1149: x0 => x0.Segmenter,
      _1150: x0 => x0.v8BreakIterator,
      _1151: (x0,x1) => new Intl.Segmenter(x0,x1),
      _1154: x0 => x0.language,
      _1155: x0 => x0.script,
      _1156: x0 => x0.region,
      _1174: x0 => x0.done,
      _1175: x0 => x0.value,
      _1176: x0 => x0.index,
      _1180: (x0,x1) => new Intl.v8BreakIterator(x0,x1),
      _1181: (x0,x1) => x0.adoptText(x1),
      _1182: x0 => x0.first(),
      _1183: x0 => x0.next(),
      _1184: x0 => x0.current(),
      _1186: () => globalThis.window.FinalizationRegistry,
      _1197: x0 => x0.hostElement,
      _1198: x0 => x0.viewConstraints,
      _1201: x0 => x0.maxHeight,
      _1202: x0 => x0.maxWidth,
      _1203: x0 => x0.minHeight,
      _1204: x0 => x0.minWidth,
      _1205: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1205(f,arguments.length,x0) }),
      _1206: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1206(f,arguments.length,x0) }),
      _1207: (x0,x1) => ({addView: x0,removeView: x1}),
      _1210: x0 => x0.loader,
      _1211: () => globalThis._flutter,
      _1212: (x0,x1) => x0.didCreateEngineInitializer(x1),
      _1213: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1213(f,arguments.length,x0) }),
      _1214: (module,f) => finalizeWrapper(f, function() { return module.exports._1214(f,arguments.length) }),
      _1215: (x0,x1) => ({initializeEngine: x0,autoStart: x1}),
      _1218: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1218(f,arguments.length,x0) }),
      _1219: x0 => ({runApp: x0}),
      _1221: (module,f) => finalizeWrapper(f, function(x0,x1) { return module.exports._1221(f,arguments.length,x0,x1) }),
      _1222: x0 => new Promise(x0),
      _1223: x0 => x0.length,
      _1224: () => globalThis.window.ImageDecoder,
      _1225: x0 => x0.tracks,
      _1227: x0 => x0.completed,
      _1229: x0 => x0.image,
      _1235: x0 => x0.displayWidth,
      _1236: x0 => x0.displayHeight,
      _1237: x0 => x0.duration,
      _1240: x0 => x0.ready,
      _1241: x0 => x0.selectedTrack,
      _1242: x0 => x0.repetitionCount,
      _1243: x0 => x0.frameCount,
      _1300: (x0,x1) => x0.createElement(x1),
      _1307: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      _1308: () => globalThis.Notification.requestPermission(),
      _1316: x0 => x0.toArray(),
      _1317: x0 => x0.toUint8Array(),
      _1318: x0 => ({serverTimestamps: x0}),
      _1319: x0 => ({source: x0}),
      _1320: x0 => ({merge: x0}),
      _1322: x0 => new firebase_firestore.FieldPath(x0),
      _1323: (x0,x1) => new firebase_firestore.FieldPath(x0,x1),
      _1324: (x0,x1,x2) => new firebase_firestore.FieldPath(x0,x1,x2),
      _1325: (x0,x1,x2,x3) => new firebase_firestore.FieldPath(x0,x1,x2,x3),
      _1326: (x0,x1,x2,x3,x4) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4),
      _1327: (x0,x1,x2,x3,x4,x5) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5),
      _1328: (x0,x1,x2,x3,x4,x5,x6) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6),
      _1329: (x0,x1,x2,x3,x4,x5,x6,x7) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7),
      _1330: (x0,x1,x2,x3,x4,x5,x6,x7,x8) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7,x8),
      _1331: (x0,x1,x2,x3,x4,x5,x6,x7,x8,x9) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7,x8,x9),
      _1332: () => globalThis.firebase_firestore.documentId(),
      _1333: (x0,x1) => new firebase_firestore.GeoPoint(x0,x1),
      _1334: x0 => globalThis.firebase_firestore.vector(x0),
      _1335: x0 => globalThis.firebase_firestore.Bytes.fromUint8Array(x0),
      _1336: x0 => globalThis.firebase_firestore.writeBatch(x0),
      _1337: (x0,x1) => globalThis.firebase_firestore.collection(x0,x1),
      _1339: (x0,x1) => globalThis.firebase_firestore.doc(x0,x1),
      _1344: x0 => x0.call(),
      _1368: x0 => x0.commit(),
      _1369: (x0,x1) => x0.delete(x1),
      _1370: (x0,x1,x2,x3) => x0.set(x1,x2,x3),
      _1371: (x0,x1,x2) => x0.set(x1,x2),
      _1372: (x0,x1,x2) => x0.update(x1,x2),
      _1373: x0 => globalThis.firebase_firestore.deleteDoc(x0),
      _1374: x0 => globalThis.firebase_firestore.getDoc(x0),
      _1375: x0 => globalThis.firebase_firestore.getDocFromServer(x0),
      _1376: x0 => globalThis.firebase_firestore.getDocFromCache(x0),
      _1377: (x0,x1) => ({includeMetadataChanges: x0,source: x1}),
      _1378: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1378(f,arguments.length,x0) }),
      _1379: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1379(f,arguments.length,x0) }),
      _1380: (x0,x1,x2,x3) => globalThis.firebase_firestore.onSnapshot(x0,x1,x2,x3),
      _1381: (x0,x1,x2) => globalThis.firebase_firestore.onSnapshot(x0,x1,x2),
      _1382: (x0,x1,x2) => globalThis.firebase_firestore.setDoc(x0,x1,x2),
      _1383: (x0,x1) => globalThis.firebase_firestore.setDoc(x0,x1),
      _1384: (x0,x1) => globalThis.firebase_firestore.query(x0,x1),
      _1385: x0 => globalThis.firebase_firestore.getDocs(x0),
      _1386: x0 => globalThis.firebase_firestore.getDocsFromServer(x0),
      _1387: x0 => globalThis.firebase_firestore.getDocsFromCache(x0),
      _1388: x0 => globalThis.firebase_firestore.limit(x0),
      _1389: x0 => globalThis.firebase_firestore.limitToLast(x0),
      _1390: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1390(f,arguments.length,x0) }),
      _1391: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1391(f,arguments.length,x0) }),
      _1392: (x0,x1) => globalThis.firebase_firestore.orderBy(x0,x1),
      _1394: (x0,x1,x2) => globalThis.firebase_firestore.where(x0,x1,x2),
      _1397: x0 => globalThis.firebase_firestore.doc(x0),
      _1400: (x0,x1) => x0.data(x1),
      _1404: x0 => x0.docChanges(),
      _1412: () => globalThis.firebase_firestore.deleteField(),
      _1413: () => globalThis.firebase_firestore.serverTimestamp(),
      _1421: (x0,x1) => globalThis.firebase_firestore.getFirestore(x0,x1),
      _1423: x0 => globalThis.firebase_firestore.Timestamp.fromMillis(x0),
      _1424: (module,f) => finalizeWrapper(f, function() { return module.exports._1424(f,arguments.length) }),
      _1440: () => globalThis.firebase_firestore.updateDoc,
      _1441: () => globalThis.firebase_firestore.or,
      _1442: () => globalThis.firebase_firestore.and,
      _1447: x0 => x0.path,
      _1450: () => globalThis.firebase_firestore.GeoPoint,
      _1451: x0 => x0.latitude,
      _1452: x0 => x0.longitude,
      _1454: () => globalThis.firebase_firestore.VectorValue,
      _1455: () => globalThis.firebase_firestore.Bytes,
      _1458: x0 => x0.type,
      _1460: x0 => x0.doc,
      _1462: x0 => x0.oldIndex,
      _1464: x0 => x0.newIndex,
      _1466: () => globalThis.firebase_firestore.DocumentReference,
      _1470: x0 => x0.path,
      _1479: x0 => x0.metadata,
      _1480: x0 => x0.ref,
      _1485: x0 => x0.docs,
      _1487: x0 => x0.metadata,
      _1491: () => globalThis.firebase_firestore.Timestamp,
      _1492: x0 => x0.seconds,
      _1493: x0 => x0.nanoseconds,
      _1530: x0 => x0.hasPendingWrites,
      _1532: x0 => x0.fromCache,
      _1539: x0 => x0.source,
      _1544: () => globalThis.firebase_firestore.startAfter,
      _1545: () => globalThis.firebase_firestore.startAt,
      _1546: () => globalThis.firebase_firestore.endBefore,
      _1547: () => globalThis.firebase_firestore.endAt,
      _1551: x0 => globalThis.window.updatePwaTheme(x0),
      _1579: x0 => x0.toJSON(),
      _1580: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1580(f,arguments.length,x0) }),
      _1581: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1581(f,arguments.length,x0) }),
      _1582: (x0,x1,x2) => x0.onAuthStateChanged(x1,x2),
      _1583: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1583(f,arguments.length,x0) }),
      _1584: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1584(f,arguments.length,x0) }),
      _1585: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1585(f,arguments.length,x0) }),
      _1586: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1586(f,arguments.length,x0) }),
      _1587: (x0,x1,x2) => x0.onIdTokenChanged(x1,x2),
      _1591: (x0,x1,x2) => globalThis.firebase_auth.createUserWithEmailAndPassword(x0,x1,x2),
      _1601: (x0,x1,x2) => globalThis.firebase_auth.signInWithEmailAndPassword(x0,x1,x2),
      _1606: x0 => x0.signOut(),
      _1607: (x0,x1) => globalThis.firebase_auth.connectAuthEmulator(x0,x1),
      _1630: x0 => globalThis.firebase_auth.OAuthProvider.credentialFromResult(x0),
      _1645: x0 => globalThis.firebase_auth.getAdditionalUserInfo(x0),
      _1646: (x0,x1,x2) => ({errorMap: x0,persistence: x1,popupRedirectResolver: x2}),
      _1647: (x0,x1) => globalThis.firebase_auth.initializeAuth(x0,x1),
      _1653: x0 => globalThis.firebase_auth.OAuthProvider.credentialFromError(x0),
      _1668: () => globalThis.firebase_auth.debugErrorMap,
      _1671: () => globalThis.firebase_auth.browserSessionPersistence,
      _1673: () => globalThis.firebase_auth.browserLocalPersistence,
      _1675: () => globalThis.firebase_auth.indexedDBLocalPersistence,
      _1678: x0 => globalThis.firebase_auth.multiFactor(x0),
      _1679: (x0,x1) => globalThis.firebase_auth.getMultiFactorResolver(x0,x1),
      _1681: x0 => x0.currentUser,
      _1695: x0 => x0.displayName,
      _1696: x0 => x0.email,
      _1697: x0 => x0.phoneNumber,
      _1698: x0 => x0.photoURL,
      _1699: x0 => x0.providerId,
      _1700: x0 => x0.uid,
      _1701: x0 => x0.emailVerified,
      _1702: x0 => x0.isAnonymous,
      _1703: x0 => x0.providerData,
      _1704: x0 => x0.refreshToken,
      _1705: x0 => x0.tenantId,
      _1706: x0 => x0.metadata,
      _1708: x0 => x0.providerId,
      _1709: x0 => x0.signInMethod,
      _1710: x0 => x0.accessToken,
      _1711: x0 => x0.idToken,
      _1712: x0 => x0.secret,
      _1723: x0 => x0.creationTime,
      _1724: x0 => x0.lastSignInTime,
      _1729: x0 => x0.code,
      _1731: x0 => x0.message,
      _1743: x0 => x0.email,
      _1744: x0 => x0.phoneNumber,
      _1745: x0 => x0.tenantId,
      _1768: x0 => x0.user,
      _1771: x0 => x0.providerId,
      _1772: x0 => x0.profile,
      _1773: x0 => x0.username,
      _1774: x0 => x0.isNewUser,
      _1777: () => globalThis.firebase_auth.browserPopupRedirectResolver,
      _1782: x0 => x0.displayName,
      _1783: x0 => x0.enrollmentTime,
      _1784: x0 => x0.factorId,
      _1785: x0 => x0.uid,
      _1787: x0 => x0.hints,
      _1788: x0 => x0.session,
      _1790: x0 => x0.phoneNumber,
      _1802: (x0,x1) => x0.getItem(x1),
      _1807: x0 => x0.remove(),
      _1808: (x0,x1) => x0.appendChild(x1),
      _1811: (x0,x1) => x0.query(x1),
      _1812: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1812(f,arguments.length,x0) }),
      _1813: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1813(f,arguments.length,x0) }),
      _1814: (x0,x1,x2) => ({enableHighAccuracy: x0,timeout: x1,maximumAge: x2}),
      _1815: (x0,x1,x2,x3) => x0.getCurrentPosition(x1,x2,x3),
      _1816: (x0,x1) => x0.clearWatch(x1),
      _1817: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1817(f,arguments.length,x0) }),
      _1818: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1818(f,arguments.length,x0) }),
      _1819: (x0,x1,x2,x3) => x0.watchPosition(x1,x2,x3),
      _1820: (x0,x1) => x0.removeItem(x1),
      _1821: (x0,x1,x2) => x0.setItem(x1,x2),
      _1835: (x0,x1,x2,x3,x4,x5,x6,x7) => ({apiKey: x0,authDomain: x1,databaseURL: x2,projectId: x3,storageBucket: x4,messagingSenderId: x5,measurementId: x6,appId: x7}),
      _1836: (x0,x1) => globalThis.firebase_core.initializeApp(x0,x1),
      _1837: x0 => globalThis.firebase_core.getApp(x0),
      _1838: () => globalThis.firebase_core.getApp(),
      _1840: (x0,x1) => ({next: x0,error: x1}),
      _1841: x0 => ({vapidKey: x0}),
      _1842: x0 => globalThis.firebase_messaging.getMessaging(x0),
      _1844: (x0,x1) => globalThis.firebase_messaging.getToken(x0,x1),
      _1846: (x0,x1) => globalThis.firebase_messaging.onMessage(x0,x1),
      _1850: x0 => x0.title,
      _1851: x0 => x0.body,
      _1852: x0 => x0.image,
      _1853: x0 => x0.messageId,
      _1854: x0 => x0.collapseKey,
      _1855: x0 => x0.fcmOptions,
      _1856: x0 => x0.notification,
      _1857: x0 => x0.data,
      _1858: x0 => x0.from,
      _1859: x0 => x0.analyticsLabel,
      _1860: x0 => x0.link,
      _1861: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1861(f,arguments.length,x0) }),
      _1862: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1862(f,arguments.length,x0) }),
      _1864: () => globalThis.firebase_core.SDK_VERSION,
      _1870: x0 => x0.apiKey,
      _1872: x0 => x0.authDomain,
      _1874: x0 => x0.databaseURL,
      _1876: x0 => x0.projectId,
      _1878: x0 => x0.storageBucket,
      _1880: x0 => x0.messagingSenderId,
      _1882: x0 => x0.measurementId,
      _1884: x0 => x0.appId,
      _1886: x0 => x0.name,
      _1887: x0 => x0.options,
      _1888: (x0,x1) => x0.debug(x1),
      _1889: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1889(f,arguments.length,x0) }),
      _1890: (module,f) => finalizeWrapper(f, function(x0,x1) { return module.exports._1890(f,arguments.length,x0,x1) }),
      _1891: (x0,x1) => ({createScript: x0,createScriptURL: x1}),
      _1892: (x0,x1,x2) => x0.createPolicy(x1,x2),
      _1893: (x0,x1) => x0.createScriptURL(x1),
      _1894: (x0,x1,x2) => x0.createScript(x1,x2),
      _1895: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._1895(f,arguments.length,x0) }),
      _1896: x0 => ({type: x0}),
      _1897: (x0,x1) => new Blob(x0,x1),
      _1898: x0 => globalThis.URL.createObjectURL(x0),
      _1899: x0 => x0.click(),
      _1900: x0 => globalThis.URL.revokeObjectURL(x0),
      _1912: Date.now,
      _1914: s => new Date(s * 1000).getTimezoneOffset() * 60,
      _1915: s => {
        if (!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(s)) {
          return NaN;
        }
        return parseFloat(s);
      },
      _1916: () => typeof dartUseDateNowForTicks !== "undefined",
      _1917: () => 1000 * performance.now(),
      _1918: () => Date.now(),
      _1919: () => {
        // On browsers return `globalThis.location.href`
        if (globalThis.location != null) {
          return globalThis.location.href;
        }
        return null;
      },
      _1920: () => {
        return typeof process != "undefined" &&
               Object.prototype.toString.call(process) == "[object process]" &&
               process.platform == "win32"
      },
      _1921: () => new WeakMap(),
      _1922: (map, o) => map.get(o),
      _1923: (map, o, v) => map.set(o, v),
      _1924: x0 => new WeakRef(x0),
      _1925: x0 => x0.deref(),
      _1932: () => globalThis.WeakRef,
      _1935: s => JSON.stringify(s),
      _1936: s => printToConsole(s),
      _1937: o => {
        if (o === null || o === undefined) return 0;
        if (typeof(o) === 'string') return 1;
        return 2;
      },
      _1938: (o, p, r) => o.replaceAll(p, () => r),
      _1939: (o, p, r) => o.replace(p, () => r),
      _1940: Function.prototype.call.bind(String.prototype.toLowerCase),
      _1941: s => s.toUpperCase(),
      _1942: s => s.trim(),
      _1943: s => s.trimLeft(),
      _1944: s => s.trimRight(),
      _1945: (string, times) => string.repeat(times),
      _1946: Function.prototype.call.bind(String.prototype.indexOf),
      _1947: (s, p, i) => s.lastIndexOf(p, i),
      _1948: (string, token) => string.split(token),
      _1949: Object.is,
      _1954: (o, c) => o instanceof c,
      _1955: o => Object.keys(o),
      _1959: (o, a) => o + a,
      _2009: x0 => new Array(x0),
      _2011: x0 => x0.length,
      _2013: (x0,x1) => x0[x1],
      _2014: (x0,x1,x2) => { x0[x1] = x2 },
      _2017: (x0,x1,x2) => new DataView(x0,x1,x2),
      _2019: x0 => new Int8Array(x0),
      _2020: (x0,x1,x2) => new Uint8Array(x0,x1,x2),
      _2022: x0 => new Uint8ClampedArray(x0),
      _2024: x0 => new Int16Array(x0),
      _2026: x0 => new Uint16Array(x0),
      _2028: x0 => new Int32Array(x0),
      _2030: x0 => new Uint32Array(x0),
      _2032: x0 => new Float32Array(x0),
      _2034: x0 => new Float64Array(x0),
      _2058: x0 => x0.random(),
      _2059: (x0,x1) => x0.getRandomValues(x1),
      _2060: () => globalThis.crypto,
      _2061: () => globalThis.Math,
      _2074: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      _2075: (handle) => clearTimeout(handle),
      _2076: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      _2077: (handle) => clearInterval(handle),
      _2078: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      _2079: () => Date.now(),
      _2080: () => new Error().stack,
      _2081: (exn) => {
        let stackString = exn.toString();
        let frames = stackString.split('\n');
        let drop = 4;
        if (frames[0].startsWith('Error')) {
            drop += 1;
        }
        return frames.slice(drop).join('\n');
      },
      _2082: (s, m) => {
        try {
          return new RegExp(s, m);
        } catch (e) {
          return String(e);
        }
      },
      _2083: (x0,x1) => x0.exec(x1),
      _2084: (x0,x1) => x0.test(x1),
      _2085: x0 => x0.pop(),
      _2087: o => o === undefined,
      _2089: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      _2091: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      _2092: o => o instanceof RegExp,
      _2093: (l, r) => l === r,
      _2094: o => o,
      _2095: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'number') return 1;
        return 2;
      },
      _2096: o => o,
      _2097: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'boolean') return 1;
        return 2;
      },
      _2098: o => o,
      _2099: b => !!b,
      _2100: o => o.length,
      _2102: (o, i) => o[i],
      _2103: f => f.dartFunction,
      _2104: () => ({}),
      _2105: () => [],
      _2107: () => globalThis,
      _2108: (constructor, args) => {
        const factoryFunction = constructor.bind.apply(
            constructor, [null, ...args]);
        return new factoryFunction();
      },
      _2110: (o, p) => o[p],
      _2111: (o, p, v) => o[p] = v,
      _2112: (o, m, a) => o[m].apply(o, a),
      _2114: o => String(o),
      _2115: (p, s, f) => p.then(s, (e) => f(e, e === undefined)),
      _2116: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._2116(f,arguments.length,x0) }),
      _2117: (module,f) => finalizeWrapper(f, function(x0,x1) { return module.exports._2117(f,arguments.length,x0,x1) }),
      _2118: o => {
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
      _2119: o => [o],
      _2120: (o0, o1) => [o0, o1],
      _2121: (o0, o1, o2) => [o0, o1, o2],
      _2122: (o0, o1, o2, o3) => [o0, o1, o2, o3],
      _2123: (exn) => {
        if (exn instanceof Error) {
          return exn.stack;
        } else {
          return null;
        }
      },
      _2124: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI8ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2125: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI8ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2126: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI16ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2127: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI16ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2128: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2129: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2130: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2131: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2132: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF64ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2133: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF64ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2134: x0 => new ArrayBuffer(x0),
      _2135: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      _2137: x0 => x0.index,
      _2139: x0 => x0.flags,
      _2140: x0 => x0.multiline,
      _2141: x0 => x0.ignoreCase,
      _2142: x0 => x0.unicode,
      _2143: x0 => x0.dotAll,
      _2144: (x0,x1) => { x0.lastIndex = x1 },
      _2145: (o, p) => p in o,
      _2146: (o, p) => o[p],
      _2147: (o, p, v) => o[p] = v,
      _2148: (o, p) => delete o[p],
      _2167: () => new AbortController(),
      _2168: x0 => x0.abort(),
      _2169: (x0,x1,x2,x3,x4,x5) => ({method: x0,headers: x1,body: x2,credentials: x3,redirect: x4,signal: x5}),
      _2170: (x0,x1) => globalThis.fetch(x0,x1),
      _2171: (x0,x1) => x0.get(x1),
      _2172: (module,f) => finalizeWrapper(f, function(x0,x1,x2) { return module.exports._2172(f,arguments.length,x0,x1,x2) }),
      _2173: (x0,x1) => x0.forEach(x1),
      _2174: x0 => x0.getReader(),
      _2175: x0 => x0.cancel(),
      _2176: x0 => x0.read(),
      _2177: (x0,x1) => x0.matchMedia(x1),
      _2178: (module,f) => finalizeWrapper(f, function(x0) { return module.exports._2178(f,arguments.length,x0) }),
      _2179: (x0,x1,x2) => x0.addEventListener(x1,x2),
      _2180: (x0,x1) => x0.key(x1),
      _2181: x0 => x0.trustedTypes,
      _2182: (x0,x1) => { x0.text = x1 },
      _2183: o => o instanceof Array,
      _2187: a => a.pop(),
      _2188: (a, i) => a.splice(i, 1),
      _2189: (a, s) => a.join(s),
      _2190: (a, s, e) => a.slice(s, e),
      _2192: (a, b) => a == b ? 0 : (a > b ? 1 : -1),
      _2193: a => a.length,
      _2195: (a, i) => a[i],
      _2196: (a, i, v) => a[i] = v,
      _2198: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof ArrayBuffer) return 1;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 2;
        }
        return 3;
      },
      _2199: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      _2201: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint8Array) return 1;
        return 2;
      },
      _2202: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
      _2203: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int8Array) return 1;
        return 2;
      },
      _2204: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      _2205: o => o instanceof Uint8ClampedArray,
      _2206: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      _2207: o => o instanceof Uint16Array,
      _2208: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      _2209: o => o instanceof Int16Array,
      _2210: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
      _2211: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint32Array) return 1;
        return 2;
      },
      _2212: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      _2213: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int32Array) return 1;
        return 2;
      },
      _2214: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
      _2216: (o, start, length) => new BigInt64Array(o.buffer, o.byteOffset + start, length),
      _2217: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float32Array) return 1;
        return 2;
      },
      _2218: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      _2219: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float64Array) return 1;
        return 2;
      },
      _2220: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      _2221: (a, i) => a.push(i),
      _2222: (t, s) => t.set(s),
      _2223: l => new DataView(new ArrayBuffer(l)),
      _2224: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      _2226: o => o.buffer,
      _2227: o => o.byteOffset,
      _2228: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
      _2229: (b, o) => new DataView(b, o),
      _2230: (b, o, l) => new DataView(b, o, l),
      _2231: Function.prototype.call.bind(DataView.prototype.getUint8),
      _2232: Function.prototype.call.bind(DataView.prototype.setUint8),
      _2233: Function.prototype.call.bind(DataView.prototype.getInt8),
      _2234: Function.prototype.call.bind(DataView.prototype.setInt8),
      _2235: Function.prototype.call.bind(DataView.prototype.getUint16),
      _2236: Function.prototype.call.bind(DataView.prototype.setUint16),
      _2237: Function.prototype.call.bind(DataView.prototype.getInt16),
      _2238: Function.prototype.call.bind(DataView.prototype.setInt16),
      _2239: Function.prototype.call.bind(DataView.prototype.getUint32),
      _2240: Function.prototype.call.bind(DataView.prototype.setUint32),
      _2241: Function.prototype.call.bind(DataView.prototype.getInt32),
      _2242: Function.prototype.call.bind(DataView.prototype.setInt32),
      _2245: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      _2246: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      _2247: Function.prototype.call.bind(DataView.prototype.getFloat32),
      _2248: Function.prototype.call.bind(DataView.prototype.setFloat32),
      _2249: Function.prototype.call.bind(DataView.prototype.getFloat64),
      _2250: Function.prototype.call.bind(DataView.prototype.setFloat64),
      _2251: Function.prototype.call.bind(Number.prototype.toString),
      _2252: Function.prototype.call.bind(BigInt.prototype.toString),
      _2253: Function.prototype.call.bind(Number.prototype.toString),
      _2254: (d, digits) => d.toFixed(digits),
      _2390: x0 => x0.style,
      _2749: (x0,x1) => { x0.download = x1 },
      _2774: (x0,x1) => { x0.href = x1 },
      _3629: (x0,x1) => { x0.type = x1 },
      _3637: (x0,x1) => { x0.crossOrigin = x1 },
      _3639: (x0,x1) => { x0.text = x1 },
      _4096: () => globalThis.window,
      _4137: x0 => x0.location,
      _4156: x0 => x0.navigator,
      _4418: x0 => x0.trustedTypes,
      _4419: x0 => x0.sessionStorage,
      _4420: x0 => x0.localStorage,
      _4435: x0 => x0.hostname,
      _4526: x0 => x0.geolocation,
      _4529: x0 => x0.mediaDevices,
      _4531: x0 => x0.permissions,
      _4545: x0 => x0.userAgent,
      _4753: x0 => x0.length,
      _6698: x0 => x0.signal,
      _6772: () => globalThis.document,
      _6853: x0 => x0.body,
      _6855: x0 => x0.head,
      _8532: x0 => x0.value,
      _8534: x0 => x0.done,
      _8957: () => globalThis.Notification.permission,
      _9234: x0 => x0.url,
      _9236: x0 => x0.status,
      _9238: x0 => x0.statusText,
      _9239: x0 => x0.headers,
      _9240: x0 => x0.body,
      _9522: x0 => x0.matches,
      _9627: x0 => x0.state,
      _10940: x0 => x0.coords,
      _10941: x0 => x0.timestamp,
      _10943: x0 => x0.accuracy,
      _10944: x0 => x0.latitude,
      _10945: x0 => x0.longitude,
      _10946: x0 => x0.altitude,
      _10947: x0 => x0.altitudeAccuracy,
      _10948: x0 => x0.heading,
      _10949: x0 => x0.speed,
      _10950: x0 => x0.code,
      _10951: x0 => x0.message,
      _11637: (x0,x1) => { x0.display = x1 },
      _12859: x0 => x0.name,
      _13575: () => globalThis.console,
      _13601: () => globalThis.console,
      _13640: (x0,x1) => x0.error(x1),
      _13653: x0 => x0.name,
      _13654: x0 => x0.message,
      _13655: x0 => x0.code,
      _13657: x0 => x0.customData,

    };

    const baseImports = {
      dart2wasm: dart2wasm,
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
    dartInstance.exports.$setThisModule(dartInstance);

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

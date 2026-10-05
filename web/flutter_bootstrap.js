{{flutter_js}}
{{flutter_build_config}}

try {
  const BUILD_VERSION = '05.10.2026-04.16';
  const urlParams = new URLSearchParams(window.location.search);
  const v = urlParams.get('t') || BUILD_VERSION;
  if (window._flutter && window._flutter.buildConfig && window._flutter.buildConfig.builds) {
    window._flutter.buildConfig.builds.forEach(function(build) {
      if (build.mainJsPath) {
        build.mainJsPath = build.mainJsPath + '?v=' + encodeURIComponent(v);
      }
    });
  }
} catch (e) {
  console.error("Error setting build version:", e);
}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    
    if (window.location.search) {
      try {
        window.history.replaceState(null, '', window.location.pathname);
      } catch (e) {}
    }

    // Uygulama motoru yüklendiğinde ve hazır olduğunda yükleme ekranını kaldırıyoruz.
    const loader = document.querySelector('.web-loader-container');
    if (loader) {
      loader.remove();
    }
    
    await appRunner.runApp();
  }
});

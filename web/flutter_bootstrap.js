{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    
    // Uygulama motoru yüklendiğinde ve hazır olduğunda yükleme ekranını kaldırıyoruz.
    const loader = document.querySelector('.web-loader-container');
    if (loader) {
      loader.remove();
    }
    
    await appRunner.runApp();
  }
});

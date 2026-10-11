{{flutter_js}}
{{flutter_build_config}}

const splash = document.getElementById('loading');
window.addEventListener('flutter-first-frame', () => splash?.remove(), {once: true});
_flutter.loader.load({
  config: {canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href},
  onEntrypointLoaded: async (engineInitializer) => {
    try {
      const runner = await engineInitializer.initializeEngine();
      await runner.runApp();
    } catch (error) {
      showLoadingError();
    }
  }
}).catch(showLoadingError);
function showLoadingError() {
  document.getElementById('loading-status').textContent = 'Не удалось загрузить приложение. Проверьте соединение и попробуйте снова.';
  document.getElementById('loading-retry').hidden = false;
}

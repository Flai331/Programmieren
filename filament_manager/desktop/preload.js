// Brücke zwischen Web-App und Windows-App (gleiche Namen wie AndroidBridge in der Android-App).
const { contextBridge, ipcRenderer } = require('electron');

ipcRenderer.on('fm-update', (_e, state) => {
  window.postMessage({ type: 'fm-update', state }, '*');
});

contextBridge.exposeInMainWorld('DesktopBridge', {
  appVersion: () => ipcRenderer.sendSync('fm-version'),
  updateCheck: () => ipcRenderer.send('fm-update-check'),
  updateDownload: () => ipcRenderer.send('fm-update-download'),
  updateCanInstall: () => true,
  updateInstall: () => { ipcRenderer.send('fm-update-install'); return 'installer'; },
});

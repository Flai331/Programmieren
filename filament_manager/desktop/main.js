// Windows-App: Fenster um die Web-App (web/), Daten bleiben im App-Profil (IndexedDB).
// Selbst-Update über electron-updater aus dem GitHub-Release "filament-manager" (latest.yml).
const { app, BrowserWindow, ipcMain, protocol, net, shell, Menu } = require('electron');
const path = require('path');
const { pathToFileURL } = require('url');

const SMOKE = process.argv.includes('--smoke-test');
const SCHEME = 'app';
const START = `${SCHEME}://filament/index.html`;

// Eigenes, sicheres Schema: IndexedDB, fetch und Kamera funktionieren wie auf einer https-Seite.
protocol.registerSchemesAsPrivileged([
  { scheme: SCHEME, privileges: { standard: true, secure: true, supportFetchAPI: true, corsEnabled: true, stream: true } },
]);

let win = null;
let updater = null;

function versionInfo() {
  const v = app.getVersion(); // 1.0.<Build-Nummer>
  const code = Number(v.split('.').pop()) || 0;
  // FM_UPDATE_URL: nur für Tests (lokaler Update-Server statt GitHub-Release)
  return { code, name: v, tag: 'filament-manager', enabled: !!process.env.FM_UPDATE_URL || (app.isPackaged && code > 0) };
}

function send(state) {
  if (win && !win.isDestroyed()) win.webContents.send('fm-update', state);
}

function getUpdater() {
  if (updater) return updater;
  const { autoUpdater } = require('electron-updater');
  autoUpdater.autoDownload = false;
  autoUpdater.autoInstallOnAppQuit = false;
  if (process.env.FM_UPDATE_URL) {
    autoUpdater.forceDevUpdateConfig = true;
    autoUpdater.setFeedURL({ provider: 'generic', url: process.env.FM_UPDATE_URL });
  }
  const codeOf = (v) => Number(String(v || '').split('.').pop()) || 0;
  autoUpdater.on('update-available', (i) => send({ state: 'available', code: codeOf(i.version), name: i.version }));
  autoUpdater.on('update-not-available', (i) => send({ state: 'none', code: codeOf(i && i.version), name: i && i.version }));
  autoUpdater.on('download-progress', (p) => send({ state: 'progress', pct: Math.round(p.percent || 0) }));
  autoUpdater.on('update-downloaded', (i) => send({ state: 'ready', code: codeOf(i.version), pct: 100 }));
  autoUpdater.on('error', (e) => send({ state: 'error', msg: String((e && e.message) || e).slice(0, 200) }));
  updater = autoUpdater;
  return updater;
}

ipcMain.on('fm-version', (e) => { e.returnValue = JSON.stringify(versionInfo()); });
ipcMain.on('fm-update-check', () => {
  if (!versionInfo().enabled) return send({ state: 'none' });
  getUpdater().checkForUpdates().catch(() => send({ state: 'none' }));
});
ipcMain.on('fm-update-download', () => {
  getUpdater().downloadUpdate().catch((e) => send({ state: 'error', msg: String(e && e.message || e).slice(0, 200) }));
});
ipcMain.on('fm-update-install', () => {
  setImmediate(() => getUpdater().quitAndInstall(true, true));
});

function createWindow() {
  win = new BrowserWindow({
    width: 1200,
    height: 850,
    minWidth: 380,
    minHeight: 500,
    title: 'Filament-Manager',
    icon: path.join(__dirname, 'build', 'icon.png'),
    show: !SMOKE,
    backgroundColor: '#f4f6f8',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  // Externe Links (MakerWorld, Printables, mailto: …) im Standard-Browser öffnen
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (!url.startsWith(`${SCHEME}://`)) shell.openExternal(url);
    return { action: 'deny' };
  });
  win.webContents.on('will-navigate', (e, url) => {
    if (!url.startsWith(`${SCHEME}://`)) { e.preventDefault(); shell.openExternal(url); }
  });

  win.webContents.on('console-message', (_e, level, message) => {
    if (SMOKE) {
      console.log(`[web] ${message}`);
      if (level >= 3) { console.error('JS-Fehler beim Start'); app.exit(1); }
      if (message.includes('Filament-Manager bereit')) app.exit(0);
    }
  });

  win.loadURL(START);
}

app.whenReady().then(() => {
  const root = path.join(__dirname, 'web');
  protocol.handle(SCHEME, (req) => {
    const { pathname } = new URL(req.url);
    const file = path.normalize(path.join(root, decodeURIComponent(pathname)));
    if (!file.startsWith(root)) return new Response('Nicht erlaubt', { status: 403 });
    return net.fetch(pathToFileURL(file).toString());
  });
  Menu.setApplicationMenu(null);
  createWindow();
  if (SMOKE) setTimeout(() => { console.error('Zeitüberschreitung beim Start'); app.exit(2); }, 45000);
});

app.on('window-all-closed', () => app.quit());

// Nur eine Instanz: zweiter Start holt das vorhandene Fenster nach vorn
if (!app.requestSingleInstanceLock()) app.quit();
else app.on('second-instance', () => { if (win) { if (win.isMinimized()) win.restore(); win.focus(); } });

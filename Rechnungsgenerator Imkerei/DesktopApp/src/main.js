/**
 * Electron Main Process
 * Rechnungsgenerator Imkerei Desktop App
 */

const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');
const path = require('path');
const fs = require('fs');

// Logger und Diagnostics
const Logger = require('./services/logger');
const StartupDiagnostics = require('./services/diagnostics');

// Keep a global reference of the window object
let mainWindow;
let logger;
let startupReport = null;

// Check if running in development mode
const isDev = process.argv.includes('--dev');

// Backend URL
const BACKEND_URL = 'http://localhost:8000';

// App-Version
const APP_VERSION = '1.0.0';

// Logger initialisieren
function initLogger() {
    const logDir = path.join(__dirname, '..', 'logs');
    logger = new Logger(logDir);
    logger.info('APP', 'Anwendung gestartet', { version: APP_VERSION, dev: isDev });

    // Alte Logs bereinigen
    logger.cleanOldLogs(7);
}

// Startup-Diagnose ausführen
async function runStartupDiagnostics() {
    logger.info('DIAGNOSE', 'Starte Startup-Diagnose...');

    const diagnostics = new StartupDiagnostics({
        backendUrl: BACKEND_URL,
        timeout: 5000,
        appVersion: APP_VERSION
    });

    try {
        startupReport = await diagnostics.runAllTests();

        // Report in Log schreiben
        logger.writeStartupReport(startupReport);

        // Ergebnis loggen
        if (startupReport.summary.status === 'OK') {
            logger.info('DIAGNOSE', 'Alle Tests bestanden', startupReport.summary);
        } else {
            logger.warn('DIAGNOSE', 'Einige Tests fehlgeschlagen', startupReport.summary.failures);
        }

        return startupReport;
    } catch (err) {
        logger.error('DIAGNOSE', 'Diagnose fehlgeschlagen', err.message);
        return null;
    }
}

function createWindow() {
    // Create the browser window
    mainWindow = new BrowserWindow({
        width: 1400,
        height: 900,
        minWidth: 800,
        minHeight: 600,
        webPreferences: {
            nodeIntegration: false,
            contextIsolation: true,
            preload: path.join(__dirname, 'preload.js')
        },
        icon: path.join(__dirname, '../assets/icon.png'),
        title: 'Rechnungsgenerator Imkerei',
        show: false // Erst nach Diagnose anzeigen
    });

    // Load the app
    mainWindow.loadFile(path.join(__dirname, 'renderer/index.html'));

    // Fenster anzeigen wenn geladen
    mainWindow.once('ready-to-show', () => {
        mainWindow.show();

        // Startup-Report an Renderer senden
        if (startupReport) {
            mainWindow.webContents.send('startup:report', startupReport);
        }
    });

    // Open DevTools in development mode
    if (isDev) {
        mainWindow.webContents.openDevTools();
    }

    // Handle window close
    mainWindow.on('closed', () => {
        mainWindow = null;
    });

    // Handle external links
    mainWindow.webContents.setWindowOpenHandler(({ url }) => {
        shell.openExternal(url);
        return { action: 'deny' };
    });
}

// Unbehandelte Fehler abfangen
process.on('uncaughtException', (error) => {
    if (logger) {
        logger.error('FATAL', 'Unbehandelter Fehler', {
            message: error.message,
            stack: error.stack
        });
    } else {
        console.error('FATAL ERROR:', error);
    }
});

process.on('unhandledRejection', (reason, promise) => {
    if (logger) {
        logger.error('FATAL', 'Unbehandelte Promise-Ablehnung', {
            reason: String(reason)
        });
    }
});

// App ready
app.whenReady().then(async () => {
    // Logger initialisieren
    initLogger();

    // Diagnose ausführen
    await runStartupDiagnostics();

    // Fenster erstellen
    createWindow();

    app.on('activate', () => {
        if (BrowserWindow.getAllWindows().length === 0) {
            createWindow();
        }
    });
});

// Quit when all windows are closed (except on macOS)
app.on('window-all-closed', () => {
    if (logger) {
        logger.info('APP', 'Anwendung beendet');
    }
    if (process.platform !== 'darwin') {
        app.quit();
    }
});

// ============================================
// IPC Handlers
// ============================================

// Startup-Report abrufen
ipcMain.handle('diagnostics:getReport', () => {
    return startupReport;
});

// Diagnose erneut ausführen
ipcMain.handle('diagnostics:runAgain', async () => {
    return await runStartupDiagnostics();
});

// Log-Eintrag schreiben
ipcMain.handle('log:write', (event, level, category, message, details) => {
    if (!logger) return { success: false };

    switch (level) {
        case 'error':
            logger.error(category, message, details);
            break;
        case 'warn':
            logger.warn(category, message, details);
            break;
        case 'debug':
            logger.debug(category, message, details);
            break;
        default:
            logger.info(category, message, details);
    }

    return { success: true };
});

// Letzte Log-Einträge abrufen
ipcMain.handle('log:getRecent', (event, lines = 50) => {
    if (!logger) return [];
    return logger.getRecentLogs(lines);
});

// Log-Datei-Pfad abrufen
ipcMain.handle('log:getPath', () => {
    if (!logger) return null;
    return logger.getLogFileName();
});

// Open file dialog
ipcMain.handle('dialog:openFile', async (event, options) => {
    const result = await dialog.showOpenDialog(mainWindow, {
        properties: ['openFile'],
        filters: options?.filters || [
            { name: 'Images', extensions: ['jpg', 'jpeg', 'png', 'gif'] },
            { name: 'All Files', extensions: ['*'] }
        ]
    });
    return result;
});

// Save file dialog
ipcMain.handle('dialog:saveFile', async (event, options) => {
    const result = await dialog.showSaveDialog(mainWindow, {
        defaultPath: options?.defaultPath || 'rechnung.pdf',
        filters: options?.filters || [
            { name: 'PDF', extensions: ['pdf'] },
            { name: 'All Files', extensions: ['*'] }
        ]
    });
    return result;
});

// Read file
ipcMain.handle('fs:readFile', async (event, filePath) => {
    try {
        // Pfad validieren
        if (!filePath || typeof filePath !== 'string') {
            throw new Error('Ungueltiger Dateipfad');
        }

        const data = fs.readFileSync(filePath);
        logger?.info('FS', 'Datei gelesen', { path: filePath, size: data.length });
        return { success: true, data: data.toString('base64') };
    } catch (error) {
        logger?.error('FS', 'Fehler beim Lesen', { path: filePath, error: error.message });
        return { success: false, error: error.message };
    }
});

// Write file
ipcMain.handle('fs:writeFile', async (event, filePath, data) => {
    try {
        // Pfad validieren
        if (!filePath || typeof filePath !== 'string') {
            throw new Error('Ungueltiger Dateipfad');
        }

        const buffer = Buffer.from(data, 'base64');
        fs.writeFileSync(filePath, buffer);
        logger?.info('FS', 'Datei geschrieben', { path: filePath, size: buffer.length });
        return { success: true };
    } catch (error) {
        logger?.error('FS', 'Fehler beim Schreiben', { path: filePath, error: error.message });
        return { success: false, error: error.message };
    }
});

// Open file in default application
ipcMain.handle('shell:openPath', async (event, filePath) => {
    try {
        await shell.openPath(filePath);
        logger?.info('SHELL', 'Datei geoeffnet', { path: filePath });
        return { success: true };
    } catch (error) {
        logger?.error('SHELL', 'Fehler beim Oeffnen', { path: filePath, error: error.message });
        return { success: false, error: error.message };
    }
});

// Open URL in default browser
ipcMain.handle('shell:openExternal', async (event, url) => {
    try {
        await shell.openExternal(url);
        return { success: true };
    } catch (error) {
        logger?.error('SHELL', 'Fehler beim Oeffnen der URL', { url, error: error.message });
        return { success: false, error: error.message };
    }
});

// Log-Ordner öffnen
ipcMain.handle('shell:openLogFolder', async () => {
    try {
        const logDir = path.join(__dirname, '..', 'logs');
        await shell.openPath(logDir);
        return { success: true };
    } catch (error) {
        return { success: false, error: error.message };
    }
});

// Send email with attachment (using default mail client)
ipcMain.handle('email:sendWithAttachment', async (event, options) => {
    try {
        const { to, subject, body, attachmentPath } = options;

        // Create mailto URL
        let mailtoUrl = `mailto:${to}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;

        // Note: mailto doesn't support attachments directly
        // We'll open the mail client and show a message about the attachment
        await shell.openExternal(mailtoUrl);

        // Also open the PDF in the file explorer so user can drag it
        if (attachmentPath && fs.existsSync(attachmentPath)) {
            shell.showItemInFolder(attachmentPath);
        }

        logger?.info('EMAIL', 'E-Mail-Client geoeffnet', { to, subject });

        return {
            success: true,
            message: 'E-Mail-Programm geoeffnet. Bitte fuegen Sie die PDF-Datei manuell als Anhang hinzu.'
        };
    } catch (error) {
        logger?.error('EMAIL', 'Fehler beim Oeffnen des E-Mail-Clients', error.message);
        return { success: false, error: error.message };
    }
});

// Get app info
ipcMain.handle('app:getInfo', () => {
    return {
        name: app.getName(),
        version: APP_VERSION,
        platform: process.platform,
        arch: process.arch,
        electronVersion: process.versions.electron,
        nodeVersion: process.versions.node
    };
});

// Get backend URL
ipcMain.handle('app:getBackendUrl', () => {
    return BACKEND_URL;
});

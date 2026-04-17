/**
 * Electron Preload Script
 * Exposes secure APIs to the renderer process
 */

const { contextBridge, ipcRenderer } = require('electron');

// Expose protected methods to renderer
contextBridge.exposeInMainWorld('electronAPI', {
    // Dialog methods
    openFileDialog: (options) => ipcRenderer.invoke('dialog:openFile', options),
    saveFileDialog: (options) => ipcRenderer.invoke('dialog:saveFile', options),

    // File system methods
    readFile: (filePath) => ipcRenderer.invoke('fs:readFile', filePath),
    writeFile: (filePath, data) => ipcRenderer.invoke('fs:writeFile', filePath, data),

    // Shell methods
    openPath: (filePath) => ipcRenderer.invoke('shell:openPath', filePath),
    openExternal: (url) => ipcRenderer.invoke('shell:openExternal', url),
    openLogFolder: () => ipcRenderer.invoke('shell:openLogFolder'),

    // Email methods
    sendEmailWithAttachment: (options) => ipcRenderer.invoke('email:sendWithAttachment', options),

    // App info
    getAppInfo: () => ipcRenderer.invoke('app:getInfo'),
    getBackendUrl: () => ipcRenderer.invoke('app:getBackendUrl'),

    // Diagnostics API
    diagnostics: {
        getReport: () => ipcRenderer.invoke('diagnostics:getReport'),
        runAgain: () => ipcRenderer.invoke('diagnostics:runAgain'),
        onReport: (callback) => {
            ipcRenderer.on('startup:report', (event, report) => callback(report));
        }
    },

    // Logger API
    logger: {
        info: (category, message, details) =>
            ipcRenderer.invoke('log:write', 'info', category, message, details),
        warn: (category, message, details) =>
            ipcRenderer.invoke('log:write', 'warn', category, message, details),
        error: (category, message, details) =>
            ipcRenderer.invoke('log:write', 'error', category, message, details),
        debug: (category, message, details) =>
            ipcRenderer.invoke('log:write', 'debug', category, message, details),
        getRecent: (lines) => ipcRenderer.invoke('log:getRecent', lines),
        getPath: () => ipcRenderer.invoke('log:getPath')
    }
});

// Log when preload is loaded
console.log('Preload script loaded - Diagnostics & Logger APIs available');

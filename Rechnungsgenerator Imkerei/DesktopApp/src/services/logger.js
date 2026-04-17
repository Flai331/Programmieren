/**
 * Logger Service für Rechnungsgenerator Imkerei
 * Strukturierte Protokollierung mit Datei- und Konsolen-Ausgabe
 */

const fs = require('fs');
const path = require('path');

class Logger {
    constructor(logDir) {
        this.logDir = logDir;
        this.currentLogFile = null;
        this.ensureLogDir();
    }

    ensureLogDir() {
        if (!fs.existsSync(this.logDir)) {
            fs.mkdirSync(this.logDir, { recursive: true });
        }
    }

    getLogFileName() {
        const date = new Date();
        const dateStr = date.toISOString().split('T')[0]; // YYYY-MM-DD
        return path.join(this.logDir, `app_${dateStr}.log`);
    }

    getTimestamp() {
        const now = new Date();
        return now.toLocaleString('de-DE', {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        });
    }

    formatMessage(level, category, message, details = null) {
        const timestamp = this.getTimestamp();
        const levelPadded = level.toUpperCase().padEnd(5);
        let logLine = `[${timestamp}] [${levelPadded}] [${category}] ${message}`;

        if (details) {
            if (typeof details === 'object') {
                logLine += `\n    Details: ${JSON.stringify(details, null, 2).replace(/\n/g, '\n    ')}`;
            } else {
                logLine += `\n    Details: ${details}`;
            }
        }

        return logLine;
    }

    write(level, category, message, details = null) {
        const logLine = this.formatMessage(level, category, message, details);

        // Konsole
        switch (level.toLowerCase()) {
            case 'error':
                console.error(logLine);
                break;
            case 'warn':
                console.warn(logLine);
                break;
            case 'debug':
                console.debug(logLine);
                break;
            default:
                console.log(logLine);
        }

        // Datei
        try {
            const logFile = this.getLogFileName();
            fs.appendFileSync(logFile, logLine + '\n');
        } catch (err) {
            console.error('Fehler beim Schreiben der Log-Datei:', err.message);
        }
    }

    info(category, message, details = null) {
        this.write('INFO', category, message, details);
    }

    warn(category, message, details = null) {
        this.write('WARN', category, message, details);
    }

    error(category, message, details = null) {
        this.write('ERROR', category, message, details);
    }

    debug(category, message, details = null) {
        this.write('DEBUG', category, message, details);
    }

    // Startup-Diagnose-Report schreiben
    writeStartupReport(report) {
        const separator = '='.repeat(50);
        const timestamp = this.getTimestamp();

        let content = `\n${separator}\n`;
        content += `RECHNUNGSGENERATOR IMKEREI - Startup-Diagnose\n`;
        content += `${separator}\n`;
        content += `Datum/Zeit: ${timestamp}\n`;
        content += `App-Version: ${report.appVersion || '1.0.0'}\n`;
        content += `Electron: ${report.electronVersion || 'unbekannt'}\n`;
        content += `Node: ${report.nodeVersion || 'unbekannt'}\n`;
        content += `OS: ${report.platform || 'unbekannt'}\n\n`;

        // Tests durchgehen
        for (const section of report.sections) {
            content += `--- ${section.name.toUpperCase()} ---\n`;
            for (const test of section.tests) {
                const icon = test.passed ? '[OK]' : '[FEHLER]';
                content += `${icon} ${test.name}\n`;
                if (!test.passed && test.error) {
                    content += `    -> ${test.error}\n`;
                }
            }
            content += '\n';
        }

        // Zusammenfassung
        const totalTests = report.sections.reduce((sum, s) => sum + s.tests.length, 0);
        const failedTests = report.sections.reduce((sum, s) =>
            sum + s.tests.filter(t => !t.passed).length, 0);

        content += `--- ZUSAMMENFASSUNG ---\n`;
        content += `Gesamt: ${totalTests} Tests\n`;
        content += `Erfolgreich: ${totalTests - failedTests}\n`;
        content += `Fehlgeschlagen: ${failedTests}\n`;
        content += `Status: ${failedTests === 0 ? 'BEREIT' : 'FEHLER GEFUNDEN'}\n`;

        if (failedTests > 0) {
            content += `\nHinweis: Stellen Sie sicher, dass das Backend laeuft!\n`;
            content += `Backend starten: Backend/start_backend.bat\n`;
        }

        content += `${separator}\n\n`;

        // In Datei schreiben
        try {
            const logFile = this.getLogFileName();
            fs.appendFileSync(logFile, content);
            return { success: true, file: logFile };
        } catch (err) {
            return { success: false, error: err.message };
        }
    }

    // Alte Logs bereinigen (älter als 7 Tage)
    cleanOldLogs(maxAgeDays = 7) {
        try {
            const files = fs.readdirSync(this.logDir);
            const now = Date.now();
            const maxAge = maxAgeDays * 24 * 60 * 60 * 1000;
            let deleted = 0;

            for (const file of files) {
                if (file.startsWith('app_') && file.endsWith('.log')) {
                    const filePath = path.join(this.logDir, file);
                    const stats = fs.statSync(filePath);

                    if (now - stats.mtimeMs > maxAge) {
                        fs.unlinkSync(filePath);
                        deleted++;
                    }
                }
            }

            if (deleted > 0) {
                this.info('SYSTEM', `${deleted} alte Log-Datei(en) geloescht`);
            }

            return deleted;
        } catch (err) {
            this.error('SYSTEM', 'Fehler beim Bereinigen alter Logs', err.message);
            return 0;
        }
    }

    // Letzten Log-Eintrag lesen
    getRecentLogs(lines = 50) {
        try {
            const logFile = this.getLogFileName();
            if (!fs.existsSync(logFile)) {
                return [];
            }

            const content = fs.readFileSync(logFile, 'utf8');
            const allLines = content.split('\n').filter(l => l.trim());
            return allLines.slice(-lines);
        } catch (err) {
            return [`Fehler beim Lesen: ${err.message}`];
        }
    }
}

module.exports = Logger;

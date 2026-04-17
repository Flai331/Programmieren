/**
 * Startup-Diagnose Service für Rechnungsgenerator Imkerei
 * Prüft alle Voraussetzungen beim App-Start
 */

const os = require('os');
const fs = require('fs');
const path = require('path');
const { net } = require('electron');

class StartupDiagnostics {
    constructor(config = {}) {
        this.config = {
            backendUrl: config.backendUrl || 'http://localhost:8000',
            timeout: config.timeout || 5000,
            appVersion: config.appVersion || '1.0.0',
            ...config
        };

        this.report = {
            timestamp: new Date().toISOString(),
            appVersion: this.config.appVersion,
            electronVersion: process.versions.electron,
            nodeVersion: process.versions.node,
            chromeVersion: process.versions.chrome,
            platform: `${os.type()} ${os.release()}`,
            arch: os.arch(),
            sections: []
        };
    }

    // HTTP-Request mit Timeout
    async httpRequest(url, timeout = 5000) {
        return new Promise((resolve, reject) => {
            const timeoutId = setTimeout(() => {
                reject(new Error('Timeout nach ' + (timeout / 1000) + ' Sekunden'));
            }, timeout);

            const request = net.request(url);

            request.on('response', (response) => {
                clearTimeout(timeoutId);
                let data = '';

                response.on('data', (chunk) => {
                    data += chunk.toString();
                });

                response.on('end', () => {
                    resolve({
                        statusCode: response.statusCode,
                        data: data,
                        headers: response.headers
                    });
                });
            });

            request.on('error', (err) => {
                clearTimeout(timeoutId);
                reject(err);
            });

            request.end();
        });
    }

    // Einzelnen Test ausführen
    async runTest(name, testFn) {
        const startTime = Date.now();
        try {
            const result = await testFn();
            return {
                name,
                passed: true,
                duration: Date.now() - startTime,
                result: result || null
            };
        } catch (err) {
            return {
                name,
                passed: false,
                duration: Date.now() - startTime,
                error: err.message || String(err)
            };
        }
    }

    // === SYSTEM-TESTS ===
    async testSystem() {
        const tests = [];

        // Electron-Version
        tests.push(await this.runTest('Electron geladen', async () => {
            if (!process.versions.electron) {
                throw new Error('Electron nicht verfuegbar');
            }
            return `v${process.versions.electron}`;
        }));

        // Node-Version
        tests.push(await this.runTest('Node.js verfuegbar', async () => {
            if (!process.versions.node) {
                throw new Error('Node.js nicht verfuegbar');
            }
            return `v${process.versions.node}`;
        }));

        // Arbeitsspeicher
        tests.push(await this.runTest('Arbeitsspeicher ausreichend', async () => {
            const freeMem = os.freemem();
            const minMem = 100 * 1024 * 1024; // 100 MB
            if (freeMem < minMem) {
                throw new Error(`Nur ${Math.round(freeMem / 1024 / 1024)} MB frei`);
            }
            return `${Math.round(freeMem / 1024 / 1024)} MB frei`;
        }));

        return {
            name: 'System',
            tests
        };
    }

    // === NETZWERK-TESTS ===
    async testNetwork() {
        const tests = [];

        // Backend erreichbar
        tests.push(await this.runTest('Backend erreichbar', async () => {
            const response = await this.httpRequest(
                this.config.backendUrl,
                this.config.timeout
            );
            if (response.statusCode >= 500) {
                throw new Error(`Server-Fehler (${response.statusCode})`);
            }
            return `Status ${response.statusCode}`;
        }));

        // Health-Check
        tests.push(await this.runTest('Health-Check', async () => {
            const response = await this.httpRequest(
                `${this.config.backendUrl}/health`,
                this.config.timeout
            );
            if (response.statusCode !== 200) {
                throw new Error(`Health-Check fehlgeschlagen (${response.statusCode})`);
            }
            return 'OK';
        }));

        // API-Dokumentation
        tests.push(await this.runTest('API-Dokumentation', async () => {
            const response = await this.httpRequest(
                `${this.config.backendUrl}/docs`,
                this.config.timeout
            );
            if (response.statusCode !== 200) {
                throw new Error(`Docs nicht erreichbar (${response.statusCode})`);
            }
            return 'Verfuegbar';
        }));

        return {
            name: 'Netzwerk',
            tests
        };
    }

    // === DATEISYSTEM-TESTS ===
    async testFileSystem() {
        const tests = [];
        const appPath = path.dirname(require.main?.filename || __dirname);

        // Log-Ordner
        tests.push(await this.runTest('Log-Ordner schreibbar', async () => {
            const logDir = path.join(appPath, '..', 'logs');

            if (!fs.existsSync(logDir)) {
                fs.mkdirSync(logDir, { recursive: true });
            }

            // Test-Datei schreiben
            const testFile = path.join(logDir, '.write_test');
            fs.writeFileSync(testFile, 'test');
            fs.unlinkSync(testFile);

            return logDir;
        }));

        // Temp-Ordner
        tests.push(await this.runTest('Temp-Ordner verfuegbar', async () => {
            const tmpDir = os.tmpdir();
            if (!fs.existsSync(tmpDir)) {
                throw new Error('Temp-Ordner nicht gefunden');
            }
            return tmpDir;
        }));

        return {
            name: 'Dateisystem',
            tests
        };
    }

    // === DATENBANK-TEST (über Backend) ===
    async testDatabase() {
        const tests = [];

        tests.push(await this.runTest('Datenbank-Verbindung', async () => {
            // Prüft, ob das Backend die DB erreichen kann
            const response = await this.httpRequest(
                `${this.config.backendUrl}/api/customers?limit=1`,
                this.config.timeout
            );

            // 401 = Auth nötig, aber Backend + DB funktionieren
            // 200 = Alles OK
            // 500+ = DB-Problem
            if (response.statusCode >= 500) {
                throw new Error('Datenbank-Fehler im Backend');
            }

            return 'Verbunden';
        }));

        return {
            name: 'Datenbank',
            tests
        };
    }

    // Alle Tests ausführen
    async runAllTests() {
        console.log('=== Starte Diagnose ===');

        // System-Tests
        try {
            this.report.sections.push(await this.testSystem());
        } catch (err) {
            this.report.sections.push({
                name: 'System',
                tests: [{ name: 'System-Tests', passed: false, error: err.message }]
            });
        }

        // Netzwerk-Tests
        try {
            this.report.sections.push(await this.testNetwork());
        } catch (err) {
            this.report.sections.push({
                name: 'Netzwerk',
                tests: [{ name: 'Netzwerk-Tests', passed: false, error: err.message }]
            });
        }

        // Dateisystem-Tests
        try {
            this.report.sections.push(await this.testFileSystem());
        } catch (err) {
            this.report.sections.push({
                name: 'Dateisystem',
                tests: [{ name: 'Dateisystem-Tests', passed: false, error: err.message }]
            });
        }

        // Datenbank-Tests
        try {
            this.report.sections.push(await this.testDatabase());
        } catch (err) {
            this.report.sections.push({
                name: 'Datenbank',
                tests: [{ name: 'Datenbank-Tests', passed: false, error: err.message }]
            });
        }

        // Zusammenfassung berechnen
        let totalTests = 0;
        let passedTests = 0;
        let failedTests = [];

        for (const section of this.report.sections) {
            for (const test of section.tests) {
                totalTests++;
                if (test.passed) {
                    passedTests++;
                } else {
                    failedTests.push({
                        section: section.name,
                        test: test.name,
                        error: test.error
                    });
                }
            }
        }

        this.report.summary = {
            totalTests,
            passedTests,
            failedTests: failedTests.length,
            failures: failedTests,
            status: failedTests.length === 0 ? 'OK' : 'FEHLER',
            ready: failedTests.filter(f =>
                f.section === 'Netzwerk' || f.section === 'Datenbank'
            ).length === 0
        };

        console.log(`=== Diagnose abgeschlossen: ${passedTests}/${totalTests} Tests bestanden ===`);

        return this.report;
    }

    // Report für Anzeige formatieren
    getFormattedReport() {
        const lines = [];
        const sep = '─'.repeat(45);

        lines.push(sep);
        lines.push('STARTUP-DIAGNOSE');
        lines.push(sep);
        lines.push(`Zeit: ${new Date().toLocaleString('de-DE')}`);
        lines.push(`Version: ${this.report.appVersion}`);
        lines.push(`System: ${this.report.platform}`);
        lines.push('');

        for (const section of this.report.sections) {
            lines.push(`▸ ${section.name.toUpperCase()}`);
            for (const test of section.tests) {
                const icon = test.passed ? '  ✓' : '  ✗';
                lines.push(`${icon} ${test.name}`);
                if (!test.passed && test.error) {
                    lines.push(`      → ${test.error}`);
                }
            }
            lines.push('');
        }

        if (this.report.summary) {
            lines.push(sep);
            const status = this.report.summary.status === 'OK' ? '✓ BEREIT' : '✗ FEHLER';
            lines.push(`Status: ${status}`);
            lines.push(`Tests: ${this.report.summary.passedTests}/${this.report.summary.totalTests} bestanden`);

            if (this.report.summary.failedTests > 0) {
                lines.push('');
                lines.push('Tipp: Starten Sie zuerst das Backend!');
                lines.push('→ Backend/start_backend.bat');
            }
        }

        lines.push(sep);

        return lines.join('\n');
    }
}

module.exports = StartupDiagnostics;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../build_info.dart';
import '../services/services.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import '../utils/feedback_service.dart';
import 'catalog_screen.dart';
import 'company_screen.dart';
import 'honey_stock_screen.dart';
import 'report_list_screen.dart';
import 'import_screen.dart';
import 'stock_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color _peach = Color(0xFFfda085);
  static const Color _gold = Color(0xFFf6d365);

  CompanyModel? _company;
  late TextEditingController _patternCtrl;
  bool _patternSaving = false;
  String _patternPreview = '';

  // ── Aktualisierung ──
  final UpdateService _updates = UpdateService();

  /// Prüfen oder Laden läuft. Sperrt den Knopf, damit nicht zwei Läufe
  /// gleichzeitig unterwegs sind.
  bool _updateBusy = false;

  /// Die gefundene neuere Fassung, falls es eine gibt.
  UpdateInfo? _updateFound;

  /// Klartext für die Anzeige — auch und gerade, wenn es nicht geklappt hat.
  String? _updateMessage;

  /// Anteil des Ladens zwischen 0 und 1, null wenn nicht geladen wird.
  double? _updateProgress;

  /// Das schon geladene Paket. Wichtig für den häufigsten Stolperstein:
  /// Fehlt die Installationserlaubnis, schickt Android in die
  /// Einstellungen — und danach soll das Tippen installieren, nicht
  /// vierzig Megabyte erneut holen.
  String? _updateFile;

  @override
  void initState() {
    super.initState();
    _patternCtrl = TextEditingController();
    _patternCtrl.addListener(_updatePreview);
    FeedbackService.logScreenLoad('Settings');
    _loadCompany();
  }

  @override
  void dispose() {
    _patternCtrl.removeListener(_updatePreview);
    _patternCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCompany() async {
    final companies = await DatabaseService().getAllCompanies();
    if (!mounted) return;
    if (companies.isNotEmpty) {
      setState(() {
        _company = companies.first;
        _patternCtrl.text = _company!.invoiceNumberPattern;
        _updatePreview();
      });
    }
  }

  void _updatePreview() {
    if (!mounted) return;
    setState(() {
      _patternPreview = InvoiceNumberGenerator.preview(
        _patternCtrl.text.trim().isEmpty
            ? InvoiceNumberGenerator.defaultPattern
            : _patternCtrl.text.trim(),
        customerName: 'Mustermann',
      );
    });
  }

  Future<void> _savePattern() async {
    if (_company == null) return;
    final pattern = _patternCtrl.text.trim();
    if (pattern.isEmpty) return;
    setState(() => _patternSaving = true);
    try {
      final updated = _company!.copyWith(invoiceNumberPattern: pattern);
      await DatabaseService().updateCompany(updated);
      setState(() => _company = updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Rechnungsnummer-Format gespeichert'),
          backgroundColor: Color(0xFF4ade80),
        ),
      );
      FeedbackService.logUserAction('Rechnungsnummer-Pattern gespeichert',
          context: {'pattern': pattern});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler: $e'),
          backgroundColor: Color(0xFFff6b7a),
        ),
      );
    } finally {
      if (mounted) setState(() => _patternSaving = false);
    }
  }

  void _insertVariable(String variable) {
    final ctrl = _patternCtrl;
    final sel = ctrl.selection;
    final text = ctrl.text;
    final newText = sel.isValid
        ? text.replaceRange(sel.start, sel.end, variable)
        : text + variable;
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: sel.isValid ? sel.start + variable.length : newText.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Verbindungsstatus ─────────────────────────────────
            const Text(
              'Verbindungsstatus',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Consumer<ConnectivityService>(
              builder: (context, connectivity, _) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: connectivity.isOnline
                                    ? const Color(0xFF4ade80)
                                    : const Color(0xFFff6b7a),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              connectivity.isOnline ? 'Online' : 'Offline',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          connectivity.isOnline
                              ? 'Die App ist mit dem Internet verbunden'
                              : 'Die App funktioniert offline. Änderungen werden später synchronisiert.',
                          style: const TextStyle(color: Color(0xFF8a8a94)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // ── Synchronisierung ──────────────────────────────────
            const Text(
              'Synchronisierung',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Consumer2<ConnectivityService, SyncService>(
              builder: (context, connectivity, sync, _) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${sync.pendingSyncCount} Einträge warten auf Synchronisierung',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        if (sync.lastSyncTime != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Color(0xFF4ade80), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Zuletzt synchronisiert: ${AppUtils.formatDateTime(sync.lastSyncTime!)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8a8a94),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (sync.lastSyncError != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.error,
                                  color: Color(0xFFff6b7a), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Fehler: ${sync.lastSyncError}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFff6b7a),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: sync.isSyncing
                                ? null
                                : () async {
                                    await sync.syncInvoicesManual();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Synchronisierung abgeschlossen'),
                                      ),
                                    );
                                  },
                            icon: sync.isSyncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.cloud_upload),
                            label: const Text('Jetzt synchronisieren'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // ── Rechnungsnummern ──────────────────────────────────
            const Text(
              'Rechnungsnummern',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInvoiceNumberCard(),
            const SizedBox(height: 32),

            // ── Unternehmenseinstellungen ─────────────────────────
            const Text(
              'Unternehmenseinstellungen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const CompanyScreen()),
                  );
                },
                icon: const Icon(Icons.business),
                label: const Text('Firmendaten'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ImportScreen()),
                  );
                },
                icon: const Icon(Icons.download_outlined),
                label: const Text('Daten aus dem Rechnungsgenerator '
                    'übernehmen'),
              ),
            ),
            const SizedBox(height: 32),

            // ── Lager ─────────────────────────────────────────────
            // Die Navigationsleiste trägt schon neun Ziele; ein zehntes
            // wäre nicht mehr lesbar. Das Lager ist deshalb von hier und
            // über die Dashboard-Kachel erreichbar.
            const Text(
              'Lager',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Honig in Eimern mit Zustand und Lagerplatz, dazu Gläser, '
              'Futter, Mittelwände und Behandlungsmittel mit '
              'Mindestbestand.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8a8a94)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const HoneyStockScreen()),
                  );
                },
                icon: const Icon(Icons.hive_outlined),
                label: const Text('Honiglager'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StockScreen()),
                  );
                },
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Gläser und Material'),
              ),
            ),
            const SizedBox(height: 32),

            // ── Verzeichnisse ─────────────────────────────────────
            const Text(
              'Verzeichnisse',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Was die App zur Auswahl stellt: Zustände am Eimer, '
              'Honigsorten, Lager-Kategorien, Buchungsgründe und Maßnahmen '
              'am Volk. Beschriftungen, Reihenfolge und Farben sind deine; '
              'eigene Einträge kannst du dazunehmen.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8a8a94)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const CatalogScreen()),
                  );
                },
                icon: const Icon(Icons.list_alt_outlined),
                label: const Text('Auswahllisten anpassen'),
              ),
            ),
            const SizedBox(height: 32),

            // ── Fehlerberichte ────────────────────────────────────
            const Text(
              'Fehlerberichte',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Gemeldete Fehler werden auf dem Gerät abgelegt und gehen per '
              'Mail an ${FeedbackService.supportEmail}. Von hier aus lassen '
              'sie sich jederzeit erneut senden, teilen oder kopieren.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8a8a94)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ReportListScreen()),
                  );
                },
                icon: const Icon(Icons.bug_report_outlined),
                label: const Text('Abgelegte Berichte'),
              ),
            ),
            const SizedBox(height: 32),

            // ── App-Information ───────────────────────────────────
            const Text(
              'App-Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Anwendung', AppConstants.appName),
                    const SizedBox(height: 8),
                    _buildInfoRow('Version', AppConstants.appVersion),
                    const SizedBox(height: 8),
                    _buildInfoRow('Build', '#$kBuildNumber'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Datenbankversion',
                        AppConstants.dbVersion.toString()),
                    const SizedBox(height: 8),
                    _buildInfoRow('API-Version', AppConstants.apiVersion),
                    const SizedBox(height: 8),
                    _buildInfoRow('Status', '✓ Einsatzbereit'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Aktualisierung ────────────────────────────────────
            const Text(
              'Aktualisierung',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'BeeBrain sieht auf Knopfdruck nach, ob eine neuere Fassung '
              'veröffentlicht ist, lädt sie und übergibt sie Android zur '
              'Installation. Von selbst passiert das nie — am Bienenstand '
              'wäre ein überraschender Download eine Zumutung.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8a8a94)),
            ),
            const SizedBox(height: 12),
            _buildUpdateCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Aktualisierungs-Karte ──────────────────────────────────────
  Widget _buildUpdateCard() {
    final gefunden = _updateFound;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (gefunden != null) ...[
              Row(
                children: [
                  const Icon(Icons.system_update_outlined,
                      color: Color(0xFF22c55e)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Build #${gefunden.buildNumber} steht bereit'
                      ' · ${gefunden.readableSize}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (gefunden.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  gefunden.notes,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF8a8a94)),
                ),
              ],
              const SizedBox(height: 12),
            ],

            if (_updateMessage != null) ...[
              Text(
                _updateMessage!,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
            ],

            if (_updateProgress != null) ...[
              LinearProgressIndicator(value: _updateProgress),
              const SizedBox(height: 6),
              Text(
                '${((_updateProgress ?? 0) * 100).round()} % von '
                '${gefunden?.readableSize ?? ''}',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF8a8a94)),
              ),
              const SizedBox(height: 12),
            ],

            SizedBox(
              width: double.infinity,
              child: gefunden == null
                  ? ElevatedButton.icon(
                      onPressed: _updateBusy ? null : _checkForUpdate,
                      icon: _updateBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(_updateBusy
                          ? 'Wird nachgesehen …'
                          : 'Nach neuer Fassung sehen'),
                    )
                  : ElevatedButton.icon(
                      onPressed: _updateBusy ? null : _downloadAndInstall,
                      icon: Icon(_updateFile == null
                          ? Icons.download_outlined
                          : Icons.install_mobile_outlined),
                      label: Text(
                        _updateBusy
                            ? 'Wird geladen …'
                            : _updateFile == null
                                ? 'Herunterladen und installieren'
                                : 'Installieren',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _updateBusy = true;
      _updateMessage = null;
      _updateFound = null;
      _updateFile = null;
    });

    try {
      // Erst das Gerät fragen: Ohne Verbindung einen ehrlichen Satz, statt
      // zwanzig Sekunden auf einen Zeitablauf zu warten.
      if (!await ConnectivityService().checkConnection()) {
        if (!mounted) return;
        setState(() => _updateMessage =
            'Keine Internetverbindung. Zum Nachsehen braucht BeeBrain '
            'einmal Netz — im Keller also später.');
        return;
      }

      final ergebnis = await _updates.check();
      if (!mounted) return;
      setState(() {
        if (ergebnis.status == UpdateStatus.available) {
          _updateFound = ergebnis.info;
        } else if (ergebnis.status == UpdateStatus.upToDate) {
          _updateMessage = 'BeeBrain ist aktuell (Build #$kBuildNumber).';
        } else {
          _updateMessage =
              ergebnis.detail ?? 'Die Prüfung hat nicht geklappt.';
        }
      });
    } finally {
      if (mounted) setState(() => _updateBusy = false);
    }
  }

  Future<void> _downloadAndInstall() async {
    final fassung = _updateFound;
    if (fassung == null) return;

    // Liegt das Paket vom vorigen Versuch noch da, nicht erneut laden.
    final schonDa = _updateFile;
    if (schonDa != null && await File(schonDa).exists()) {
      if (!mounted) return;
      setState(() {
        _updateBusy = true;
        _updateMessage = null;
      });
      await _installFile(schonDa);
      return;
    }

    setState(() {
      _updateBusy = true;
      _updateMessage = null;
      _updateProgress = 0;
    });

    final pfad = await _updates.download(
      fassung,
      onProgress: (anteil, geladen, gesamt) {
        if (!mounted) return;
        // Nur bei jedem ganzen Prozent neu zeichnen. Sonst baut sich die
        // Oberfläche bei vierzig Megabyte hunderte Male neu auf.
        final bisher = _updateProgress ?? 0;
        if (anteil < 1 && (anteil - bisher).abs() < 0.01) return;
        setState(() => _updateProgress = anteil);
      },
    );

    if (!mounted) return;
    if (pfad == null) {
      setState(() {
        _updateBusy = false;
        _updateProgress = null;
        _updateMessage = 'Das Herunterladen ist abgebrochen. Die halbe Datei '
            'wurde gelöscht; mit stabilerem Netz noch einmal versuchen.';
      });
      return;
    }

    setState(() {
      _updateProgress = null;
      _updateFile = pfad;
    });
    await _installFile(pfad);
  }

  Future<void> _installFile(String pfad) async {
    final ergebnis = await _updates.install(pfad);
    if (!mounted) return;
    setState(() {
      _updateBusy = false;
      _updateProgress = null;
      if (ergebnis == InstallOutcome.started) {
        _updateMessage = 'Android übernimmt und fragt gleich um Erlaubnis. '
            'Deine Daten bleiben dabei erhalten.';
      } else if (ergebnis == InstallOutcome.permissionNeeded) {
        _updateMessage = 'BeeBrain darf noch keine Apps installieren. Die '
            'Einstellung dafür ist jetzt offen — erlauben, zurückkommen und '
            'hier noch einmal tippen. Das Paket ist schon geladen.';
      } else if (ergebnis == InstallOutcome.unsupported) {
        _updateMessage = 'Installieren geht nur auf Android.';
      } else {
        _updateMessage = 'Die Installation ließ sich nicht starten. Das '
            'Paket liegt im Zwischenspeicher und lässt sich auch über die '
            'Dateien-App öffnen.';
      }
    });
  }

  // ── Rechnungsnummer-Karte ──────────────────────────────────────
  Widget _buildInvoiceNumberCard() {
    if (_company == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pattern-Eingabe
            const Text(
              'Format-Vorlage',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF8a8a94)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _patternCtrl,
              decoration: InputDecoration(
                hintText: InvoiceNumberGenerator.defaultPattern,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.restore),
                  tooltip: 'Zurücksetzen',
                  onPressed: () {
                    _patternCtrl.text =
                        InvoiceNumberGenerator.defaultPattern;
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Verfügbare Variablen (Chips)
            const Text(
              'Verfügbare Variablen — antippen zum Einfügen:',
              style: TextStyle(fontSize: 11, color: Color(0xFF8a8a94)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: InvoiceNumberGenerator.variables.map((v) {
                return ActionChip(
                  label: Text(
                    v.variable,
                    style: const TextStyle(
                        fontSize: 11, fontFamily: 'monospace'),
                  ),
                  tooltip: '${v.description} → ${v.example}',
                  backgroundColor: _gold.withAlpha(40),
                  side: const BorderSide(color: Colors.transparent),
                  onPressed: () => _insertVariable(v.variable),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Live-Vorschau
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_gold.withAlpha(30), _peach.withAlpha(30)],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _peach.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vorschau (nächste Rechnung):',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8a8a94)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _patternPreview.isEmpty
                        ? '—'
                        : _patternPreview,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _peach,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Variablen-Legende
            _buildVariableLegend(),
            const SizedBox(height: 16),

            // Speichern-Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _patternSaving ? null : _savePattern,
                icon: _patternSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: const Color(0xFF1a0e08)),
                      )
                    : const Icon(Icons.save),
                label:
                    Text(_patternSaving ? 'Speichern…' : 'Format speichern'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariableLegend() {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text(
        'Alle Variablen',
        style: TextStyle(fontSize: 12, color: Color(0xFF8a8a94)),
      ),
      children: InvoiceNumberGenerator.variables
          .map(
            (v) => Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      v.variable,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${v.description}  →  ${v.example}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8a8a94))),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

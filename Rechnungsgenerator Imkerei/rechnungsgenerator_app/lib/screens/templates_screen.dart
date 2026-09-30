import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/design_template_service.dart';
import '../fehlerbericht.dart';
import 'design_customizer_screen.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({Key? key}) : super(key: key);

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  List<DesignTemplateModel> _saved = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Fehlerbericht.logSeite('Vorlagen');
    _load();
  }

  Future<void> _load() async {
    final list = await DesignTemplateService().loadAll();
    if (mounted) setState(() { _saved = list; _loading = false; });
  }

  // ── DIN Standard anwenden ──────────────────────────────────────
  Future<void> _applyDin() async {
    final confirmed = await _confirmDialog(
      'DIN 5008 Standard anwenden?',
      'Design-Einstellungen werden zurückgesetzt:\n'
      '• Keine Bilder / kein Logo\n'
      '• Schwarze Tabellenüberschrift\n'
      '• Standard-Layout',
    );
    if (confirmed != true) return;
    await _applyToDb(DesignTemplateModel(
      id: 'din5008',
      name: 'DIN 5008 Standard',
      tableHeaderColor: '#000000',
      headerTextColor: '#000000',
      headerTextSize: 20,
      createdAt: DateTime.now(),
    ));
  }

  // ── Gespeicherte Vorlage anwenden ──────────────────────────────
  Future<void> _applySaved(DesignTemplateModel t) async {
    final confirmed = await _confirmDialog(
      '„${t.name}" anwenden?',
      'Aktuelle Design-Einstellungen werden überschrieben.',
    );
    if (confirmed != true) return;
    await _applyToDb(t);
  }

  Future<void> _applyToDb(DesignTemplateModel t) async {
    try {
      final db = DatabaseService();
      final companies = await db.getAllCompanies();
      if (companies.isEmpty) {
        _snack('Kein Unternehmen gefunden.');
        return;
      }
      final companyId = companies.first.id;
      final existing = await db.getDesignSettings(companyId);
      final settings = DesignSettingsModel(
        id: existing?.id ?? const Uuid().v4(),
        companyId: companyId,
        headerTextColor: t.headerTextColor,
        headerTextSize: t.headerTextSize,
        tableHeaderColor: t.tableHeaderColor,
        logoUrl: t.logoUrl,
        topHeaderUrl: t.topHeaderUrl,
        layoutJson: t.layoutJson,
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      if (existing != null) {
        await db.updateDesignSettings(settings);
      } else {
        await db.insertDesignSettings(settings);
      }
      _snack('✓ „${t.name}" angewendet');
      Fehlerbericht.log('Template angewendet: ${t.name}');
    } catch (e) {
      _snack('Fehler: $e');
    }
  }

  // ── Vorlage löschen ────────────────────────────────────────────
  Future<void> _delete(DesignTemplateModel t) async {
    final confirmed = await _confirmDialog(
      '„${t.name}" löschen?',
      'Diese Vorlage wird dauerhaft entfernt.',
    );
    if (confirmed != true) return;
    await DesignTemplateService().delete(t.id);
    await _load();
  }

  // ── Design Customizer öffnen ───────────────────────────────────
  Future<void> _openCustomizer() async {
    final companies = await DatabaseService().getAllCompanies();
    if (!mounted) return;
    if (companies.isEmpty) {
      _snack('Bitte zuerst Firmendaten anlegen');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DesignCustomizerScreen(companyId: companies.first.id),
      ),
    );
  }

  // ── Aktuelles Design als Vorlage speichern ─────────────────────
  Future<void> _saveCurrentAsTemplate() async {
    final companies = await DatabaseService().getAllCompanies();
    if (!mounted) return;
    if (companies.isEmpty) { _snack('Kein Unternehmen gefunden.'); return; }

    final existing =
        await DatabaseService().getDesignSettings(companies.first.id);
    if (!mounted) return;
    if (existing == null) { _snack('Noch keine Design-Einstellungen vorhanden.'); return; }

    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vorlage speichern'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name der Vorlage',
            hintText: 'z.B. Imkerei Sommer',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) { _snack('Kein Name eingegeben.'); return; }

    final template = DesignTemplateModel(
      id: const Uuid().v4(),
      name: name,
      tableHeaderColor: existing.tableHeaderColor,
      headerTextColor: existing.headerTextColor,
      headerTextSize: existing.headerTextSize,
      logoUrl: existing.logoUrl,
      topHeaderUrl: existing.topHeaderUrl,
      layoutJson: existing.layoutJson,
      createdAt: DateTime.now(),
    );
    await DesignTemplateService().save(template);
    _snack('✓ Vorlage „$name" gespeichert');
    await _load();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool?> _confirmDialog(String title, String body) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── DIN Standard (eingebaut) ─────────────────────
                _builtInCard(),
                const SizedBox(height: 16),

                // ── Gespeicherte Vorlagen ─────────────────────────
                if (_saved.isNotEmpty) ...[
                  Text(
                    'Gespeicherte Vorlagen',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final t in _saved) ...[
                    _savedCard(t),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                ],

                // ── Eigene Vorlage ────────────────────────────────
                _customCard(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveCurrentAsTemplate,
        icon: const Icon(Icons.bookmark_add_outlined),
        label: const Text('Aktuelles Design speichern'),
      ),
    );
  }

  // ── DIN-Card ───────────────────────────────────────────────────
  Widget _builtInCard() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mini-Vorschau
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Muster GmbH',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text('Muster GmbH · Musterstr. 1 · 12345 Musterstadt',
                    style: TextStyle(fontSize: 7, color: Colors.grey.shade600)),
                Divider(color: Colors.grey.shade400, height: 8, thickness: 0.5),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _pt('Empfänger GmbH'),
                          _pt('Musterstraße 1'),
                          _pt('12345 Stadt'),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _plv('Rechnungsnr.:', '20260001'),
                        _plv('Datum:', '11.05.2026'),
                        _plv('Zahlbar bis:', '25.05.2026'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.verified_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text('DIN 5008 Standard',
                      style: Theme.of(context).textTheme.titleMedium),
                ]),
                const SizedBox(height: 4),
                Text(
                  'Schlichte Rechnung nach DIN 5008 Form B. '
                  'Keine Bilder, schwarze Tabellenüberschrift, Standard-Layout.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _applyDin,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Anwenden'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Gespeicherte Vorlage Card ──────────────────────────────────
  Widget _savedCard(DesignTemplateModel t) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _hexColor(t.tableHeaderColor),
          child: const Icon(Icons.palette, color: Colors.white, size: 18),
        ),
        title: Text(t.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Tabelle: ${t.tableHeaderColor}  '
          '${t.logoUrl != null ? '• Logo' : ''}  '
          '${t.topHeaderUrl != null ? '• Header-Bild' : ''}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_circle_outline),
              tooltip: 'Anwenden',
              onPressed: () => _applySaved(t),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Löschen',
              onPressed: () => _delete(t),
            ),
          ],
        ),
      ),
    );
  }

  // ── Eigene Vorlage Card ────────────────────────────────────────
  Widget _customCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.palette_outlined, size: 22),
              const SizedBox(width: 8),
              Text('Eigene Vorlage erstellen',
                  style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 6),
            Text(
              'Logo, Header-Bild, Farben und Layout-Positionen anpassen. '
              'Danach per „Aktuelles Design speichern" als Vorlage sichern.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openCustomizer,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Design anpassen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────
  Widget _pt(String t) =>
      Text(t, style: const TextStyle(fontSize: 9, color: Colors.black87));

  Widget _plv(String l, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(l, style: const TextStyle(fontSize: 8, color: Colors.black54)),
          const SizedBox(width: 4),
          Text(v,
              style: const TextStyle(
                  fontSize: 8,
                  color: Colors.black87,
                  fontWeight: FontWeight.bold)),
        ]),
      );

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }
}

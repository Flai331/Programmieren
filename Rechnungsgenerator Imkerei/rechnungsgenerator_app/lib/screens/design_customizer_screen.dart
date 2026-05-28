import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../services/services.dart';
import '../models/models.dart';
import '../utils/feedback_service.dart';
import '../widgets/feedback_actions.dart';
import '../widgets/invoice_layout_canvas.dart';

class DesignCustomizerScreen extends StatefulWidget {
  final String companyId;

  const DesignCustomizerScreen({
    Key? key,
    required this.companyId,
  }) : super(key: key);

  @override
  State<DesignCustomizerScreen> createState() => _DesignCustomizerScreenState();
}

class _DesignCustomizerScreenState extends State<DesignCustomizerScreen> {
  late DatabaseService _dbService;
  late SyncService _syncService;
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _headerTextColorController;
  late TextEditingController _headerTextSizeController;
  late TextEditingController _tableHeaderColorController;

  DesignSettingsModel? _designSettings;
  CompanyModel? _company;
  Map<String, String> _textOverrides = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dbService = DatabaseService();
    _syncService = SyncService();

    _headerTextColorController = TextEditingController(text: '#000000');
    _headerTextSizeController = TextEditingController(text: '16');
    _tableHeaderColorController = TextEditingController(text: '#fda085');

    FeedbackService.logScreenLoad('Design & Vorlagen');
    _loadDesignSettings();
  }

  Future<void> _loadDesignSettings() async {
    try {
      // Load company data for real preview
      final companies = await _dbService.getAllCompanies();
      if (companies.isNotEmpty) _company = companies.first;

      final settings = await _dbService.getDesignSettings(widget.companyId);
      if (settings != null) {
        _designSettings = settings;
        _headerTextColorController.text = settings.headerTextColor;
        _headerTextSizeController.text = settings.headerTextSize.toString();
        _tableHeaderColorController.text = settings.tableHeaderColor;
        _textOverrides = InvoiceLayoutCanvas.decodeTexts(settings.layoutJson);
      } else {
        _designSettings = DesignSettingsModel(
          id: const Uuid().v4(),
          companyId: widget.companyId,
          createdAt: DateTime.now(),
        );
        await _dbService.insertDesignSettings(_designSettings!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Encode current layout positions + text overrides into JSON.
  String _encodeLayoutWithTexts(Map<String, ElementPos> layout) {
    return InvoiceLayoutCanvas.encodeLayoutWithTexts(layout, _textOverrides);
  }

  /// Get displayed text: custom override → company data → fallback.
  String _text(String id, String companyDefault) =>
      _textOverrides[id] ?? companyDefault;

  /// Show dialog to edit a text element, save override.
  Future<void> _editText(String id, String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Text bearbeiten'),
        content: TextField(
          controller: ctrl,
          maxLines: null,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Inhalt eingeben …',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _textOverrides[id] = result);
    final ds = _designSettings;
    if (ds == null) return;
    final layout = InvoiceLayoutCanvas.decodeLayout(ds.layoutJson);
    final encoded = _encodeLayoutWithTexts(layout);
    final updated = ds.copyWith(layoutJson: encoded, updatedAt: DateTime.now());
    setState(() => _designSettings = updated);
    try {
      await _dbService.updateDesignSettings(updated);
    } catch (_) {}
  }

  Future<String?> _uploadImage(String prefix) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (image == null) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speichere Bild …')),
      );

      final bytes = await image.readAsBytes();
      final ext = image.name.contains('.')
          ? image.name.split('.').last.toLowerCase()
          : 'png';

      // Lokal im App-Dokumente-Ordner speichern
      final docsDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${docsDir.path}/images/${widget.companyId}');
      await imagesDir.create(recursive: true);
      final fileName =
          '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final file = File('${imagesDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      FeedbackService.log('🖼️ Bild gespeichert: ${file.path}');
      return file.path;
    } catch (e) {
      FeedbackService.logError('Bild speichern: $e', context: 'storage');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _pickLogoImage() async {
    final url = await _uploadImage('logo');
    if (url == null || _designSettings == null) return;
    final updated = _designSettings!.copyWith(
      logoUrl: url,
      updatedAt: DateTime.now(),
    );
    await _dbService.updateDesignSettings(updated);
    if (!mounted) return;
    setState(() => _designSettings = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✓ Logo gespeichert')),
    );
  }

  Future<void> _pickHeaderImage() async {
    final url = await _uploadImage('header');
    if (url == null || _designSettings == null) return;
    final updated = _designSettings!.copyWith(
      topHeaderUrl: url,
      updatedAt: DateTime.now(),
    );
    await _dbService.updateDesignSettings(updated);
    if (!mounted) return;
    setState(() => _designSettings = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✓ Header gespeichert')),
    );
  }

  Future<void> _resetLayout() async {
    final ds = _designSettings;
    if (ds == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Layout zurücksetzen?'),
        content: const Text(
            'Alle Element-Positionen werden auf Standardwerte zurückgesetzt.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Zurücksetzen')),
        ],
      ),
    );
    if (confirmed != true) return;

    // Neues Model ohne layoutJson (copyWith kann nicht auf null setzen)
    final reset = DesignSettingsModel(
      id: ds.id,
      companyId: ds.companyId,
      headerTextColor: ds.headerTextColor,
      headerTextSize: ds.headerTextSize,
      logoUrl: ds.logoUrl,
      topHeaderUrl: ds.topHeaderUrl,
      logoX: ds.logoX,
      logoY: ds.logoY,
      logoWidth: ds.logoWidth,
      logoHeight: ds.logoHeight,
      headerX: ds.headerX,
      headerY: ds.headerY,
      headerWidth: ds.headerWidth,
      headerHeight: ds.headerHeight,
      logoFlipH: ds.logoFlipH,
      logoFlipV: ds.logoFlipV,
      headerFlipH: ds.headerFlipH,
      headerFlipV: ds.headerFlipV,
      tableHeaderColor: ds.tableHeaderColor,
      layoutJson: null,
      createdAt: ds.createdAt,
      updatedAt: DateTime.now(),
    );
    try {
      await _dbService.updateDesignSettings(reset);
      setState(() => _designSettings = reset);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Layout zurückgesetzt')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveDesignSettings() async {
    setState(() => _isSaving = true);

    try {
      final updatedSettings = _designSettings!.copyWith(
        headerTextColor: _headerTextColorController.text,
        headerTextSize: int.tryParse(_headerTextSizeController.text) ?? 16,
        tableHeaderColor: _tableHeaderColorController.text,
        updatedAt: DateTime.now(),
      );

      await _dbService.updateDesignSettings(updatedSettings);

      _syncService.addToQueue(
        operation: 'UPDATE',
        entityType: 'DESIGN_SETTINGS',
        data: updatedSettings.toMap(),
      );

      _designSettings = updatedSettings;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Design-Einstellungen gespeichert')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Design & Vorlagen')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Design & Vorlagen'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveDesignSettings,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Speichern'),
              ),
            ),
          ),
          const FeedbackActions(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo section
            _buildSectionHeader('Logo'),
            const SizedBox(height: 12),
            _buildImageUploadButton(
              label: 'Logo hochladen',
              onPressed: _pickLogoImage,
              imageUrl: _designSettings?.logoUrl,
            ),
            if (_designSettings?.logoUrl != null) ...[
              const SizedBox(height: 12),
              Text(
                '✓ Logo hochgeladen',
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),

            // Header image section
            _buildSectionHeader('Header-Bild'),
            const SizedBox(height: 12),
            _buildImageUploadButton(
              label: 'Header-Bild hochladen',
              onPressed: _pickHeaderImage,
              imageUrl: _designSettings?.topHeaderUrl,
            ),
            if (_designSettings?.topHeaderUrl != null) ...[
              const SizedBox(height: 12),
              Text(
                '✓ Header-Bild hochgeladen',
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),

            // Header text styling
            _buildSectionHeader('Header-Text Styling'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Textfarbe',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _parseColor(
                                    _headerTextColorController.text),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _headerTextColorController,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '#000000',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Schriftgröße',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _headerTextSizeController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          hintText: '16',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Table header color
            _buildSectionHeader('Tabellenbalken-Farbe'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _parseColor(_tableHeaderColorController.text),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _tableHeaderColorController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '#fda085',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Preview section — A4-Canvas mit verschiebbaren Bildern
            _buildSectionHeader('Vorschau (verschieben + Größe ändern)'),
            const SizedBox(height: 8),
            const Text(
              'Ziehen = verschieben · Kante/Ecke = Größe · Doppeltippen = Text bearbeiten',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            _buildPreviewCanvas(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resetLayout,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Layout auf Standard zurücksetzen'),
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveDesignSettings,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Design speichern'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── A4-Canvas mit allen Layout-Elementen ─────────────────────
  Widget _buildPreviewCanvas() {
    final ds = _designSettings;
    if (ds == null) return const SizedBox.shrink();

    final layout = InvoiceLayoutCanvas.decodeLayout(ds.layoutJson);
    final headerColor = _parseColor(_headerTextColorController.text);
    final headerSize = (double.tryParse(_headerTextSizeController.text) ?? 16);

    // Real company data with fallbacks
    final c = _company;
    final companyName = c?.name ?? 'Meine Firma';
    final companyAddrDefault = c != null
        ? '${c.name}\n${c.street} · ${c.zipcode} ${c.city}'
            '${c.phone.isNotEmpty ? '\nTel: ${c.phone}' : ''}'
            '${c.email.isNotEmpty ? ' · ${c.email}' : ''}'
        : 'Meine Firma\nMusterstraße 1 · 12345 Musterstadt';
    final bankDefault = c != null && c.iban != null
        ? 'Bankverbindung: ${c.accountHolder ?? c.name} · ${c.iban}'
            '${c.bic != null ? ' · ${c.bic}' : ''}'
        : 'Bankverbindung: Inhaber · DE00 0000 0000 0000 0000 00 · BIC';

    final elements = <LayoutElement>[
      if (ds.topHeaderUrl != null && ds.topHeaderUrl!.isNotEmpty)
        LayoutElement(
          id: 'header_image',
          label: 'Header-Bild',
          isImage: true,
          builder: (_) => Image.network(ds.topHeaderUrl!,
              fit: BoxFit.fill,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.red.shade100)),
        ),
      if (ds.logoUrl != null && ds.logoUrl!.isNotEmpty)
        LayoutElement(
          id: 'logo',
          label: 'Logo',
          isImage: true,
          builder: (_) => Image.network(ds.logoUrl!,
              fit: BoxFit.fill,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.red.shade100)),
        ),
      LayoutElement(
        id: 'company_header',
        label: 'Firmenname',
        onDoubleTap: () => _editText(
            'company_header', _text('company_header', companyName)),
        builder: (_) => _previewText(
          _text('company_header', companyName),
          color: headerColor,
          bold: true,
          size: headerSize,
        ),
      ),
      LayoutElement(
        id: 'company_address',
        label: 'Absender',
        onDoubleTap: () => _editText(
            'company_address', _text('company_address', companyAddrDefault)),
        builder: (_) => _previewText(
          _text('company_address', companyAddrDefault),
          size: 7,
        ),
      ),
      LayoutElement(
        id: 'customer_address',
        label: 'Empfänger',
        onDoubleTap: () => _editText('customer_address',
            _text('customer_address', 'Musterkunde GmbH\nMusterstraße 1\n12345 Musterstadt')),
        builder: (_) => _previewText(
          _text('customer_address',
              'Musterkunde GmbH\nMusterstraße 1\n12345 Musterstadt'),
          size: 10,
        ),
      ),
      LayoutElement(
        id: 'invoice_meta',
        label: 'Rechnungs-Info',
        onDoubleTap: () => _editText('invoice_meta',
            _text('invoice_meta',
                'Rechnungsnummer:  RE-2026-001\nRechnungsdatum:   05.05.2026\nZahlbar bis:      19.05.2026')),
        builder: (_) => _previewText(
          _text('invoice_meta',
              'Rechnungsnummer:  RE-2026-001\nRechnungsdatum:   05.05.2026\nZahlbar bis:      19.05.2026'),
          size: 10,
        ),
      ),
      LayoutElement(
        id: 'items_table',
        label: 'Positionen',
        builder: (_) => _previewTable(),
      ),
      LayoutElement(
        id: 'summary',
        label: 'Summe',
        onDoubleTap: () => _editText('summary',
            _text('summary',
                'Netto:        50.42 €\nMwSt. (19%):   9.58 €\n_______________________\nGesamt:       60.00 €')),
        builder: (_) => _previewText(
          _text('summary',
              'Netto:        50.42 €\nMwSt. (19%):   9.58 €\n_______________________\nGesamt:       60.00 €'),
          size: 10,
          bold: true,
        ),
      ),
      LayoutElement(
        id: 'bank_info',
        label: 'Bankdaten',
        onDoubleTap: () =>
            _editText('bank_info', _text('bank_info', bankDefault)),
        builder: (_) => _previewText(
          _text('bank_info', bankDefault),
          size: 9,
        ),
      ),
      LayoutElement(
        id: 'footer',
        label: 'Fußzeile',
        onDoubleTap: () => _editText(
            'footer',
            _text('footer', 'Vielen Dank für Ihren Auftrag!')),
        builder: (_) => _previewText(
          _text('footer', 'Vielen Dank für Ihren Auftrag!'),
          size: 9,
          italic: true,
        ),
      ),
    ];

    return InvoiceLayoutCanvas(
      elements: elements,
      initialLayout: layout,
      onLayoutChanged: (newLayout) async {
        final encoded = _encodeLayoutWithTexts(newLayout);
        final updated = ds.copyWith(
          layoutJson: encoded,
          updatedAt: DateTime.now(),
        );
        setState(() => _designSettings = updated);
        try {
          await _dbService.updateDesignSettings(updated);
        } catch (_) {}
      },
    );
  }

  Widget _previewText(
    String text, {
    Color color = Colors.black,
    bool bold = false,
    bool italic = false,
    double size = 10,
  }) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _previewTable() {
    final tableColor = _parseColor(_tableHeaderColorController.text);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: tableColor,
            padding: const EdgeInsets.symmetric(
                horizontal: 4, vertical: 2),
            child: const Row(
              children: [
                Expanded(
                    flex: 1, child: Text('Pos.', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 4,
                    child:
                        Text('Beschreibung', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 1, child: Text('Menge', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 2,
                    child: Text('Preis', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 2,
                    child: Text('Gesamt', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Expanded(flex: 1, child: Text('1', style: TextStyle(fontSize: 8))),
                Expanded(
                    flex: 4,
                    child: Text('Blütenhonig 500g',
                        style: TextStyle(fontSize: 8))),
                Expanded(
                    flex: 1, child: Text('2', style: TextStyle(fontSize: 8))),
                Expanded(
                    flex: 2,
                    child: Text('8.50 €', style: TextStyle(fontSize: 8))),
                Expanded(
                    flex: 2,
                    child: Text('17.00 €', style: TextStyle(fontSize: 8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFFfda085),
      ),
    );
  }

  Widget _buildImageUploadButton({
    required String label,
    required VoidCallback onPressed,
    String? imageUrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageUrl != null && imageUrl.isNotEmpty) ...[
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Center(child: Text('Bild nicht ladbar')),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.image),
            label: Text(imageUrl != null && imageUrl.isNotEmpty
                ? '$label ändern'
                : label),
          ),
        ),
      ],
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xff')));
    } catch (e) {
      return Colors.black;
    }
  }

  @override
  void dispose() {
    _headerTextColorController.dispose();
    _headerTextSizeController.dispose();
    _tableHeaderColorController.dispose();
    super.dispose();
  }
}


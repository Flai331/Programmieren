import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../services/services.dart';
import '../models/models.dart';
import '../utils/utils.dart';

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

  DesignSettingsModel? _designSettings;
  bool _isLoading = true;
  bool _isSaving = false;

  XFile? _selectedLogoFile;
  XFile? _selectedHeaderFile;
  bool _logoRemoved = false;
  bool _headerRemoved = false;

  static const _peach = Color(0xFFfda085);

  @override
  void initState() {
    super.initState();
    _dbService = DatabaseService();
    _syncService = SyncService();

    _headerTextColorController = TextEditingController(text: '#000000');
    _headerTextSizeController = TextEditingController(text: '16');

    _loadDesignSettings();
  }

  Future<void> _loadDesignSettings() async {
    try {
      final settings = await _dbService.getDesignSettings(widget.companyId);
      if (settings != null) {
        _designSettings = settings;
        _headerTextColorController.text = settings.headerTextColor;
        _headerTextSizeController.text = settings.headerTextSize.toString();
      } else {
        _designSettings = DesignSettingsModel(
          id: const Uuid().v4(),
          companyId: widget.companyId,
          createdAt: DateTime.now(),
        );
        await _dbService.insertDesignSettings(_designSettings!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickLogoImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedLogoFile = image;
          _logoRemoved = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _pickHeaderImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedHeaderFile = image;
          _headerRemoved = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _saveDesignSettings() async {
    setState(() => _isSaving = true);
    try {
      final logoPath = _logoRemoved
          ? null
          : (_selectedLogoFile?.path ?? _designSettings!.logoUrl);
      final headerPath = _headerRemoved
          ? null
          : (_selectedHeaderFile?.path ?? _designSettings!.topHeaderUrl);

      final updatedSettings = DesignSettingsModel(
        id: _designSettings!.id,
        companyId: _designSettings!.companyId,
        headerTextColor: _headerTextColorController.text,
        headerTextSize: int.tryParse(_headerTextSizeController.text) ?? 16,
        logoUrl: logoPath,
        topHeaderUrl: headerPath,
        logoX: _designSettings!.logoX,
        logoY: _designSettings!.logoY,
        headerX: _designSettings!.headerX,
        headerY: _designSettings!.headerY,
        headerWidth: _designSettings!.headerWidth,
        headerHeight: _designSettings!.headerHeight,
        createdAt: _designSettings!.createdAt,
        updatedAt: DateTime.now(),
      );

      await _dbService.updateDesignSettings(updatedSettings);

      _syncService.addToQueue(
        operation: 'UPDATE',
        entityType: 'DESIGN_SETTINGS',
        data: updatedSettings.toMap(),
      );

      setState(() => _designSettings = updatedSettings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Design gespeichert')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Logo'),
            const SizedBox(height: 4),
            Text(
              'Erscheint oben links auf der Rechnung',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            _buildImageSection(
              pickLabel: 'Logo hochladen',
              onPick: _pickLogoImage,
              onRemove: () => setState(() {
                _selectedLogoFile = null;
                _logoRemoved = true;
              }),
              selectedFile: _selectedLogoFile,
              savedPath: _logoRemoved ? null : _designSettings?.logoUrl,
              aspectHint: 'Quadratisch empfohlen (z.B. 200×200 px)',
            ),
            const SizedBox(height: 28),

            _buildSectionHeader('Header-Bild'),
            const SizedBox(height: 4),
            Text(
              'Breites Bannerbild ganz oben auf der Rechnung',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            _buildImageSection(
              pickLabel: 'Header-Bild hochladen',
              onPick: _pickHeaderImage,
              onRemove: () => setState(() {
                _selectedHeaderFile = null;
                _headerRemoved = true;
              }),
              selectedFile: _selectedHeaderFile,
              savedPath: _headerRemoved ? null : _designSettings?.topHeaderUrl,
              aspectHint: 'Breitformat empfohlen (z.B. 1200×300 px)',
              previewHeight: 110,
            ),
            const SizedBox(height: 28),

            _buildSectionHeader('Header-Text Styling'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Textfarbe',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Schriftgröße',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _headerTextSizeController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          hintText: '16',
                          suffixText: 'pt',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            _buildSectionHeader('Vorschau'),
            const SizedBox(height: 12),
            _buildLivePreview(),
            const SizedBox(height: 32),

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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Bild-Sektion mit Vorschau ────────────────────────────────
  Widget _buildImageSection({
    required String pickLabel,
    required VoidCallback onPick,
    required VoidCallback onRemove,
    XFile? selectedFile,
    String? savedPath,
    String? aspectHint,
    double previewHeight = 140,
  }) {
    final hasImage =
        selectedFile != null || (savedPath != null && savedPath.isNotEmpty);

    if (!hasImage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.add_photo_alternate_outlined, color: _peach),
              label: Text(pickLabel, style: const TextStyle(color: _peach)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _peach),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (aspectHint != null) ...[
            const SizedBox(height: 4),
            Text(aspectHint,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vorschau-Container
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            height: previewHeight,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildImageWidget(selectedFile, savedPath, previewHeight),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.edit_outlined, size: 18, color: _peach),
                label: const Text('Ändern', style: TextStyle(color: _peach)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _peach),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: Colors.red),
              label: const Text('Entfernen',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageWidget(
      XFile? file, String? savedPath, double height) {
    if (file != null) {
      return Image.file(
        File(file.path),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    }
    if (savedPath != null && savedPath.isNotEmpty) {
      if (savedPath.startsWith('http')) {
        return Image.network(
          savedPath,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
          errorBuilder: (_, __, ___) => _imagePlaceholder(),
        );
      }
      return Image.file(
        File(savedPath),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
          SizedBox(height: 4),
          Text('Bild nicht gefunden',
              style: TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  // ── Live-Vorschau ────────────────────────────────────────────
  Widget _buildLivePreview() {
    final headerColor = _parseColor(_headerTextColorController.text);
    final textSize =
        (double.tryParse(_headerTextSizeController.text) ?? 16).clamp(8.0, 32.0);

    final logoFile = _selectedLogoFile;
    final logoPath = _logoRemoved ? null : _designSettings?.logoUrl;
    final hasLogo = logoFile != null || (logoPath != null && logoPath.isNotEmpty);

    final headerFile = _selectedHeaderFile;
    final headerPath = _headerRemoved ? null : _designSettings?.topHeaderUrl;
    final hasHeader =
        headerFile != null || (headerPath != null && headerPath.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header-Bild
          if (hasHeader)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              child: SizedBox(
                width: double.infinity,
                height: 70,
                child: _buildImageWidget(headerFile, headerPath, 70),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                if (hasLogo) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: _buildImageWidget(logoFile, logoPath, 48),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Imkerei Mustermann',
                        style: TextStyle(
                          color: headerColor,
                          fontSize: textSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Musterstraße 1 · 12345 Musterstadt',
                        style: TextStyle(
                            fontSize: textSize * 0.55, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(height: 2, color: headerColor),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Vorschau – so sieht der Rechnungskopf aus',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
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
          fontSize: 16, fontWeight: FontWeight.bold, color: _peach),
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xff')));
    } catch (_) {
      return Colors.black;
    }
  }

  @override
  void dispose() {
    _headerTextColorController.dispose();
    _headerTextSizeController.dispose();
    super.dispose();
  }
}

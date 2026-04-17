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
        // Create default settings
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

  Future<void> _pickLogoImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        // TODO: Upload to Cloudinary
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo ausgewählt. Session 5: Cloudinary Upload'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden: $e')),
      );
    }
  }

  Future<void> _pickHeaderImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        // TODO: Upload to Cloudinary
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Header-Bild ausgewählt. Session 5: Cloudinary Upload'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden: $e')),
      );
    }
  }

  Future<void> _saveDesignSettings() async {
    setState(() => _isSaving = true);

    try {
      final updatedSettings = _designSettings!.copyWith(
        headerTextColor: _headerTextColorController.text,
        headerTextSize: int.tryParse(_headerTextSizeController.text) ?? 16,
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

            // Preview section
            _buildSectionHeader('Vorschau'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[50],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Beispiel Header-Text',
                    style: TextStyle(
                      color: _parseColor(_headerTextColorController.text),
                      fontSize: double.tryParse(_headerTextSizeController.text) ??
                          16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dies ist eine Vorschau der gewählten Einstellungen',
                    style: TextStyle(
                      color: _parseColor(_headerTextColorController.text),
                      fontSize: (double.tryParse(_headerTextSizeController.text) ??
                              16) *
                          0.75,
                    ),
                  ),
                ],
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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.image),
        label: Text(label),
      ),
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
    super.dispose();
  }
}

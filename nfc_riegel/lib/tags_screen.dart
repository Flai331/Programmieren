import 'dart:async';

import 'package:flutter/material.dart';

import 'lock_status.dart';
import 'riegel_channel.dart';
import 'theme.dart';
import 'ui/anker_surfaces.dart';

/// Angelernte Chips anzeigen, neue anlernen, alte löschen.
class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key, required this.status, required this.channel});

  final LockStatus status;
  final RiegelChannel channel;

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  late LockStatus _status = widget.status;
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final status = await widget.channel.getState();
    if (mounted) setState(() => _status = status);
  }

  /// Nach dem Anlernen wartet der Bildschirm darauf, dass die native Seite den
  /// neuen Chip meldet.
  void _startPolling(int previousCount) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final status = await widget.channel.getState();
      if (!mounted) return;
      setState(() => _status = status);
      if (status.tags.length != previousCount) timer.cancel();
    });
  }

  Future<void> _enroll() async {
    final result = await showDialog<_EnrollRequest>(
      context: context,
      builder: (_) => _EnrollDialog(profiles: _status.profiles),
    );
    if (result == null) return;
    await widget.channel.startTagEnrollment(
      label: result.label,
      profileId: result.profileId,
    );
    _startPolling(_status.tags.length);
  }

  Future<void> _delete(TagInfo tag) async {
    final ok = await widget.channel.deleteTag(tag.uid);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Während einer Sperre nicht möglich')),
      );
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chips'),
        actions: [
          TextButton(onPressed: _enroll, child: const Text('Anlernen')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(RiegelSpacing.s4),
        children: [
          // Die Anlernfläche steht oben und ist der Weg, nicht eine Zeile in
          // der Liste. Gestrichelt, weil sie auf etwas wartet, das noch fehlt.
          _AnlernFlaeche(onTap: _enroll),
          const SizedBox(height: RiegelSpacing.s6),
          SectionLabel('Angelernt · ${_status.tags.length}'),
          for (final tag in _status.tags)
            Padding(
              padding: const EdgeInsets.only(bottom: RiegelSpacing.s2),
              child: Container(
                decoration: ankerSurface(radius: RiegelRadii.xl),
                padding: const EdgeInsets.all(RiegelSpacing.s4),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: RiegelColors.accentTint,
                        borderRadius: BorderRadius.circular(RiegelRadii.md + 2),
                      ),
                      child: const Icon(
                        Icons.nfc,
                        size: 19,
                        color: RiegelColors.accent,
                      ),
                    ),
                    const SizedBox(width: RiegelSpacing.s3),
                    // Der Ort steht groß, das Profil klein darunter: ein Chip
                    // ist ein Ort — „Schreibtisch", „Nachttisch" —, kein Knopf.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tag.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: RiegelColors.fg1,
                            ),
                          ),
                          Text(
                            _profileName(tag.profileId),
                            style: const TextStyle(
                              fontSize: 12,
                              color: RiegelColors.fg3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(tag),
                    ),
                  ],
                ),
              ),
            ),
          if (_status.tags.isEmpty)
            const Text(
              'Noch kein Chip angelernt.',
              style: TextStyle(color: RiegelColors.fg3),
            ),
        ],
      ),
    );
  }

  String _profileName(String id) {
    for (final p in _status.profiles) {
      if (p.id == id) return p.name;
    }
    return 'Unbekannt';
  }
}

/// Die Fläche zum Anlernen: gestrichelter Rahmen, pulsierender NFC-Ring.
class _AnlernFlaeche extends StatelessWidget {
  const _AnlernFlaeche({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RiegelRadii.xxl - 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: RiegelSpacing.s8 - 4,
          horizontal: RiegelSpacing.s5,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(RiegelRadii.xxl - 4),
          color: RiegelColors.accent.withValues(alpha: 0.06),
          border: Border.all(
            color: RiegelColors.accent.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            const NfcPulse(),
            const SizedBox(height: RiegelSpacing.s4),
            const Text(
              'Neuen Chip anlernen',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: RiegelColors.fg1,
              ),
            ),
            const SizedBox(height: RiegelSpacing.s1 + 2),
            const Text(
              'Chip an die Rückseite halten und den Ort benennen.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: RiegelColors.fg2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnrollRequest {
  const _EnrollRequest(this.label, this.profileId);

  final String label;
  final String profileId;
}

class _EnrollDialog extends StatefulWidget {
  const _EnrollDialog({required this.profiles});

  final List<ProfileInfo> profiles;

  @override
  State<_EnrollDialog> createState() => _EnrollDialogState();
}

class _EnrollDialogState extends State<_EnrollDialog> {
  final _label = TextEditingController();
  late String _profileId = widget.profiles.first.id;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chip anlernen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _label,
            decoration: const InputDecoration(labelText: 'Bezeichnung'),
          ),
          const SizedBox(height: RiegelSpacing.s4),
          DropdownButtonFormField<String>(
            initialValue: _profileId,
            decoration: const InputDecoration(labelText: 'Profil'),
            items: [
              for (final p in widget.profiles)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => _profileId = v ?? _profileId),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _EnrollRequest(
              _label.text.trim().isEmpty ? 'Chip' : _label.text.trim(),
              _profileId,
            ),
          ),
          child: const Text('Weiter'),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import 'lock_status.dart';
import 'riegel_channel.dart';
import 'theme.dart';

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
          for (final tag in _status.tags)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.nfc, color: RiegelColors.accent),
              title: Text(tag.label),
              subtitle: Text(
                _profileName(tag.profileId),
                style: const TextStyle(fontSize: 12, color: RiegelColors.fg3),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(tag),
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

// ═══════════════════════════════════════════════════════════════
//  QUICK-IDEE DIALOG
//  Wird vom Homescreen-Widget geöffnet.
//  App-Liste wird live aus Notion geladen.
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../app_colors.dart';
import '../secrets.dart';

const _notionToken = kNotionIdeenToken;
const _notionDbId  = '946c45e86e394da8933aff054573e4e2';

Future<void> showQuickIdeaSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _QuickIdeaSheet(),
  );
}

const _fallbackApps = [
  '💡 Ideen & Features',
  'Sauerteig Planer',
  'RHS Trainingstagebuch',
  '🐠 Aquarium Task-Manager',
  '🐝 Imkerei-Management-System',
  'Rechnungs-Automation',
  'Kalender/To-Do Manager',
];

Future<List<String>> _fetchAppOptions() async {
  try {
    final res = await http.get(
      Uri.parse('https://api.notion.com/v1/databases/$_notionDbId'),
      headers: {
        'Authorization': 'Bearer $_notionToken',
        'Notion-Version': '2022-06-28',
      },
    ).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return _fallbackApps;
    final data = jsonDecode(res.body);
    final options = data['properties']?['App']?['select']?['options'] as List?;
    if (options == null || options.isEmpty) return _fallbackApps;
    return options.map<String>((o) => o['name'] as String).toList();
  } catch (_) {
    return _fallbackApps;
  }
}

class _QuickIdeaSheet extends StatefulWidget {
  const _QuickIdeaSheet();
  @override
  State<_QuickIdeaSheet> createState() => _QuickIdeaSheetState();
}

class _QuickIdeaSheetState extends State<_QuickIdeaSheet> {
  final _textCtrl = TextEditingController();

  String?      _app;
  String?      _prio;
  List<String> _appOptions  = [];
  bool         _loadingApps = true;

  bool    _sending = false;
  String? _error;
  bool    _done    = false;

  static const _prios = ['Direkt', 'Optional', 'Erstmal nicht umsetzen'];

  static const _prioColors = {
    'Direkt':                 Color(0xFFE74C3C),
    'Optional':               Color(0xFFF39C12),
    'Erstmal nicht umsetzen': Color(0xFF888888),
  };

  String get _effectivePrio {
    if (_prio != null) return _prio!;
    return _app == null ? 'Erstmal nicht umsetzen' : 'Optional';
  }

  @override
  void initState() {
    super.initState();
    _appOptions = _fallbackApps;
    _loadingApps = false;
    _fetchAppOptions().then((opts) {
      if (mounted) setState(() => _appOptions = opts);
    });
  }

  Color _colorForApp(String app) {
    const palette = [
      Color(0xFFC8A84B), Color(0xFF5B9BD5), Color(0xFF1ABC9C),
      Color(0xFF2ECC71), Color(0xFFE67E22), Color(0xFFE74C3C),
      Color(0xFF9B59B6), Color(0xFF3498DB), Color(0xFF16A085),
    ];
    final i = _appOptions.indexOf(app);
    return palette[i.clamp(0, palette.length - 1)];
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Bitte eine Idee eingeben.');
      return;
    }
    setState(() { _sending = true; _error = null; });

    try {
      final properties = <String, dynamic>{
        'Beschreibung': {
          'title': [{'text': {'content': text}}]
        },
        'Status': {'status': {'name': 'Offen'}},
        'Priorität': {'select': {'name': _effectivePrio}},
      };
      if (_app != null) {
        properties['App'] = {'select': {'name': _app}};
      }

      final res = await http.post(
        Uri.parse('https://api.notion.com/v1/pages'),
        headers: {
          'Authorization': 'Bearer $_notionToken',
          'Notion-Version': '2022-06-28',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'parent': {'database_id': _notionDbId}, 'properties': properties}),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() { _done = true; _sending = false; });
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() { _error = 'Fehler ${res.statusCode}'; _sending = false; });
      }
    } catch (e) {
      setState(() { _error = 'Netzwerkfehler: $e'; _sending = false; });
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.4)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: _done ? _buildDone() : _buildForm(),
    );
  }

  Widget _buildDone() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 24),
        Text('💡', style: TextStyle(fontSize: 40)),
        SizedBox(height: 12),
        Text('Idee gespeichert!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        SizedBox(height: 8),
        Text('Sie wurde in Notion eingetragen.',
            style: TextStyle(color: Colors.white54)),
        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('💡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          const Text('Neue Idee',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white38, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
        const SizedBox(height: 14),

        TextField(
          controller: _textCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          maxLines: 3,
          minLines: 1,
          decoration: InputDecoration(
            hintText: 'Idee hier eingeben …',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),

        Row(children: [
          const Text('App (optional)', style: TextStyle(color: Colors.white38, fontSize: 11)),
          if (_loadingApps) ...[
            const SizedBox(width: 8),
            const SizedBox(width: 10, height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white24)),
          ],
        ]),
        const SizedBox(height: 6),
        if (!_loadingApps && _appOptions.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _appOptions.map((app) {
              final selected = _app == app;
              final color = _colorForApp(app);
              return GestureDetector(
                onTap: () => setState(() => _app = selected ? null : app),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withOpacity(0.2)
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? color : Colors.white.withOpacity(0.12),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(app,
                      style: TextStyle(
                        color: selected ? color : Colors.white38,
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      )),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 14),

        Row(children: [
          const Text('Priorität: ', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ..._prios.map((p) {
            final selected = _prio == p;
            final isAuto   = _prio == null && p == _effectivePrio;
            final color = _prioColors[p]!;
            return GestureDetector(
              onTap: () => setState(() => _prio = selected ? null : p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (selected || isAuto)
                      ? color.withOpacity(0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (selected || isAuto)
                        ? color
                        : Colors.white.withOpacity(0.12),
                  ),
                ),
                child: Text(p,
                    style: TextStyle(
                      color: (selected || isAuto) ? color : Colors.white38,
                      fontSize: 11,
                      fontWeight: (selected || isAuto) ? FontWeight.bold : FontWeight.normal,
                    )),
              ),
            );
          }),
        ]),

        if (_app == null)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Ohne App → Priorität automatisch "Erstmal nicht umsetzen"',
                style: TextStyle(color: Colors.white24, fontSize: 10)),
          ),
        const SizedBox(height: 16),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(_error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _sending ? null : _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _sending
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Text('Idee speichern',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ],
    );
  }
}

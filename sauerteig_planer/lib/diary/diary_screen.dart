import 'package:flutter/material.dart';
import '../app_colors.dart';
import 'diary_models.dart';
import 'diary_storage.dart';
import 'diary_entry_card.dart';
import 'diary_entry_edit_screen.dart';
import 'diary_search_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  DIARY SCREEN — Timeline
// ═══════════════════════════════════════════════════════════════

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  List<DiaryEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await DiaryStorage.loadAll();
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _newEntry() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DiaryEntryEditScreen()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('📓 Tagebuch',
            style: TextStyle(color: AppColors.gold)),
        iconTheme: const IconThemeData(color: AppColors.gold),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.text2),
            tooltip: 'Suche',
            onPressed: _entries.isEmpty
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DiarySearchScreen(entries: _entries),
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newEntry,
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.bg,
        icon: const Icon(Icons.add),
        label: const Text('Eintrag'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.orange))
          : _entries.isEmpty
              ? _buildEmpty()
              : _buildTimeline(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📓', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text('Noch keine Einträge',
              style: TextStyle(color: AppColors.text2, fontSize: 18)),
          const SizedBox(height: 8),
          const Text(
            'Halte deine Fütterungen, Beobachtungen\nund Backergebnisse fest.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.text3, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _newEntry,
            icon: const Icon(Icons.add),
            label: const Text('Ersten Eintrag erstellen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: AppColors.bg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    // Gruppiere nach Monat
    final groups = <String, List<DiaryEntry>>{};
    for (final e in _entries) {
      final key = _monthKey(e.timestamp);
      groups.putIfAbsent(key, () => []).add(e);
    }

    final monthKeys = groups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: monthKeys.length,
      itemBuilder: (_, i) {
        final key = monthKeys[i];
        final monthEntries = groups[key]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Monats-Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Text(
                key,
                style: const TextStyle(
                  color: AppColors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            ...monthEntries.map((e) => DiaryEntryCard(
                  entry: e,
                  onChanged: _load,
                )),
          ],
        );
      },
    );
  }

  String _monthKey(DateTime d) {
    const months = [
      'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
      'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
    ];
    return '${months[d.month - 1]} ${d.year}'.toUpperCase();
  }
}

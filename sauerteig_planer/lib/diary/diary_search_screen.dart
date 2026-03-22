import 'package:flutter/material.dart';
import '../app_colors.dart';
import 'diary_models.dart';
import 'diary_entry_card.dart';

// ═══════════════════════════════════════════════════════════════
//  DIARY SEARCH SCREEN
// ═══════════════════════════════════════════════════════════════

class DiarySearchScreen extends StatefulWidget {
  final List<DiaryEntry> entries;

  const DiarySearchScreen({super.key, required this.entries});

  @override
  State<DiarySearchScreen> createState() => _DiarySearchScreenState();
}

class _DiarySearchScreenState extends State<DiarySearchScreen> {
  String _query = '';
  DiaryEntryType? _typeFilter;
  List<DiaryEntry> _results = [];

  @override
  void initState() {
    super.initState();
    _results = widget.entries;
  }

  void _filter(String query) {
    setState(() {
      _query = query;
      _applyFilter();
    });
  }

  void _setTypeFilter(DiaryEntryType? type) {
    setState(() {
      _typeFilter = type;
      _applyFilter();
    });
  }

  void _applyFilter() {
    _results = widget.entries.where((e) {
      final matchesType = _typeFilter == null || e.type == _typeFilter;
      final q = _query.toLowerCase();
      final matchesQuery = q.isEmpty || e.text.toLowerCase().contains(q);
      return matchesType && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: TextField(
          autofocus: true,
          style: const TextStyle(color: AppColors.text),
          cursorColor: AppColors.orange,
          decoration: const InputDecoration(
            hintText: 'Einträge durchsuchen...',
            hintStyle: TextStyle(color: AppColors.text3),
            border: InputBorder.none,
          ),
          onChanged: _filter,
        ),
        iconTheme: const IconThemeData(color: AppColors.gold),
      ),
      body: Column(
        children: [
          // Typ-Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                _filterChip(null, 'Alle', AppColors.text2),
                ...DiaryEntryType.values.map((t) => _filterChip(
                      t,
                      '${kEntryTypeEmoji[t]} ${kEntryTypeLabel[t]}',
                      kEntryTypeColor[t] ?? AppColors.text2,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Ergebnisse
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty
                          ? 'Wähle einen Filter'
                          : 'Keine Ergebnisse für „$_query"',
                      style:
                          const TextStyle(color: AppColors.text3),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: _results.length,
                    itemBuilder: (_, i) => DiaryEntryCard(
                      entry: _results[i],
                      onChanged: () => Navigator.pop(context),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(DiaryEntryType? type, String label, Color color) {
    final selected = _typeFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label,
            style: TextStyle(
              color: selected ? AppColors.bg : color,
              fontSize: 12,
            )),
        selected: selected,
        selectedColor: color,
        backgroundColor: AppColors.surface,
        side: BorderSide(color: selected ? color : AppColors.border),
        onSelected: (_) => _setTypeFilter(type),
        showCheckmark: false,
      ),
    );
  }
}

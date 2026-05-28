import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../utils/app_utils.dart';
import 'letter_edit_screen.dart';

class LetterListScreen extends StatefulWidget {
  const LetterListScreen({Key? key}) : super(key: key);

  @override
  State<LetterListScreen> createState() => _LetterListScreenState();
}

class _LetterListScreenState extends State<LetterListScreen> {
  final _db = DatabaseService();
  late Future<List<LetterModel>> _future;
  static const _peach = Color(0xFFfda085);

  @override
  void initState() {
    super.initState();
    _future = _db.getAllLetters();
  }

  void _reload() => setState(() => _future = _db.getAllLetters());

  Future<void> _delete(LetterModel l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Brief löschen'),
        content: Text('„${l.subject ?? "Brief"}" wirklich löschen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Löschen',
                  style: TextStyle(color: Color(0xFFff6b7a)))),
        ],
      ),
    );
    if (ok == true) {
      await _db.deleteLetter(l.id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<LetterModel>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final letters = snap.data ?? [];
          if (letters.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mail_outline,
                      size: 64, color: Color(0xFF8a8a94)),
                  const SizedBox(height: 16),
                  const Text('Keine Briefe vorhanden'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LetterEditScreen()),
                      );
                      _reload();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Ersten Brief erstellen'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: letters.length,
              itemBuilder: (_, i) {
                final l = letters[i];
                final color = l.status == 'sent'
                    ? const Color(0xFF22c55e)
                    : const Color(0xFF8a8a94);
                final label = l.status == 'sent' ? 'Versandt' : 'Entwurf';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                LetterEditScreen(letterId: l.id)),
                      );
                      _reload();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(
                                l.subject?.isNotEmpty == true
                                    ? l.subject!
                                    : '(ohne Betreff)',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withAlpha(38),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: color, width: 1),
                              ),
                              child: Text(label,
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                            '${l.recipientName ?? "–"}'
                            '${l.recipientCity != null ? " · ${l.recipientCity}" : ""}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF8a8a94)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            l.letterDate != null
                                ? AppUtils.formatDate(l.letterDate!)
                                : AppUtils.formatDate(l.createdAt),
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF8a8a94)),
                          ),
                          const SizedBox(height: 6),
                          Wrap(alignment: WrapAlignment.end, children: [
                            TextButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          LetterEditScreen(letterId: l.id)),
                                );
                                _reload();
                              },
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Bearbeiten'),
                            ),
                            TextButton.icon(
                              onPressed: () => _delete(l),
                              icon: const Icon(Icons.delete,
                                  size: 16, color: Color(0xFFff6b7a)),
                              label: const Text('Löschen',
                                  style: TextStyle(color: Color(0xFFff6b7a))),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _peach,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LetterEditScreen()),
          );
          _reload();
        },
        icon: const Icon(Icons.add),
        label: const Text('Neuer Brief'),
      ),
    );
  }
}

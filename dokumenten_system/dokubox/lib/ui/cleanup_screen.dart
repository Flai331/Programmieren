import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_services.dart';
import '../data/database.dart';
import 'document_detail_screen.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');

/// Ausmistliste: Dokumente mit abgelaufener Aufbewahrungsfrist, deren
/// Original noch existiert. Raussuchen, schreddern, abhaken.
class CleanupScreen extends StatelessWidget {
  const CleanupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ausmistliste')),
      body: StreamBuilder<List<Document>>(
        stream: services.repository.watchCleanupCandidates(),
        builder: (context, snapshot) {
          final docs = snapshot.data;
          if (docs == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nichts auszumisten. 🎉\n\nDokumente erscheinen hier, '
                  'sobald ihre Aufbewahrungsfrist abgelaufen ist.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              return ListTile(
                title: Text(doc.title.isEmpty ? doc.docNumber : doc.title),
                subtitle: Text(
                  '${doc.docNumber} · ${doc.storageLocation} · Frist: '
                  '${_dateFormat.format(doc.retentionUntil!)}',
                ),
                trailing: FilledButton.tonal(
                  onPressed: () async {
                    await services.repository.markDestroyed(doc.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '${doc.docNumber} als vernichtet markiert '
                              '(Scan bleibt erhalten)'),
                        ),
                      );
                    }
                  },
                  child: const Text('Vernichtet'),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DocumentDetailScreen(documentId: doc.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

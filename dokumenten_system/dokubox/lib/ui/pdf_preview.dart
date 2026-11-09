import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../scan/scan_service.dart';

/// Vorschau der ersten Seite eines gespeicherten Dokuments. Antippen öffnet
/// das ganze Original (alle Seiten, zoombar) — zum Kontrollieren, ob die
/// erkannten Angaben stimmen.
class OriginalPreview extends StatelessWidget {
  /// Pfad relativ zum App-Dokumentenverzeichnis (wie in der Datenbank).
  final String relativePdfPath;
  final String title;
  final double height;

  const OriginalPreview({
    super.key,
    required this.relativePdfPath,
    this.title = 'Original',
    this.height = 240,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<String>(
      future: ScanService.absolutePdfPath(relativePdfPath),
      builder: (context, snap) {
        final path = snap.data;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: path == null
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PdfViewerScreen(path: path, title: title),
                    )),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: height,
                  child: path == null
                      ? const Center(child: CircularProgressIndicator())
                      : ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: PdfDocumentViewBuilder.file(
                            path,
                            builder: (context, document) => document == null
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: PdfPageView(
                                      document: document,
                                      pageNumber: 1,
                                      maximumDpi: 150,
                                    ),
                                  ),
                          ),
                        ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.zoom_in, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Original ansehen – antippen zum Vergrößern',
                            style: theme.textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Ganzes Dokument in der App anzeigen (blättern, mit zwei Fingern zoomen).
class PdfViewerScreen extends StatelessWidget {
  final String path;
  final String title;

  const PdfViewerScreen({super.key, required this.path, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfViewer.file(path),
    );
  }
}

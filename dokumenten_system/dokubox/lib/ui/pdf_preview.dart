import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../scan/scan_service.dart';

/// Kleine Vorschau eines gespeicherten Dokuments – direkt mit zwei Fingern
/// zoombar. Der Ausschnitt bleibt stehen (auch nach der Vollansicht), damit
/// man z. B. einen Namen bequem abschreiben kann. Mit [onTogglePin] lässt
/// sie sich oben anheften, während man darunter tippt.
class OriginalPreview extends StatefulWidget {
  /// Pfad relativ zum App-Dokumentenverzeichnis (wie in der Datenbank).
  final String relativePdfPath;
  final String title;
  final double height;
  final bool pinned;
  final VoidCallback? onTogglePin;

  const OriginalPreview({
    super.key,
    required this.relativePdfPath,
    this.title = 'Original',
    this.height = 240,
    this.pinned = false,
    this.onTogglePin,
  });

  @override
  State<OriginalPreview> createState() => _OriginalPreviewState();
}

class _OriginalPreviewState extends State<OriginalPreview> {
  final _ctl = PdfViewerController();
  late Future<String> _path = ScanService.absolutePdfPath(widget.relativePdfPath);

  /// Zuletzt gewählter Ausschnitt (Dokument-Koordinaten).
  Rect? _area;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    // Jede Änderung (Pinch, Doppeltipp, Verschieben) merken.
    _ctl.addListener(_remember);
  }

  @override
  void dispose() {
    _ctl.removeListener(_remember);
    super.dispose();
  }

  @override
  void didUpdateWidget(OriginalPreview old) {
    super.didUpdateWidget(old);
    if (old.relativePdfPath != widget.relativePdfPath) {
      _path = ScanService.absolutePdfPath(widget.relativePdfPath);
      _area = null;
    }
  }

  void _remember() {
    if (!_ctl.isReady) return;
    _area = _ctl.visibleRect;
    final z = _ctl.currentZoom > _ctl.minScale * 1.05;
    if (z != _zoomed && mounted) setState(() => _zoomed = z);
  }

  Future<void> _openFull(String path) async {
    final area = await Navigator.of(context).push<Rect>(MaterialPageRoute(
      builder: (_) => PdfViewerScreen(
          path: path, title: widget.title, initialArea: _ctl.isReady ? _ctl.visibleRect : null),
    ));
    if (area != null && _ctl.isReady) {
      _area = area;
      await _ctl.goToArea(rect: area, anchor: PdfPageAnchor.all, duration: Duration.zero);
      _remember();
    }
  }

  Future<void> _reset() async {
    if (!_ctl.isReady) return;
    await _ctl.goToPage(pageNumber: 1, anchor: PdfPageAnchor.all);
    _remember();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<String>(
      future: _path,
      builder: (context, snap) {
        final path = snap.data;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: widget.height,
            child: path == null
                ? const Center(child: CircularProgressIndicator())
                : Stack(children: [
                    Positioned.fill(
                      child: PdfViewer.file(
                        path,
                        controller: _ctl,
                        params: PdfViewerParams(
                          margin: 4,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          maxScale: 12,
                          onViewerReady: (_, c) {
                            final a = _area;
                            if (a != null) {
                              c.goToArea(rect: a, anchor: PdfPageAnchor.all, duration: Duration.zero);
                            } else {
                              c.goToPage(pageNumber: 1, anchor: PdfPageAnchor.all, duration: Duration.zero);
                            }
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (_zoomed)
                          _OverlayButton(
                              icon: Icons.zoom_out_map, tooltip: 'Ganze Seite', onTap: _reset),
                        if (widget.onTogglePin != null)
                          _OverlayButton(
                            icon: widget.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                            tooltip: widget.pinned ? 'Lösen' : 'Oben anheften',
                            onTap: widget.onTogglePin!,
                          ),
                        _OverlayButton(
                            icon: Icons.fullscreen,
                            tooltip: 'Vollbild',
                            onTap: () => _openFull(path)),
                      ]),
                    ),
                    if (!_zoomed && !widget.pinned)
                      Positioned(
                        left: 8,
                        bottom: 6,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withValues(alpha: .85),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Mit zwei Fingern zoomen – Ausschnitt bleibt',
                                style: theme.textTheme.bodySmall),
                          ),
                        ),
                      ),
                  ]),
          ),
        );
      },
    );
  }
}

class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _OverlayButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          tooltip: tooltip,
          icon: Icon(icon, size: 20),
          onPressed: onTap,
        ),
      );
}

/// Ganzes Dokument in der App anzeigen (blättern, mit zwei Fingern zoomen).
/// Gibt beim Schließen den zuletzt gezeigten Ausschnitt zurück.
class PdfViewerScreen extends StatefulWidget {
  final String path;
  final String title;
  final Rect? initialArea;

  const PdfViewerScreen(
      {super.key, required this.path, required this.title, this.initialArea});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final _ctl = PdfViewerController();

  @override
  Widget build(BuildContext context) {
    return PopScope<Rect>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_ctl.isReady ? _ctl.visibleRect : null);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: PdfViewer.file(
          widget.path,
          controller: _ctl,
          params: PdfViewerParams(
            maxScale: 12,
            onViewerReady: (_, c) {
              final a = widget.initialArea;
              if (a != null) {
                c.goToArea(rect: a, anchor: PdfPageAnchor.all, duration: Duration.zero);
              }
            },
          ),
        ),
      ),
    );
  }
}

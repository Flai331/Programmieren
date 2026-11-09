import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdfrx/pdfrx.dart';

import '../app_services.dart';
import '../data/database.dart';
import '../fill/fill_export.dart';
import '../fill/fill_model.dart';
import '../scan/scan_service.dart';

enum _Tool { text, check, cross, date, signature }

/// Formular ausfüllen: Antippen setzt Text/Haken/Kreuz/Datum/Unterschrift,
/// Ziehen verschiebt, der Griff unten rechts ändert die Größe. Zwei Finger
/// zoomen. Gespeichert wird eine ausgefüllte Kopie – das Original bleibt.
class FillScreen extends StatefulWidget {
  final Document document;
  const FillScreen({super.key, required this.document});

  @override
  State<FillScreen> createState() => _FillScreenState();
}

class _FillScreenState extends State<FillScreen> {
  late FillDocument _fill;
  final _history = FillHistory();
  String? _path;
  int _page = 0;
  String? _selectedId;
  _Tool _tool = _Tool.text;
  int _color = kFillColors.first;
  SignatureTemplate? _pendingTemplate;
  List<SignatureTemplate> _templates = const [];
  final _templateBytes = <String, Uint8List>{};
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fill = FillDocument.decode(widget.document.fillData);
    ScanService.absolutePdfPath(widget.document.pdfPath).then((value) {
      if (mounted) setState(() => _path = value);
    });
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final list = await services.repository.allTemplates();
    // Auch Vorlagen laden, die schon im Formular stehen (evtl. gelöscht).
    final ids = {
      for (final t in list) t.id,
      for (final i in _fill.items)
        if (i.templateId != null) i.templateId!,
    };
    for (final id in ids) {
      final bytes = await services.templates.bytes(id);
      if (bytes != null) _templateBytes[id] = bytes;
    }
    if (mounted) setState(() => _templates = list);
  }

  FillItem? get _selected =>
      _fill.items.where((i) => i.id == _selectedId).firstOrNull;

  /// Vor jeder Änderung aufrufen (für „Rückgängig“).
  void _remember() {
    _history.remember(_fill);
    _dirty = true;
  }

  void _undo() {
    final previous = _history.undo();
    if (previous == null) return;
    setState(() {
      _fill = previous;
      _selectedId = null;
    });
  }

  // ------------------------------------------------------------- Aktionen

  Future<void> _tapPage(Offset pos, Size size) async {
    if (_selectedId != null) {
      setState(() => _selectedId = null);
      return;
    }
    final fx = pos.dx / size.width;
    final fy = pos.dy / size.height;
    FillItem? item;
    switch (_tool) {
      case _Tool.text:
        final text = await _editText('');
        if (text == null || text.trim().isEmpty) return;
        item = _textItem(text, fx, fy, size);
      case _Tool.date:
        item = _textItem(DateFormat('dd.MM.yyyy').format(DateTime.now()), fx,
            fy, size);
      case _Tool.check:
      case _Tool.cross:
        final kind = _tool == _Tool.check ? FillKind.check : FillKind.cross;
        final probe = FillItem(kind: kind, page: _page, x: 0, y: 0);
        final side = probe.size;
        item = FillItem(
          kind: kind,
          page: _page,
          x: (fx - side / 2).clamp(0, 1).toDouble(),
          y: (fy - side * size.width / size.height / 2).clamp(0, 1).toDouble(),
          color: _color,
        );
      case _Tool.signature:
        final template = _pendingTemplate ?? await _pickTemplate();
        if (template == null) return;
        final probe = FillItem(kind: FillKind.image, page: _page, x: 0, y: 0);
        final w = probe.size;
        final h = w * template.aspect * size.width / size.height;
        item = FillItem(
          kind: FillKind.image,
          page: _page,
          x: (fx - w / 2).clamp(0, 1).toDouble(),
          y: (fy - h / 2).clamp(0, 1).toDouble(),
          templateId: template.id,
          aspect: template.aspect,
        );
    }
    _remember();
    setState(() {
      _fill.items.add(item!);
      _selectedId = item.id;
    });
  }

  FillItem _textItem(String text, double fx, double fy, Size size) {
    final probe = FillItem(kind: FillKind.text, page: _page, x: 0, y: 0);
    // Text sitzt mit der Mitte der ersten Zeile auf dem Tipp.
    final lineHeight = probe.size * 1.3 * size.width / size.height;
    return FillItem(
      kind: FillKind.text,
      page: _page,
      x: fx.clamp(0, 1).toDouble(),
      y: (fy - lineHeight / 2).clamp(0, 1).toDouble(),
      text: text,
      color: _color,
    );
  }

  Future<String?> _editText(String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initial.isEmpty ? 'Text eintragen' : 'Text ändern'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            helperText: 'Mehrere Zeilen möglich',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<SignatureTemplate?> _pickTemplate() async {
    if (_templates.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Noch keine Unterschriften'),
          content: const Text(
            'Zeichne deine Unterschrift am PC im Scan-Trenner '
            '(„✍ Unterschrift zeichnen…“) und schicke sie per WLAN: '
            'PDF importieren → Vom PC (WLAN). Sie erscheint dann hier.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return null;
    }
    final picked = await showModalBottomSheet<SignatureTemplate>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          padding: const EdgeInsets.all(12),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2,
          children: [
            for (final t in _templates)
              InkWell(
                onTap: () => Navigator.pop(ctx, t),
                child: Card(
                  color: Colors.white,
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: _templateBytes[t.id] == null
                              ? const Icon(Icons.broken_image)
                              : Image.memory(_templateBytes[t.id]!),
                        ),
                      ),
                      Text(t.name,
                          style: const TextStyle(
                              color: Colors.black87, fontSize: 12)),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _pendingTemplate = picked);
    return picked;
  }

  Future<void> _tapItem(FillItem item) async {
    if (_selectedId != item.id) {
      setState(() => _selectedId = item.id);
      return;
    }
    if (item.kind == FillKind.text) {
      final text = await _editText(item.text);
      if (text == null) return;
      _remember();
      setState(() {
        if (text.trim().isEmpty) {
          _fill.items.removeWhere((i) => i.id == item.id);
          _selectedId = null;
        } else {
          item.text = text;
        }
      });
    }
  }

  void _setColor(int color) {
    final item = _selected;
    setState(() {
      _color = color;
      if (item != null && item.kind != FillKind.image && item.color != color) {
        _remember();
        item.color = color;
      }
    });
  }

  void _deleteSelected() {
    final id = _selectedId;
    if (id == null) return;
    _remember();
    setState(() {
      _fill.items.removeWhere((i) => i.id == id);
      _selectedId = null;
    });
  }

  void _duplicateSelected() {
    final item = _selected;
    if (item == null) return;
    _remember();
    final copy = FillItem.fromJson({
      ...item.toJson(),
      'id': null,
      'x': (item.x + 0.03).clamp(0, 1),
      'y': (item.y + 0.03).clamp(0, 1),
    })!;
    setState(() {
      _fill.items.add(copy);
      _selectedId = copy.id;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _selectedId = null;
    });
    try {
      await services.fill.save(widget.document, _fill);
      _dirty = false;
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Änderungen verwerfen?'),
        content: const Text('Die Eintragungen wurden noch nicht gespeichert.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Weiter ausfüllen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verwerfen'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ---------------------------------------------------------------- Aufbau

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          _dirty = false;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Ausfüllen · ${widget.document.docNumber}'),
          actions: [
            IconButton(
              tooltip: 'Rückgängig',
              icon: const Icon(Icons.undo),
              onPressed: _history.canUndo ? _undo : null,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Speichern'),
              ),
            ),
          ],
        ),
        body: _path == null
            ? const Center(child: CircularProgressIndicator())
            : PdfDocumentViewBuilder.file(
                _path!,
                builder: (context, pdf) {
                  if (pdf == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final pageCount = pdf.pages.length;
                  if (_page >= pageCount) _page = pageCount - 1;
                  final page = pdf.pages[_page];
                  return Column(
                    children: [
                      Expanded(child: _pageArea(pdf, page)),
                      _colorBar(),
                      _toolBar(),
                      if (pageCount > 1) _pageBar(pageCount),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _pageArea(PdfDocument pdf, PdfPage page) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: LayoutBuilder(builder: (context, c) {
        final ratio = page.height / page.width;
        var w = c.maxWidth - 16;
        var h = w * ratio;
        if (h > c.maxHeight - 16) {
          h = c.maxHeight - 16;
          w = h / ratio;
        }
        final size = Size(w, h);
        return Center(
          child: InteractiveViewer(
            maxScale: 6,
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: PdfPageView(
                      key: ValueKey('page-$_page'),
                      document: pdf,
                      pageNumber: _page + 1,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) => _tapPage(d.localPosition, size),
                    ),
                  ),
                  for (final item in _fill.onPage(_page))
                    _itemWidget(item, size),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _itemWidget(FillItem item, Size size) {
    final theme = Theme.of(context);
    final selected = item.id == _selectedId;
    final w = size.width;
    const handle = 26.0;

    Widget content;
    switch (item.kind) {
      case FillKind.text:
        content = Text(
          item.text,
          style: TextStyle(
            fontFamily: kFillFontFamily,
            fontSize: item.size * w,
            color: Color(item.color),
            height: 1.3,
          ),
          textHeightBehavior:
              const TextHeightBehavior(applyHeightToFirstAscent: false),
        );
      case FillKind.check:
      case FillKind.cross:
        final side = item.size * w;
        content = CustomPaint(
          size: Size.square(side),
          painter: _MarkPainter(item.kind, Color(item.color)),
        );
      case FillKind.image:
        final bytes = _templateBytes[item.templateId];
        final width = item.size * w;
        content = SizedBox(
          width: width,
          height: width * item.aspect,
          child: bytes == null
              ? const Icon(Icons.broken_image)
              : Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true),
        );
    }

    return Positioned(
      left: item.x * w,
      top: item.y * size.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _tapItem(item),
        onPanStart: (_) {
          _remember();
          setState(() => _selectedId = item.id);
        },
        onPanUpdate: (d) => setState(() {
          item.x = (item.x + d.delta.dx / w).clamp(0, 0.98).toDouble();
          item.y = (item.y + d.delta.dy / size.height).clamp(0, 0.98).toDouble();
        }),
        child: Padding(
          // Platz für den Größen-Griff unten rechts (muss innerhalb liegen,
          // sonst ist er nicht antippbar).
          padding: EdgeInsets.only(
            right: selected ? handle * 0.6 : 0,
            bottom: selected ? handle * 0.6 : 0,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                alignment: Alignment.topLeft,
                foregroundDecoration: selected
                    ? BoxDecoration(
                        border: Border.all(
                            color: theme.colorScheme.primary, width: 1.5),
                      )
                    : null,
                child: content,
              ),
              if (selected)
                Positioned(
                  right: -handle * 0.6,
                  bottom: -handle * 0.6,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) => _remember(),
                    onPanUpdate: (d) => setState(() {
                      final delta = (d.delta.dx + d.delta.dy) / 2 / w;
                      final factor = item.kind == FillKind.text ? 0.35 : 1.0;
                      item.size = clampSize(item.kind, item.size + delta * factor);
                    }),
                    child: Container(
                      width: handle,
                      height: handle,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.open_in_full,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorBar() {
    final selected = _selected;
    final theme = Theme.of(context);
    final active = selected?.kind == FillKind.image
        ? null
        : (selected?.color ?? _color);
    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
        child: Row(
          children: [
            for (final c in kFillColors)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _setColor(c),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active == c
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: active == c ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            if (selected != null) ...[
              if (selected.kind == FillKind.text)
                IconButton(
                  tooltip: 'Text ändern',
                  icon: const Icon(Icons.edit),
                  onPressed: () => _tapItem(selected),
                ),
              IconButton(
                tooltip: 'Kopieren',
                icon: const Icon(Icons.copy),
                onPressed: _duplicateSelected,
              ),
              IconButton(
                tooltip: 'Löschen',
                icon: const Icon(Icons.delete_outline),
                onPressed: _deleteSelected,
              ),
            ] else
              Text(
                'Auf die Seite tippen zum Einsetzen',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _toolBar() {
    Widget chip(_Tool tool, IconData icon, String label) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            avatar: Icon(icon, size: 18),
            label: Text(label),
            selected: _tool == tool,
            onSelected: (_) async {
              setState(() {
                _tool = tool;
                _selectedId = null;
              });
              if (tool == _Tool.signature) await _pickTemplate();
            },
          ),
        );
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Row(
          children: [
            chip(_Tool.text, Icons.text_fields, 'Text'),
            chip(_Tool.check, Icons.check, 'Haken'),
            chip(_Tool.cross, Icons.close, 'Kreuz'),
            chip(_Tool.date, Icons.today, 'Datum'),
            chip(_Tool.signature, Icons.draw,
                _pendingTemplate == null ? 'Unterschrift' : _pendingTemplate!.name),
          ],
        ),
      ),
    );
  }

  Widget _pageBar(int pageCount) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _page > 0
                  ? () => setState(() {
                        _page--;
                        _selectedId = null;
                      })
                  : null,
            ),
            Text('Seite ${_page + 1} von $pageCount'),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _page < pageCount - 1
                  ? () => setState(() {
                        _page++;
                        _selectedId = null;
                      })
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Zeichnet Haken/Kreuz genauso wie in der PDF (fill_export.dart).
class _MarkPainter extends CustomPainter {
  final FillKind kind;
  final Color color;
  _MarkPainter(this.kind, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.width;
    final paint = Paint()
      ..color = color
      ..strokeWidth = side * kMarkStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final paths = kind == FillKind.check ? [kCheckPath] : kCrossPaths;
    for (final pts in paths) {
      final path = Path()..moveTo(pts.first[0] * side, pts.first[1] * side);
      for (final pt in pts.skip(1)) {
        path.lineTo(pt[0] * side, pt[1] * side);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.kind != kind || old.color != color;
}

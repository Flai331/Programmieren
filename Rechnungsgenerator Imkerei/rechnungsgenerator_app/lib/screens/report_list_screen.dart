import 'package:flutter/material.dart';
import '../utils/app_utils.dart';
import '../utils/feedback_report.dart';
import '../utils/feedback_service.dart';

/// Abgelegte Fehlerberichte: ansehen, erneut teilen, kopieren, löschen.
///
/// Jeder Bericht bleibt hier, bis er von Hand gelöscht wird – auch wenn das
/// Teilen abgebrochen wurde oder keine passende App installiert ist.
class ReportListScreen extends StatefulWidget {
  const ReportListScreen({Key? key}) : super(key: key);

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  static const _peach = Color(0xFFfda085);
  static const _muted = Color(0xFF8a8a94);
  static const _green = Color(0xFF22c55e);

  late Future<List<FeedbackReport>> _future;

  @override
  void initState() {
    super.initState();
    FeedbackService.logScreenLoad('Fehlerberichte');
    _future = FeedbackService.storedReports();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = FeedbackService.storedReports();
    });
  }

  Future<void> _share(FeedbackReport r) async {
    await FeedbackService.shareReport(r);
    _reload();
  }

  Future<void> _copy(FeedbackReport r) async {
    final ok = await FeedbackService.copyReport(r);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '✓ In die Zwischenablage kopiert' : '✗ Kopieren fehlgeschlagen'),
    ));
    _reload();
  }

  Future<void> _mail(FeedbackReport r) async {
    final ok = await FeedbackService.mailReport(r);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'E-Mail an ${FeedbackService.supportEmail} vorbereitet'
          : 'Keine E-Mail-App gefunden – teilen oder kopieren'),
    ));
    _reload();
  }

  Future<void> _delete(FeedbackReport r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bericht löschen'),
        content: Text('„${r.title}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen',
                style: TextStyle(color: Color(0xFFff6b7a))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FeedbackService.deleteReport(r.id);
    _reload();
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alle Berichte löschen'),
        content: const Text(
            'Alle abgelegten Fehlerberichte werden entfernt. Das lässt sich '
            'nicht rückgängig machen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Alle löschen',
                style: TextStyle(color: Color(0xFFff6b7a))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FeedbackService.deleteAllReports();
    _reload();
  }

  void _showDetail(FeedbackReport r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(r.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20, color: _peach),
                    tooltip: 'Kopieren',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _copy(r);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.ios_share, size: 20, color: _peach),
                    tooltip: 'Teilen',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _share(r);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  r.asPlainText(),
                  style: const TextStyle(fontSize: 11, height: 1.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fehlerberichte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Alle löschen',
            onPressed: _deleteAll,
          ),
        ],
      ),
      body: FutureBuilder<List<FeedbackReport>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snap.data ?? const <FeedbackReport>[];
          if (reports.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bug_report_outlined, size: 64, color: _muted),
                    SizedBox(height: 16),
                    Text('Keine Fehlerberichte'),
                    SizedBox(height: 8),
                    Text(
                      'Gemeldete Fehler werden hier abgelegt und bleiben '
                      'erhalten, bis du sie löschst.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: reports.length,
              itemBuilder: (_, i) => _reportCard(reports[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _reportCard(FeedbackReport r) {
    final beschreibung = (r.note ?? '').trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showDetail(r),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    r.isAutoError
                        ? Icons.warning_amber_rounded
                        : Icons.bug_report_outlined,
                    size: 18,
                    color: r.isAutoError ? Colors.orange : _peach,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(r.title,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (r.exported)
                    const Icon(Icons.check_circle_outline,
                        size: 15, color: _green),
                ],
              ),
              if (beschreibung.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(beschreibung,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${AppUtils.formatDateTime(r.createdAt)} · '
                    'Build #${r.appVersion}'
                    '${r.hasPhotos ? " · ${r.photoNames.length} Bild(er)" : ""}',
                    style: const TextStyle(fontSize: 10, color: _muted),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _copy(r),
                    icon: const Icon(Icons.copy, size: 15),
                    label: const Text('Kopieren',
                        style: TextStyle(fontSize: 12)),
                  ),
                  TextButton.icon(
                    onPressed: () => _mail(r),
                    icon: const Icon(Icons.mail_outline, size: 15),
                    label: const Text('Mail', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton.icon(
                    onPressed: () => _share(r),
                    icon: const Icon(Icons.ios_share, size: 15),
                    label:
                        const Text('Teilen', style: TextStyle(fontSize: 12)),
                  ),
                  IconButton(
                    onPressed: () => _delete(r),
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Color(0xFFff6b7a)),
                    tooltip: 'Löschen',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

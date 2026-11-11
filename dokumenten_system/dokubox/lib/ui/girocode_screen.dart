import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../app_services.dart';
import '../data/database.dart';
import '../data/finance.dart';
import '../finance/girocode.dart';
import 'finance_actions.dart';

/// Überweisung per GiroCode: groß anzeigen (auf Tablet/Laptop mit der
/// Banking-App abscannen) oder als Bild an die Banking-App teilen.
Future<void> openGiroCode(BuildContext context, Document doc) async {
  final repo = services.repository;
  final firm = doc.correspondentId == null
      ? null
      : await repo.getCorrespondent(doc.correspondentId!);
  final refs = await repo.refsForDocument(doc.id);
  final iban = firm?.iban ?? refs['IBAN']?.firstOrNull ?? '';
  final reference = doc.paymentReference ??
      [
        for (final k in ['RGNR', 'KDNR', 'VSNR'])
          if (refs[k]?.isNotEmpty ?? false) '${k == 'RGNR' ? 'RG' : k == 'KDNR' ? 'Kd' : 'Vers'} ${refs[k]!.first}',
      ].join(' ');
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => GiroCodeScreen(
      doc: doc,
      name: firm?.name ?? '',
      iban: iban,
      bic: firm?.bic,
      reference: reference,
      correspondentId: firm?.id,
    ),
  ));
}

class GiroCodeScreen extends StatefulWidget {
  final Document doc;
  final String name, iban, reference;
  final String? bic, correspondentId;
  const GiroCodeScreen(
      {super.key,
      required this.doc,
      required this.name,
      required this.iban,
      required this.reference,
      this.bic,
      this.correspondentId});

  @override
  State<GiroCodeScreen> createState() => _GiroCodeScreenState();
}

class _GiroCodeScreenState extends State<GiroCodeScreen> {
  late final _name = TextEditingController(text: widget.name);
  late final _iban = TextEditingController(text: widget.iban);
  late final _amount = TextEditingController(
      text: widget.doc.amountCents == null
          ? ''
          : formatEuro(widget.doc.amountCents!).replaceAll(RegExp(r'\s?€'), ''));
  late final _ref = TextEditingController(text: widget.reference);
  final _qrKey = GlobalKey();

  String? _code;
  String? _error;

  @override
  void initState() {
    super.initState();
    _build();
  }

  void _build() {
    try {
      _code = buildGiroCode(
        name: _name.text,
        iban: _iban.text,
        bic: widget.bic,
        amountCents: parseEuro(_amount.text),
        reference: _ref.text,
      );
      _error = null;
    } on FormatException catch (e) {
      _code = null;
      _error = e.message;
    }
    setState(() {});
  }

  Future<void> _shareImage() async {
    final code = _code;
    if (code == null) return;
    final painter = QrPainter(
      data: code,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      eyeStyle: const QrEyeStyle(color: Colors.black),
      dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
    );
    final data = await painter.toImageData(900, format: ui.ImageByteFormat.png);
    if (data == null) return;
    // Weißer Rand, damit Banking-Apps ihn im Bild erkennen.
    final file = File(p.join((await getTemporaryDirectory()).path,
        'GiroCode ${widget.doc.docNumber}.png'));
    await file.writeAsBytes(data.buffer.asUint8List());
    await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        subject: 'Überweisung ${widget.doc.docNumber}'));
  }

  Future<void> _saveIban() async {
    final id = widget.correspondentId;
    if (id == null) return;
    await services.repository.setCorrespondentBank(id,
        iban: _iban.text.replaceAll(' ', '').toUpperCase());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('IBAN bei der Firma gespeichert')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Überweisen (GiroCode)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: _code == null
                  ? SizedBox(
                      width: 260,
                      height: 260,
                      child: Center(
                          child: Text(_error ?? '',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: theme.colorScheme.error))))
                  : QrImageView(
                      key: _qrKey,
                      data: _code!,
                      size: 260,
                      backgroundColor: Colors.white,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mit der Banking-App scannen (z. B. vom Tablet/Laptop-Bildschirm) '
            'oder als Bild teilen – manche Banking-Apps lesen GiroCodes aus '
            'Bildern.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          for (final (c, label) in [
            (_name, 'Empfänger'),
            (_iban, 'IBAN'),
            (_amount, 'Betrag (€)'),
            (_ref, 'Verwendungszweck'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: c,
                decoration: InputDecoration(
                    labelText: label, border: const OutlineInputBorder()),
                onChanged: (_) => _build(),
              ),
            ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: _code == null ? null : _shareImage,
              icon: const Icon(Icons.share),
              label: const Text('Als Bild teilen'),
            ),
            if (widget.correspondentId != null)
              OutlinedButton.icon(
                onPressed: _code == null ? null : _saveIban,
                icon: const Icon(Icons.save),
                label: const Text('IBAN merken'),
              ),
            if (widget.doc.paymentStatus == PaymentStatus.open)
              OutlinedButton.icon(
                onPressed: () async {
                  await markPaid(context, widget.doc);
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.check),
                label: const Text('Bezahlt'),
              ),
          ]),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/pdf_letter_service.dart';
import '../utils/app_utils.dart';

class LetterEditScreen extends StatefulWidget {
  final String? letterId;
  const LetterEditScreen({Key? key, this.letterId}) : super(key: key);

  @override
  State<LetterEditScreen> createState() => _LetterEditScreenState();
}

class _LetterEditScreenState extends State<LetterEditScreen> {
  final _db = DatabaseService();
  static const _peach = Color(0xFFfda085);

  // Form-Controller
  final _zusatz = TextEditingController();
  final _recipientName = TextEditingController();
  final _recipientStreet = TextEditingController();
  final _recipientCity = TextEditingController();
  final _recipientCountry = TextEditingController();
  final _location = TextEditingController();
  final _refYour = TextEditingController();
  final _refYourDate = TextEditingController();
  final _refOur = TextEditingController();
  final _refOurDate = TextEditingController();
  final _subject = TextEditingController();
  final _salutation = TextEditingController();
  final _body = TextEditingController();
  final _closing = TextEditingController();
  final _signer = TextEditingController();

  String _form = 'B';
  String _envelope = 'DL';
  DateTime _date = DateTime.now();
  bool _showFold = true;
  bool _showPunch = true;
  bool _loading = true;
  bool _isSaving = false;

  LetterModel? _current;
  CompanyModel? _company;

  static const _salutations = [
    'Sehr geehrte Damen und Herren,',
    'Sehr geehrter Herr ',
    'Sehr geehrte Frau ',
    'Liebe ',
  ];
  static const _closings = [
    'Mit freundlichen Grüßen',
    'Freundliche Grüße',
    'Hochachtungsvoll',
    'Viele Grüße',
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final companies = await _db.getAllCompanies();
      _company = companies.isNotEmpty ? companies.first : null;

      if (widget.letterId != null) {
        _current = await _db.getLetter(widget.letterId!);
        if (_current != null) _populate(_current!);
      } else {
        _location.text = _company?.city ?? '';
        _signer.text = _company?.name ?? '';
        _closing.text = _closings.first;
      }
    } catch (e) {
      _snack('Fehler beim Laden: $e', err: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _populate(LetterModel l) {
    _form = l.letterForm;
    _envelope = l.envelopeFormat;
    _date = l.letterDate ?? DateTime.now();
    _location.text = l.location ?? '';
    _zusatz.text = l.recipientZusatz ?? '';
    _recipientName.text = l.recipientName ?? '';
    _recipientStreet.text = l.recipientStreet ?? '';
    _recipientCity.text = l.recipientCity ?? '';
    _recipientCountry.text = l.recipientCountry ?? '';
    _refYour.text = l.refYour ?? '';
    _refYourDate.text = l.refYourDate ?? '';
    _refOur.text = l.refOur ?? '';
    _refOurDate.text = l.refOurDate ?? '';
    _subject.text = l.subject ?? '';
    _salutation.text = l.salutation ?? '';
    _body.text = l.body ?? '';
    _closing.text = l.closing ?? '';
    _signer.text = l.signerName ?? '';
    _showFold = l.showFoldMarks;
    _showPunch = l.showPunchMark;
  }

  LetterModel _buildModel() {
    return LetterModel(
      id: _current?.id ?? const Uuid().v4(),
      companyId: _company?.id,
      customerId: _current?.customerId,
      letterForm: _form,
      envelopeFormat: _envelope,
      letterDate: _date,
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      refYour: _nullable(_refYour.text),
      refYourDate: _nullable(_refYourDate.text),
      refOur: _nullable(_refOur.text),
      refOurDate: _nullable(_refOurDate.text),
      subject: _nullable(_subject.text),
      salutation: _nullable(_salutation.text),
      body: _nullable(_body.text),
      closing: _nullable(_closing.text),
      signerName: _nullable(_signer.text),
      recipientZusatz: _nullable(_zusatz.text),
      recipientName: _nullable(_recipientName.text),
      recipientStreet: _nullable(_recipientStreet.text),
      recipientCity: _nullable(_recipientCity.text),
      recipientCountry: _nullable(_recipientCountry.text),
      showFoldMarks: _showFold,
      showPunchMark: _showPunch,
      status: _current?.status ?? 'draft',
      createdAt: _current?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  String? _nullable(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _save() async {
    if (_recipientName.text.trim().isEmpty) {
      _snack('Empfänger-Name erforderlich', err: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final l = _buildModel();
      if (_current == null) {
        await _db.insertLetter(l);
      } else {
        await _db.updateLetter(l);
      }
      _current = l;
      if (mounted) {
        _snack('✓ Brief gespeichert');
        Navigator.of(context).pop();
      }
    } catch (e) {
      _snack('Fehler: $e', err: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sharePdf() async {
    try {
      final letter = _buildModel();
      final pdf = await PdfLetterService()
          .generateLetterPdf(letter: letter, company: _company);
      final bytes = await pdf.save();
      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/Brief_'
          '${AppUtils.formatDate(letter.letterDate ?? DateTime.now()).replaceAll('.', '-')}.pdf');
      await file.writeAsBytes(bytes);
      final subjectText = (letter.subject != null && letter.subject!.trim().isNotEmpty)
          ? letter.subject!
          : AppUtils.formatDate(letter.letterDate ?? DateTime.now());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Brief: $subjectText',
        text: 'Moin,\n\nanbei mein Brief.',
      );
      if (_current != null) {
        await _db.updateLetterStatus(_current!.id, 'sent');
      }
    } catch (e) {
      _snack('PDF-Fehler: $e', err: true);
    }
  }

  Future<void> _pickRecipient() async {
    final customers = await _db.getAllCustomers();
    if (!mounted) return;
    final picked = await showDialog<CustomerModel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Empfänger wählen'),
        children: customers
            .map((c) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, c),
                  child: Text('${c.name} · ${c.zipcode} ${c.city}'),
                ))
            .toList(),
      ),
    );
    if (picked != null) {
      setState(() {
        _recipientName.text = picked.name;
        _recipientStreet.text = picked.street;
        _recipientCity.text = '${picked.zipcode} ${picked.city}';
      });
    }
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: err ? Colors.red : null),
    );
  }

  InputDecoration _deco(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Brief')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_current == null ? 'Neuer Brief' : 'Brief bearbeiten'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'PDF / Senden',
            onPressed: _sharePdf,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Form + Umschlag
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _form,
                decoration: _deco('Briefform'),
                items: const [
                  DropdownMenuItem(value: 'B', child: Text('Form B (Standard)')),
                  DropdownMenuItem(value: 'A', child: Text('Form A (Behörden)')),
                ],
                onChanged: (v) => setState(() => _form = v ?? 'B'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _envelope,
                decoration: _deco('Umschlag'),
                items: const [
                  DropdownMenuItem(value: 'DL', child: Text('DIN Lang')),
                  DropdownMenuItem(value: 'C6', child: Text('C6')),
                  DropdownMenuItem(value: 'C5', child: Text('C5')),
                  DropdownMenuItem(value: 'C4', child: Text('C4')),
                  DropdownMenuItem(value: 'B6', child: Text('B6')),
                  DropdownMenuItem(value: 'B5', child: Text('B5')),
                ],
                onChanged: (v) => setState(() => _envelope = v ?? 'DL'),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Empfänger
          _section('Empfänger'),
          OutlinedButton.icon(
            onPressed: _pickRecipient,
            icon: const Icon(Icons.contacts_outlined, color: _peach),
            label: const Text('Aus Adressbuch',
                style: TextStyle(color: _peach)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _peach)),
          ),
          const SizedBox(height: 8),
          TextField(controller: _zusatz, decoration: _deco('Zusatz (z.B. Firma, z.Hd.)')),
          const SizedBox(height: 8),
          TextField(controller: _recipientName, decoration: _deco('Name *')),
          const SizedBox(height: 8),
          TextField(controller: _recipientStreet, decoration: _deco('Straße & Hausnummer')),
          const SizedBox(height: 8),
          TextField(controller: _recipientCity, decoration: _deco('PLZ Ort')),
          const SizedBox(height: 8),
          TextField(controller: _recipientCountry, decoration: _deco('Land (optional)')),
          const SizedBox(height: 16),

          // Briefkopf
          _section('Briefkopf'),
          Row(children: [
            Expanded(
              child: TextField(controller: _location, decoration: _deco('Ort')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: InputDecorator(
                  decoration: _deco('Datum'),
                  child: Text(AppUtils.formatDate(_date)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _refYour, decoration: _deco('Ihr Zeichen'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _refYourDate, decoration: _deco('Ihre Nachricht vom'))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _refOur, decoration: _deco('Unser Zeichen'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _refOurDate, decoration: _deco('Unsere Nachricht vom'))),
          ]),
          const SizedBox(height: 8),
          TextField(controller: _subject, decoration: _deco('Betreff')),
          const SizedBox(height: 16),

          // Inhalt
          _section('Briefinhalt'),
          DropdownButtonFormField<String>(
            value: _salutations.contains(_salutation.text)
                ? _salutation.text
                : null,
            decoration: _deco('Anrede (Vorlage)'),
            items: _salutations
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _salutation.text = v ?? ''),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _salutation,
            decoration: _deco('Anrede (anpassbar)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _body,
            decoration: _deco('Brieftext'),
            maxLines: 10,
            minLines: 6,
          ),
          const SizedBox(height: 16),

          // Abschluss
          _section('Abschluss'),
          DropdownButtonFormField<String>(
            value: _closings.contains(_closing.text) ? _closing.text : null,
            decoration: _deco('Grußformel (Vorlage)'),
            items: _closings
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _closing.text = v ?? ''),
          ),
          const SizedBox(height: 8),
          TextField(controller: _closing, decoration: _deco('Grußformel')),
          const SizedBox(height: 8),
          TextField(controller: _signer, decoration: _deco('Unterschrift (Name)')),
          const SizedBox(height: 16),

          // Anzeige
          _section('Anzeige (Druck-Markierungen)'),
          SwitchListTile(
            value: _showFold,
            onChanged: (v) => setState(() => _showFold = v),
            title: const Text('Faltmarken'),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: _showPunch,
            onChanged: (v) => setState(() => _showPunch = v),
            title: const Text('Lochmarke'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Speichern'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _peach,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _sharePdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, color: _peach),
            label: const Text('PDF & Senden',
                style: TextStyle(color: _peach)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _peach),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t,
            style: const TextStyle(
                color: _peach,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      );

  @override
  void dispose() {
    _zusatz.dispose();
    _recipientName.dispose();
    _recipientStreet.dispose();
    _recipientCity.dispose();
    _recipientCountry.dispose();
    _location.dispose();
    _refYour.dispose();
    _refYourDate.dispose();
    _refOur.dispose();
    _refOurDate.dispose();
    _subject.dispose();
    _salutation.dispose();
    _body.dispose();
    _closing.dispose();
    _signer.dispose();
    super.dispose();
  }
}

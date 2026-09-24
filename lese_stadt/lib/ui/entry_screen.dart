import 'package:flutter/material.dart';

import '../data/db.dart';
import 'book_screens.dart';
import 'common.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key, this.bookId});
  final int? bookId;

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  int? _bookId;
  final _seite = TextEditingController();
  DateTime? _datum;
  bool _beenden = false;
  bool _beendenGeaendert = false;
  String? _fehler;

  @override
  void initState() {
    super.initState();
    _bookId = widget.bookId;
  }

  @override
  void dispose() {
    _seite.dispose();
    super.dispose();
  }

  void _seiteGeaendert(Book? book) {
    final n = int.tryParse(_seite.text);
    setState(() {
      _fehler = null;
      if (!_beendenGeaendert && book != null && n != null) {
        _beenden = n >= book.seitenGesamt;
      }
    });
  }

  Future<void> _speichern(Book book) async {
    final store = StoreScope.read(context);
    final n = int.tryParse(_seite.text);
    final von = store.currentPage(book);
    if (n == null || n <= von) {
      setState(() => _fehler = 'Bitte eine Seite größer als $von eingeben.');
      return;
    }
    final gained = await store.addEntry(
      book,
      n,
      datum: _datum,
      beenden: _beenden,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_beenden ? 'Buch beendet!' : '${n - von} Seiten gelesen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Du bekommst:'),
            const SizedBox(height: 8),
            MaterialsWrap(gained),
            if (_beenden) ...[
              const SizedBox(height: 12),
              Text(
                book.seriesId == null
                    ? 'Das Buch-Denkmal steht jetzt in deiner Stadt.'
                    : 'Der Band hat sein Gebäude im Reihen-Viertel bekommen.',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Super'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final auswahl = [
      ...store.books.where((b) => b.status == BookStatus.lesend),
      ...store.books.where((b) => b.status == BookStatus.wunsch),
    ];
    _bookId ??= store.aktuellesBuch?.id ?? auswahl.firstOrNull?.id;
    final book = store.booksById[_bookId];
    final von = book == null ? 0 : store.currentPage(book);

    return Scaffold(
      appBar: AppBar(title: const Text('Lesen eintragen')),
      body: auswahl.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Du hast gerade kein Buch am Lesen.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Buch hinzufügen'),
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddBookScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<int>(
                  initialValue: book?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Buch',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final b in auswahl)
                      DropdownMenuItem(
                        value: b.id,
                        child: Text(
                          '${b.titel}${b.status == BookStatus.wunsch ? ' (Wunschliste)' : ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) => setState(() {
                    _bookId = id;
                    _beendenGeaendert = false;
                    _seiteGeaendert(store.booksById[id]);
                  }),
                ),
                const SizedBox(height: 16),
                if (book != null) ...[
                  Text('Bisher bis Seite $von von ${book.seitenGesamt}.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _seite,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Jetzt auf Seite',
                      border: const OutlineInputBorder(),
                      errorText: _fehler,
                    ),
                    onChanged: (_) => _seiteGeaendert(book),
                    onSubmitted: (_) => _speichern(book),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _beenden,
                    title: const Text('Buch beendet'),
                    onChanged: (v) => setState(() {
                      _beenden = v ?? false;
                      _beendenGeaendert = true;
                    }),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: Text(
                      _datum == null ? 'Heute' : datumFormat.format(_datum!),
                    ),
                    trailing: const Text('Ändern'),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _datum ?? store.now,
                        firstDate: DateTime(2000),
                        lastDate: store.now,
                      );
                      if (d != null) {
                        setState(
                          () => _datum = DateTime(d.year, d.month, d.day, 12),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Eintragen'),
                    onPressed: () => _speichern(book),
                  ),
                ],
              ],
            ),
    );
  }
}

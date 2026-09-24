import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../data/db.dart';
import '../logic/economy.dart';
import '../logic/series.dart';
import '../model/genre.dart';
import '../services/book_lookup.dart';
import 'common.dart';
import 'entry_screen.dart';
import 'scan_screen.dart';

// ================================================================ Regal

enum _Regalfach { lesend, wunsch, beendet, reihen }

class ShelfScreen extends StatefulWidget {
  const ShelfScreen({super.key});

  @override
  State<ShelfScreen> createState() => _ShelfScreenState();
}

class _ShelfScreenState extends State<ShelfScreen> {
  _Regalfach _fach = _Regalfach.lesend;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    List<Book> mit(BookStatus s) =>
        store.books.where((b) => b.status == s).toList();
    final beendet = mit(BookStatus.beendet)
      ..sort(
        (a, b) => (b.beendetAm ?? b.hinzugefuegtAm).compareTo(
          a.beendetAm ?? a.hinzugefuegtAm,
        ),
      );

    return Scaffold(
      appBar: AppBar(title: const Text('Bücherregal')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        icon: const Icon(Icons.add),
        label: const Text('Buch'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddBookScreen()),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SegmentedButton<_Regalfach>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _Regalfach.lesend,
                  label: Text('Lese ich'),
                ),
                ButtonSegment(value: _Regalfach.wunsch, label: Text('Wünsche')),
                ButtonSegment(value: _Regalfach.beendet, label: Text('Fertig')),
                ButtonSegment(value: _Regalfach.reihen, label: Text('Reihen')),
              ],
              selected: {_fach},
              onSelectionChanged: (s) => setState(() => _fach = s.first),
            ),
          ),
          Expanded(
            child: switch (_fach) {
              _Regalfach.lesend => _BookList(
                mit(BookStatus.lesend),
                leer: 'Gerade liest du nichts. Füg ein Buch hinzu oder starte eins von der Wunschliste.',
              ),
              _Regalfach.wunsch => _BookList(
                mit(BookStatus.wunsch),
                leer: 'Die Wunschliste ist leer. Jedes Buch darauf steht als Bauplan in deiner Stadt.',
              ),
              _Regalfach.beendet => _BookList(
                beendet,
                leer: 'Noch kein Buch beendet.',
              ),
              _Regalfach.reihen => const _SeriesList(),
            },
          ),
        ],
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  const _BookList(this.books, {required this.leer});
  final List<Book> books;
  final String leer;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(leer, textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: books.length,
      itemBuilder: (context, i) => BookTile(books[i]),
    );
  }
}

class BookTile extends StatelessWidget {
  const BookTile(this.book, {super.key, this.band});
  final Book book;
  final int? band;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final reihe = book.seriesId == null
        ? null
        : store.seriesById[book.seriesId];
    final seite = store.currentPage(book);
    final sub = [
      if (book.autor.isNotEmpty) book.autor,
      if (reihe != null)
        '${reihe.name}${book.seriesIndex == null ? '' : ' #${book.seriesIndex}'}',
      if (book.status == BookStatus.lesend) 'S. $seite/${book.seitenGesamt}',
      if (book.status == BookStatus.beendet && book.beendetAm != null)
        datumFormat.format(book.beendetAm!),
    ].join(' · ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: book.genres.isEmpty
            ? Colors.brown.shade200
            : book.genres.first.material.color,
        child: band != null
            ? Text('$band')
            : Icon(statusIcon(book.status), color: Colors.black87, size: 20),
      ),
      title: Text(book.titel, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (book.status == BookStatus.lesend && book.seitenGesamt > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(
                value: (seite / book.seitenGesamt).clamp(0, 1),
              ),
            ),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)),
      ),
    );
  }
}

class _SeriesList extends StatelessWidget {
  const _SeriesList();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.series.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Noch keine Reihe. Gib beim Hinzufügen eines Buchs die Reihe und Bandnummer an, dann bekommt sie ihr eigenes Viertel.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final districts = {for (final d in store.districts) d.series.id: d};
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final s in [
          ...store.series,
        ]..sort((a, b) => a.name.compareTo(b.name)))
          Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              children: [
                ListTile(
                  title: Text(s.name),
                  subtitle: Text(
                    [
                      '${districts[s.id]?.fertigeBaende ?? 0} von ${districts[s.id]?.baende ?? 0} Bänden',
                      if (districts[s.id]?.genre != null)
                        districts[s.id]!.stilName,
                      s.abgeschlossen ? 'alle Bände erschienen' : 'läuft noch',
                      if (districts[s.id]?.komplett ?? false) 'komplett!',
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Reihe bearbeiten',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => SeriesDialog(series: s),
                    ),
                  ),
                ),
                for (final entry in (assignVolumes(
                  store.books.where((b) => b.seriesId == s.id).toList(),
                  s.baendeGesamt,
                ).entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
                  BookTile(entry.value, band: entry.key),
              ],
            ),
          ),
      ],
    );
  }
}

class SeriesDialog extends StatefulWidget {
  const SeriesDialog({super.key, required this.series});
  final Series series;

  @override
  State<SeriesDialog> createState() => _SeriesDialogState();
}

class _SeriesDialogState extends State<SeriesDialog> {
  late final _name = TextEditingController(text: widget.series.name);
  late final _baende = TextEditingController(
    text: widget.series.baendeGesamt?.toString() ?? '',
  );
  late bool _abgeschlossen = widget.series.abgeschlossen;

  @override
  void dispose() {
    _name.dispose();
    _baende.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reihe'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: _baende,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Bände insgesamt',
              helperText: 'Für jeden Band gibt es einen Bauplatz.',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _abgeschlossen,
            title: const Text('Alle Bände erschienen'),
            subtitle: const Text(
              'Sonst gibt es einen Bauplatz mit Gerüst für den nächsten Band.',
            ),
            onChanged: (v) => setState(() => _abgeschlossen = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () async {
            final store = StoreScope.read(context);
            final baende = int.tryParse(_baende.text);
            await store.updateSeries(
              widget.series.copyWith(
                name: _name.text.trim().isEmpty
                    ? widget.series.name
                    : _name.text.trim(),
                baendeGesamt: Value(
                  baende != null && baende > 0 ? baende : null,
                ),
                abgeschlossen: _abgeschlossen,
              ),
            );
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

// ================================================================ Detail

class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key, required this.bookId});
  final int bookId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final book = store.booksById[bookId];
    if (book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Buch gelöscht.')),
      );
    }
    final theme = Theme.of(context);
    final reihe = book.seriesId == null
        ? null
        : store.seriesById[book.seriesId];
    final gelesen = store.pagesRead(book);
    final eintraege = store.entriesOf(book);

    return Scaffold(
      appBar: AppBar(
        title: Text(book.titel, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Bearbeiten',
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddBookScreen(book: book)),
            ),
          ),
          IconButton(
            tooltip: 'Löschen',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Buch löschen?'),
                  content: const Text(
                    'Einträge und das Denkmal verschwinden, das Material dafür auch.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Abbrechen'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Löschen'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                Navigator.pop(context);
                await store.deleteBook(book);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(book.titel, style: theme.textTheme.headlineSmall),
          if (book.autor.isNotEmpty)
            Text(book.autor, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Chip(
                avatar: Icon(statusIcon(book.status), size: 18),
                label: Text(book.status.label),
              ),
              for (final g in book.genres)
                Chip(
                  avatar: CircleAvatar(
                    backgroundColor: g.material.color,
                    radius: 7,
                  ),
                  label: Text(g.label),
                ),
              if (reihe != null)
                Chip(
                  avatar: const Icon(Icons.holiday_village, size: 18),
                  label: Text(
                    '${reihe.name}${book.seriesIndex == null ? '' : ', Band ${book.seriesIndex}'}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Seite ${store.currentPage(book)} von ${book.seitenGesamt}'
            ' · $gelesen Seiten eingetragen',
          ),
          if (book.beendetAm != null)
            Text('Beendet am ${datumFormat.format(book.beendetAm!)}'),
          if (book.isbn != null) Text('ISBN ${book.isbn}'),
          const SizedBox(height: 8),
          Text('Material bisher:', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          MaterialsWrap(materialsForPages(gelesen, book.genres)),
          if (book.notiz?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Text(
              '„${book.notiz}“',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (book.status != BookStatus.beendet)
                FilledButton.icon(
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Lesen eintragen'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EntryScreen(bookId: book.id),
                    ),
                  ),
                ),
              if (book.status != BookStatus.beendet)
                OutlinedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Beendet'),
                  onPressed: () => store.setStatus(book, BookStatus.beendet),
                ),
              if (book.status == BookStatus.beendet)
                OutlinedButton.icon(
                  icon: const Icon(Icons.undo),
                  label: const Text('Doch nicht beendet'),
                  onPressed: () => store.setStatus(book, BookStatus.lesend),
                ),
              if (book.status == BookStatus.lesend && eintraege.isEmpty)
                OutlinedButton.icon(
                  icon: const Icon(Icons.bookmark_border),
                  label: const Text('Auf die Wunschliste'),
                  onPressed: () => store.setStatus(book, BookStatus.wunsch),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Einträge', style: theme.textTheme.titleMedium),
          if (eintraege.isEmpty) const Text('Noch keine.'),
          for (final e in eintraege)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Seite ${e.vonSeite} → ${e.bisSeite} (${pagesOf(e)} Seiten)',
              ),
              subtitle: Text(datumFormat.format(e.datum)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Eintrag löschen',
                onPressed: () => store.deleteEntry(e),
              ),
            ),
        ],
      ),
    );
  }
}

// ================================================================ Formular

/// Buch hinzufügen oder bearbeiten ([book] gesetzt).
class AddBookScreen extends StatefulWidget {
  const AddBookScreen({super.key, this.book});
  final Book? book;

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  final _lookup = BookLookup();
  late final _isbn = TextEditingController(text: widget.book?.isbn ?? '');
  late final _titel = TextEditingController(text: widget.book?.titel ?? '');
  late final _autor = TextEditingController(text: widget.book?.autor ?? '');
  late final _seiten = TextEditingController(
    text: widget.book?.seitenGesamt.toString() ?? '',
  );
  late final _band = TextEditingController(
    text: widget.book?.seriesIndex?.toString() ?? '',
  );
  late final _notiz = TextEditingController(text: widget.book?.notiz ?? '');
  final _aktuell = TextEditingController();
  TextEditingController? _reihe;
  String _reiheStart = '';
  late List<Genre> _genres = widget.book?.genres ?? [];
  late BookStatus _status = widget.book?.status ?? BookStatus.wunsch;
  bool _seitenZaehlen = true;
  bool _laedt = false;
  String? _hinweis;

  bool get _neu => widget.book == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = widget.book?.seriesId;
    if (id != null && _reiheStart.isEmpty) {
      _reiheStart = StoreScope.read(context).seriesById[id]?.name ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [_isbn, _titel, _autor, _seiten, _band, _notiz, _aktuell]) {
      c.dispose();
    }
    super.dispose();
  }

  void _uebernehmen(BookInfo info) {
    setState(() {
      if (info.isbn != null) _isbn.text = info.isbn!;
      if (info.titel.isNotEmpty) _titel.text = info.titel;
      if (info.autor.isNotEmpty) _autor.text = info.autor;
      if (info.seiten != null) _seiten.text = '${info.seiten}';
      if (info.genres.isNotEmpty) _genres = info.genres;
      if (info.reihe != null) _reihe?.text = info.reihe!;
      if (info.band != null) _band.text = '${info.band}';
      _hinweis = [
        'Gefunden. Bitte kurz prüfen.',
        if (info.genres.isEmpty) 'Genre konnte nicht erkannt werden.',
        if (info.seiten == null) 'Seitenzahl fehlt.',
        if (info.reihe == null && info.band != null)
          'Band ${info.band} einer Reihe – bitte den Reihennamen ergänzen.',
      ].join(' ');
    });
  }

  Future<void> _isbnSuchen() async {
    final isbn = normalizeIsbn(_isbn.text);
    if (!isValidIsbn(isbn)) {
      setState(() => _hinweis = 'Das ist keine gültige ISBN.');
      return;
    }
    setState(() {
      _laedt = true;
      _hinweis = null;
    });
    final info = await _lookup.byIsbn(isbn);
    if (!mounted) return;
    setState(() => _laedt = false);
    if (info == null) {
      setState(
        () => _hinweis = 'Nichts gefunden (oder keine Verbindung). Du kannst das Buch von Hand eintragen.',
      );
    } else {
      _uebernehmen(info);
    }
  }

  Future<void> _scannen() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (code == null || !mounted) return;
    _isbn.text = code;
    await _isbnSuchen();
  }

  Future<void> _titelSuchen() async {
    final info = await showDialog<BookInfo>(
      context: context,
      builder: (_) => _SearchDialog(lookup: _lookup, start: _titel.text),
    );
    if (info != null) _uebernehmen(info);
  }

  Future<void> _speichern() async {
    final store = StoreScope.read(context);
    final seiten = int.tryParse(_seiten.text);
    if (_titel.text.trim().isEmpty || seiten == null || seiten <= 0) {
      setState(() => _hinweis = 'Titel und Seitenzahl werden gebraucht.');
      return;
    }
    final reihe = _reihe?.text.trim() ?? '';
    final band = int.tryParse(_band.text);
    final notiz = _notiz.text.trim().isEmpty ? null : _notiz.text.trim();
    final isbn = _isbn.text.trim().isEmpty ? null : normalizeIsbn(_isbn.text);
    if (_neu) {
      final aktuell = int.tryParse(_aktuell.text) ?? 0;
      await store.addBook(
        isbn: isbn,
        titel: _titel.text,
        autor: _autor.text,
        seitenGesamt: seiten,
        genres: _genres,
        status: _status,
        reihe: reihe,
        band: band,
        notiz: notiz,
        gelesenBis: switch (_status) {
          BookStatus.beendet => _seitenZaehlen ? seiten : 0,
          BookStatus.lesend => aktuell.clamp(0, seiten),
          BookStatus.wunsch => 0,
        },
      );
    } else {
      await store.updateBook(
        widget.book!.copyWith(
          isbn: Value(isbn),
          titel: _titel.text.trim(),
          autor: _autor.text.trim(),
          seitenGesamt: seiten,
          genres: _genres,
          status: _status,
          seriesIndex: Value(band),
          notiz: Value(notiz),
        ),
        reihe: reihe,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(title: Text(_neu ? 'Buch hinzufügen' : 'Buch bearbeiten')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _isbn,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'ISBN',
              border: const OutlineInputBorder(),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Barcode scannen',
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scannen,
                  ),
                  IconButton(
                    tooltip: 'Per ISBN suchen',
                    icon: const Icon(Icons.search),
                    onPressed: _laedt ? null : _isbnSuchen,
                  ),
                ],
              ),
            ),
            onSubmitted: (_) => _isbnSuchen(),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.manage_search),
              label: const Text('Ohne ISBN: nach Titel suchen'),
              onPressed: _titelSuchen,
            ),
          ),
          if (_laedt) const LinearProgressIndicator(),
          if (_hinweis != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_hinweis!),
            ),
          gap,
          TextField(
            controller: _titel,
            decoration: const InputDecoration(
              labelText: 'Titel',
              border: OutlineInputBorder(),
            ),
          ),
          gap,
          TextField(
            controller: _autor,
            decoration: const InputDecoration(
              labelText: 'Autor',
              border: OutlineInputBorder(),
            ),
          ),
          gap,
          TextField(
            controller: _seiten,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Seiten gesamt',
              border: OutlineInputBorder(),
            ),
          ),
          gap,
          const Text(
            'Genre (mehrere möglich, das Material wird dann aufgeteilt)',
          ),
          const SizedBox(height: 6),
          GenreChips(
            selected: _genres,
            onChanged: (g) => setState(() => _genres = g),
          ),
          gap,
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Autocomplete<String>(
                  initialValue: TextEditingValue(text: _reiheStart),
                  optionsBuilder: (v) => store.series
                      .map((s) => s.name)
                      .where(
                        (n) => n.toLowerCase().contains(v.text.toLowerCase()),
                      ),
                  fieldViewBuilder: (context, controller, focus, onSubmit) {
                    _reihe = controller;
                    return TextField(
                      controller: controller,
                      focusNode: focus,
                      decoration: const InputDecoration(
                        labelText: 'Reihe (optional)',
                        border: OutlineInputBorder(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _band,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Band',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          gap,
          SegmentedButton<BookStatus>(
            segments: [
              for (final s in BookStatus.values)
                ButtonSegment(
                  value: s,
                  label: Text(s.label),
                  icon: Icon(statusIcon(s)),
                ),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
          if (_neu && _status == BookStatus.lesend) ...[
            gap,
            TextField(
              controller: _aktuell,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Bin schon auf Seite (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (_neu && _status == BookStatus.beendet)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _seitenZaehlen,
              title: const Text('Seiten als heute gelesen eintragen'),
              subtitle: const Text('Dann gibt es auch das Material dafür.'),
              onChanged: (v) => setState(() => _seitenZaehlen = v ?? false),
            ),
          gap,
          TextField(
            controller: _notiz,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notiz (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Speichern'),
            onPressed: _speichern,
          ),
        ],
      ),
    );
  }
}

class _SearchDialog extends StatefulWidget {
  const _SearchDialog({required this.lookup, required this.start});
  final BookLookup lookup;
  final String start;

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  late final _query = TextEditingController(text: widget.start);
  List<BookInfo>? _treffer;
  bool _laedt = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _suchen() async {
    if (_query.text.trim().isEmpty) return;
    setState(() => _laedt = true);
    final t = await widget.lookup.search(_query.text);
    if (mounted) {
      setState(() {
        _treffer = t;
        _laedt = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Titel suchen'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Titel oder Autor',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _suchen,
                ),
              ),
              onSubmitted: (_) => _suchen(),
            ),
            if (_laedt) const LinearProgressIndicator(),
            Expanded(
              child: _treffer == null
                  ? const SizedBox()
                  : _treffer!.isEmpty
                  ? const Center(child: Text('Keine Treffer.'))
                  : ListView(
                      children: [
                        for (final t in _treffer!)
                          ListTile(
                            title: Text(t.titel),
                            subtitle: Text(
                              [
                                if (t.autor.isNotEmpty) t.autor,
                                if (t.seiten != null) '${t.seiten} S.',
                              ].join(' · '),
                            ),
                            onTap: () => Navigator.pop(context, t),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
      ],
    );
  }
}

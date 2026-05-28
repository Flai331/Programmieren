import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice_item_model.dart';
import '../services/database_service.dart';
import '../utils/app_utils.dart';
import '../utils/feedback_service.dart';

class ArticlesScreen extends StatefulWidget {
  const ArticlesScreen({Key? key}) : super(key: key);

  @override
  State<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends State<ArticlesScreen> {
  final _dbService = DatabaseService();
  final _searchCtrl = TextEditingController();
  List<InvoiceItemModel> _articles = [];
  List<InvoiceItemModel> _filtered = [];
  bool _loading = true;

  static const _peach = Color(0xFFfda085);

  @override
  void initState() {
    super.initState();
    FeedbackService.logScreenLoad('Artikel');
    _searchCtrl.addListener(_filter);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _dbService.getAllArticles();
    if (mounted) {
      setState(() {
        _articles = list;
        _filter();
        _loading = false;
      });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_articles)
          : _articles
              .where((a) => a.description.toLowerCase().contains(q))
              .toList();
    });
  }

  Future<void> _openDialog({InvoiceItemModel? article}) async {
    final result = await showDialog<InvoiceItemModel>(
      context: context,
      builder: (_) => _ArticleDialog(existing: article),
    );
    if (result != null) {
      try {
        if (article == null) {
          await _dbService.insertArticle(result);
        } else {
          await _dbService.updateArticle(result);
        }
        await _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _delete(InvoiceItemModel article) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Artikel löschen'),
        content: Text('„${article.description}" wirklich löschen?'),
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
    if (ok == true) {
      await _dbService.deleteArticle(article.id);
      await _load();
    }
  }

  InputDecoration _searchDeco() => InputDecoration(
        hintText: 'Artikel suchen...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchCtrl.clear();
                  _filter();
                },
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: _searchDeco(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shopping_bag_outlined,
                                size: 56, color: Color(0xFF8a8a94)),
                            const SizedBox(height: 16),
                            Text(
                              _searchCtrl.text.isNotEmpty
                                  ? 'Keine Treffer'
                                  : 'Noch keine Artikel',
                              style: const TextStyle(color: Color(0xFF8a8a94)),
                            ),
                            if (_searchCtrl.text.isEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _openDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Artikel anlegen'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final a = _filtered[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                title: Text(a.description,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  '${AppUtils.formatCurrency(a.price)} · '
                                  '${a.quantity % 1 == 0 ? a.quantity.toInt() : a.quantity} ${a.unit}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF8a8a94)),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      AppUtils.formatCurrency(a.total),
                                      style: const TextStyle(
                                          color: _peach,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      onPressed: () => _openDialog(article: a),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 18,
                                          color: Color(0xFFff6b7a)),
                                      onPressed: () => _delete(a),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openDialog(),
        tooltip: 'Artikel anlegen',
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

// ── Dialog ────────────────────────────────────────────────────────────────────

class _ArticleDialog extends StatefulWidget {
  final InvoiceItemModel? existing;
  const _ArticleDialog({this.existing});

  @override
  State<_ArticleDialog> createState() => _ArticleDialogState();
}

class _ArticleDialogState extends State<_ArticleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _desc;
  late final TextEditingController _qty;
  late final TextEditingController _unit;
  late final TextEditingController _price;
  late final TextEditingController _tax;

  static const _peach = Color(0xFFfda085);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _desc = TextEditingController(text: e?.description ?? '');
    _qty = TextEditingController(
        text: e != null
            ? (e.quantity % 1 == 0
                ? e.quantity.toInt().toString()
                : e.quantity.toString())
            : '');
    _unit = TextEditingController(text: e?.unit ?? 'Stk.');
    _price = TextEditingController(
        text: e != null ? e.price.toString().replaceAll('.', ',') : '');
    _tax = TextEditingController(
        text: e != null
            ? (e.taxRate == e.taxRate.truncateToDouble()
                ? e.taxRate.toInt().toString()
                : e.taxRate.toString())
            : '19');
  }

  @override
  void dispose() {
    _desc.dispose();
    _qty.dispose();
    _unit.dispose();
    _price.dispose();
    _tax.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final article = InvoiceItemModel(
      id: widget.existing?.id ?? const Uuid().v4(),
      invoiceId: '__article__',
      description: _desc.text.trim(),
      quantity: _qty.text.trim().isEmpty ? 1 : (double.tryParse(_qty.text.replaceAll(',', '.')) ?? 1),
      unit: _unit.text.trim().isEmpty ? 'Stk.' : _unit.text.trim(),
      price: double.tryParse(_price.text.replaceAll(',', '.')) ?? 0,
      taxRate: double.tryParse(_tax.text.replaceAll(',', '.')) ?? 19,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    Navigator.pop(context, article);
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.existing == null ? 'Artikel anlegen' : 'Artikel bearbeiten'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _desc,
                decoration: _deco('Beschreibung'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _qty,
                    decoration: _deco('Menge (optional)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null; // optional
                      return double.tryParse(v.replaceAll(',', '.')) == null
                          ? 'Zahl'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _unit,
                    decoration: _deco('Einheit'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                decoration: _deco('Preis (€)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) =>
                    (double.tryParse(v?.replaceAll(',', '.') ?? '') == null)
                        ? 'Zahl'
                        : null,
              ),
              const SizedBox(height: 12),
              // MwSt. mit Schnellauswahl
              StatefulBuilder(
                builder: (ctx, setInner) {
                  final current =
                      double.tryParse(_tax.text.replaceAll(',', '.')) ?? 19.0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _tax,
                        decoration: _deco('MwSt. (%)'),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setInner(() {}),
                        validator: (v) =>
                            (double.tryParse(v?.replaceAll(',', '.') ?? '') ==
                                    null)
                                ? 'Zahl'
                                : null,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [7.0, 7.8, 19.0].map((rate) {
                          final sel = current == rate;
                          return ChoiceChip(
                            label: Text(
                              '${rate == rate.truncateToDouble() ? rate.toInt() : rate.toString().replaceAll('.', ',')} %',
                              style: TextStyle(
                                fontSize: 13,
                                color: sel
                                    ? Colors.white
                                    : const Color(0xFF8a8a94),
                              ),
                            ),
                            selected: sel,
                            selectedColor: _peach,
                            backgroundColor: const Color(0xFF2a2a32),
                            onSelected: (_) {
                              _tax.text = rate == rate.truncateToDouble()
                                  ? rate.toInt().toString()
                                  : rate.toString();
                              setInner(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _peach),
          onPressed: _submit,
          child: Text(widget.existing == null ? 'Anlegen' : 'Speichern'),
        ),
      ],
    );
  }
}

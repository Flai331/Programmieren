import 'package:flutter/material.dart';
import '../models/invoice_item_model.dart';
import '../utils/utils.dart';

class InvoiceItemWidget extends StatefulWidget {
  final InvoiceItemModel item;
  final int index;
  final Function(int, InvoiceItemModel) onUpdate;
  final Function(int) onRemove;

  const InvoiceItemWidget({
    Key? key,
    required this.item,
    required this.index,
    required this.onUpdate,
    required this.onRemove,
  }) : super(key: key);

  @override
  State<InvoiceItemWidget> createState() => _InvoiceItemWidgetState();
}

class _InvoiceItemWidgetState extends State<InvoiceItemWidget> {
  late TextEditingController _descriptionController;
  late TextEditingController _quantityController;
  late TextEditingController _unitController;
  late TextEditingController _priceController;
  late TextEditingController _taxRateController;

  static const _peach = Color(0xFFfda085);
  static const _quickRates = [7.0, 7.8, 19.0];

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.item.description);
    _quantityController = TextEditingController(text: widget.item.quantity.toString());
    _unitController = TextEditingController(text: widget.item.unit);
    _priceController = TextEditingController(text: widget.item.price.toString());
    _taxRateController = TextEditingController(
      text: widget.item.taxRate == widget.item.taxRate.truncateToDouble()
          ? widget.item.taxRate.toInt().toString()
          : widget.item.taxRate.toString(),
    );
  }

  void _updateItem() {
    final updatedItem = widget.item.copyWith(
      description: _descriptionController.text,
      quantity: double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 1,
      unit: _unitController.text,
      price: double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0,
      taxRate: double.tryParse(_taxRateController.text.replaceAll(',', '.')) ?? 19,
    );
    widget.onUpdate(widget.index, updatedItem);
  }

  void _setTaxRate(double rate) {
    setState(() {
      _taxRateController.text =
          rate == rate.truncateToDouble() ? rate.toInt().toString() : rate.toString();
    });
    _updateItem();
  }

  InputDecoration _deco(String label, {String? prefix}) => InputDecoration(
        labelText: label,
        prefixText: prefix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  @override
  Widget build(BuildContext context) {
    final currentRate =
        double.tryParse(_taxRateController.text.replaceAll(',', '.')) ?? 19.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Titel + Summe
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Artikel ${widget.index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  AppUtils.formatCurrency(widget.item.total),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: _peach),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Beschreibung
            TextField(
              controller: _descriptionController,
              decoration: _deco('Beschreibung'),
              onChanged: (_) => _updateItem(),
            ),
            const SizedBox(height: 12),

            // Menge | Einheit | Preis
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _deco('Menge'),
                    onChanged: (_) => _updateItem(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _unitController,
                    decoration: _deco('Einheit'),
                    onChanged: (_) => _updateItem(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _deco('Preis', prefix: '€ '),
                    onChanged: (_) => _updateItem(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // MwSt-Satz
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _taxRateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _deco('MwSt. (%)'),
                    onChanged: (_) => _updateItem(),
                  ),
                ),
                const SizedBox(width: 8),
                // Schnellauswahl-Chips
                Expanded(
                  flex: 3,
                  child: Wrap(
                    spacing: 6,
                    children: _quickRates.map((rate) {
                      final selected = currentRate == rate;
                      return ChoiceChip(
                        label: Text(
                          '${rate == rate.truncateToDouble() ? rate.toInt() : rate.toString().replaceAll('.', ',')} %',
                          style: TextStyle(
                            fontSize: 12,
                            color: selected ? Colors.white : const Color(0xFF8a8a94),
                          ),
                        ),
                        selected: selected,
                        selectedColor: _peach,
                        backgroundColor: const Color(0xFF2a2a32),
                        onSelected: (_) => _setTaxRate(rate),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Löschen
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => widget.onRemove(widget.index),
                icon: const Icon(Icons.delete),
                label: const Text('Artikel löschen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }
}

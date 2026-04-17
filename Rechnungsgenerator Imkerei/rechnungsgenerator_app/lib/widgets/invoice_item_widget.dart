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

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.item.description);
    _quantityController = TextEditingController(text: widget.item.quantity.toString());
    _unitController = TextEditingController(text: widget.item.unit);
    _priceController = TextEditingController(text: widget.item.price.toString());
  }

  void _updateItem() {
    final updatedItem = widget.item.copyWith(
      description: _descriptionController.text,
      quantity: double.tryParse(_quantityController.text) ?? 1,
      unit: _unitController.text,
      price: double.tryParse(_priceController.text) ?? 0,
    );
    widget.onUpdate(widget.index, updatedItem);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.item.total;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Item number and total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Artikel ${widget.index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  AppUtils.formatCurrency(total),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFfda085),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Description field (full width)
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Beschreibung',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (_) => _updateItem(),
            ),
            const SizedBox(height: 12),

            // Quantity, Unit, Price row
            Row(
              children: [
                // Quantity
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Menge',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (_) => _updateItem(),
                  ),
                ),
                const SizedBox(width: 8),

                // Unit
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _unitController,
                    decoration: InputDecoration(
                      labelText: 'Einheit',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (_) => _updateItem(),
                  ),
                ),
                const SizedBox(width: 8),

                // Price
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Preis',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      prefixText: '€ ',
                    ),
                    onChanged: (_) => _updateItem(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Delete button
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
    super.dispose();
  }
}

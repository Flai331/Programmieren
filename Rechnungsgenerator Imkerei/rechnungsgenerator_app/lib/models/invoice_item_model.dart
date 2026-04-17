class InvoiceItemModel {
  final String id;
  final String invoiceId;
  final String description;
  final double quantity;
  final String unit;
  final double price;
  final double taxRate;
  final DateTime createdAt;

  InvoiceItemModel({
    required this.id,
    required this.invoiceId,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.taxRate,
    required this.createdAt,
  });

  double get total => quantity * price;
  double get tax => total * (taxRate / 100);
  double get totalWithTax => total + tax;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'description': description,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'tax_rate': taxRate,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory InvoiceItemModel.fromMap(Map<String, dynamic> map) {
    return InvoiceItemModel(
      id: map['id'] as String,
      invoiceId: map['invoice_id'] as String,
      description: map['description'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String,
      price: (map['price'] as num).toDouble(),
      taxRate: (map['tax_rate'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  InvoiceItemModel copyWith({
    String? id,
    String? invoiceId,
    String? description,
    double? quantity,
    String? unit,
    double? price,
    double? taxRate,
    DateTime? createdAt,
  }) {
    return InvoiceItemModel(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      taxRate: taxRate ?? this.taxRate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'InvoiceItemModel(id: $id, description: $description, quantity: $quantity, price: $price)';
}

class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String companyId;
  final String customerId;
  final DateTime date;
  final int paymentTerms; // in days
  final String? additionalInfo;
  final double taxRate;
  final double subtotal;
  final double vat;
  final double total;
  final bool synced;
  final DateTime createdAt;
  final DateTime? updatedAt;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.companyId,
    required this.customerId,
    required this.date,
    required this.paymentTerms,
    this.additionalInfo,
    required this.taxRate,
    required this.subtotal,
    required this.vat,
    required this.total,
    this.synced = false,
    required this.createdAt,
    this.updatedAt,
  });

  DateTime get dueDate => date.add(Duration(days: paymentTerms));

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'company_id': companyId,
      'customer_id': customerId,
      'date': date.toIso8601String(),
      'payment_terms': paymentTerms,
      'additional_info': additionalInfo,
      'tax_rate': taxRate,
      'subtotal': subtotal,
      'vat': vat,
      'total': total,
      'synced': synced ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory InvoiceModel.fromMap(Map<String, dynamic> map) {
    return InvoiceModel(
      id: map['id'] as String,
      invoiceNumber: map['invoice_number'] as String,
      companyId: map['company_id'] as String,
      customerId: map['customer_id'] as String,
      date: DateTime.parse(map['date'] as String),
      paymentTerms: map['payment_terms'] as int,
      additionalInfo: map['additional_info'] as String?,
      taxRate: (map['tax_rate'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
      vat: (map['vat'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      synced: (map['synced'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  InvoiceModel copyWith({
    String? id,
    String? invoiceNumber,
    String? companyId,
    String? customerId,
    DateTime? date,
    int? paymentTerms,
    String? additionalInfo,
    double? taxRate,
    double? subtotal,
    double? vat,
    double? total,
    bool? synced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      companyId: companyId ?? this.companyId,
      customerId: customerId ?? this.customerId,
      date: date ?? this.date,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      taxRate: taxRate ?? this.taxRate,
      subtotal: subtotal ?? this.subtotal,
      vat: vat ?? this.vat,
      total: total ?? this.total,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'InvoiceModel(id: $id, number: $invoiceNumber, total: $total)';
}

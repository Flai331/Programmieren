class CompanyModel {
  final String id;
  final String name;
  final String email;
  final String street;
  final String city;
  final String zipcode;
  final String phone;
  final String? taxId;
  final String? website;
  final String? accountHolder;
  final String? iban;
  final String? bic;
  final String? bank;
  final String? paypal;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CompanyModel({
    required this.id,
    required this.name,
    required this.email,
    required this.street,
    required this.city,
    required this.zipcode,
    required this.phone,
    this.taxId,
    this.website,
    this.accountHolder,
    this.iban,
    this.bic,
    this.bank,
    this.paypal,
    required this.createdAt,
    this.updatedAt,
  });

  // Convert to JSON for API/Database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'street': street,
      'city': city,
      'zipcode': zipcode,
      'phone': phone,
      'tax_id': taxId,
      'website': website,
      'account_holder': accountHolder,
      'iban': iban,
      'bic': bic,
      'bank': bank,
      'paypal': paypal,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Create from database map
  factory CompanyModel.fromMap(Map<String, dynamic> map) {
    return CompanyModel(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      street: map['street'] as String,
      city: map['city'] as String,
      zipcode: map['zipcode'] as String,
      phone: map['phone'] as String,
      taxId: map['tax_id'] as String?,
      website: map['website'] as String?,
      accountHolder: map['account_holder'] as String?,
      iban: map['iban'] as String?,
      bic: map['bic'] as String?,
      bank: map['bank'] as String?,
      paypal: map['paypal'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  // Copy with method for updates
  CompanyModel copyWith({
    String? id,
    String? name,
    String? email,
    String? street,
    String? city,
    String? zipcode,
    String? phone,
    String? taxId,
    String? website,
    String? accountHolder,
    String? iban,
    String? bic,
    String? bank,
    String? paypal,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      street: street ?? this.street,
      city: city ?? this.city,
      zipcode: zipcode ?? this.zipcode,
      phone: phone ?? this.phone,
      taxId: taxId ?? this.taxId,
      website: website ?? this.website,
      accountHolder: accountHolder ?? this.accountHolder,
      iban: iban ?? this.iban,
      bic: bic ?? this.bic,
      bank: bank ?? this.bank,
      paypal: paypal ?? this.paypal,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'CompanyModel(id: $id, name: $name, email: $email)';
}

class AddressTemplateModel {
  final String id;
  final String companyId;
  final String name;
  final String street;
  final String city;
  final String zipcode;
  final String? phone;
  final String? email;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AddressTemplateModel({
    required this.id,
    required this.companyId,
    required this.name,
    required this.street,
    required this.city,
    required this.zipcode,
    this.phone,
    this.email,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company_id': companyId,
      'name': name,
      'street': street,
      'city': city,
      'zipcode': zipcode,
      'phone': phone,
      'email': email,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory AddressTemplateModel.fromMap(Map<String, dynamic> map) {
    return AddressTemplateModel(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      name: map['name'] as String,
      street: map['street'] as String,
      city: map['city'] as String,
      zipcode: map['zipcode'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  AddressTemplateModel copyWith({
    String? id,
    String? companyId,
    String? name,
    String? street,
    String? city,
    String? zipcode,
    String? phone,
    String? email,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AddressTemplateModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      street: street ?? this.street,
      city: city ?? this.city,
      zipcode: zipcode ?? this.zipcode,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'AddressTemplateModel(id: $id, name: $name, city: $city)';
}

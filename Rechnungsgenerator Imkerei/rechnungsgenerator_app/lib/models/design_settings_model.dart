class DesignSettingsModel {
  final String id;
  final String companyId;
  final String headerTextColor; // hex color code
  final int headerTextSize;
  final String? logoUrl; // URL to Cloudinary
  final String? topHeaderUrl; // URL to Cloudinary
  final double? logoX;
  final double? logoY;
  final double? headerX;
  final double? headerY;
  final double? headerWidth;
  final double? headerHeight;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DesignSettingsModel({
    required this.id,
    required this.companyId,
    this.headerTextColor = '#000000',
    this.headerTextSize = 16,
    this.logoUrl,
    this.topHeaderUrl,
    this.logoX,
    this.logoY,
    this.headerX,
    this.headerY,
    this.headerWidth,
    this.headerHeight,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company_id': companyId,
      'header_text_color': headerTextColor,
      'header_text_size': headerTextSize,
      'logo_url': logoUrl,
      'top_header_url': topHeaderUrl,
      'logo_x': logoX,
      'logo_y': logoY,
      'header_x': headerX,
      'header_y': headerY,
      'header_width': headerWidth,
      'header_height': headerHeight,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory DesignSettingsModel.fromMap(Map<String, dynamic> map) {
    return DesignSettingsModel(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      headerTextColor: map['header_text_color'] as String? ?? '#000000',
      headerTextSize: map['header_text_size'] as int? ?? 16,
      logoUrl: map['logo_url'] as String?,
      topHeaderUrl: map['top_header_url'] as String?,
      logoX: map['logo_x'] as double?,
      logoY: map['logo_y'] as double?,
      headerX: map['header_x'] as double?,
      headerY: map['header_y'] as double?,
      headerWidth: map['header_width'] as double?,
      headerHeight: map['header_height'] as double?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  DesignSettingsModel copyWith({
    String? id,
    String? companyId,
    String? headerTextColor,
    int? headerTextSize,
    String? logoUrl,
    String? topHeaderUrl,
    double? logoX,
    double? logoY,
    double? headerX,
    double? headerY,
    double? headerWidth,
    double? headerHeight,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DesignSettingsModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      headerTextColor: headerTextColor ?? this.headerTextColor,
      headerTextSize: headerTextSize ?? this.headerTextSize,
      logoUrl: logoUrl ?? this.logoUrl,
      topHeaderUrl: topHeaderUrl ?? this.topHeaderUrl,
      logoX: logoX ?? this.logoX,
      logoY: logoY ?? this.logoY,
      headerX: headerX ?? this.headerX,
      headerY: headerY ?? this.headerY,
      headerWidth: headerWidth ?? this.headerWidth,
      headerHeight: headerHeight ?? this.headerHeight,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'DesignSettingsModel(id: $id, companyId: $companyId, logoUrl: $logoUrl)';
}

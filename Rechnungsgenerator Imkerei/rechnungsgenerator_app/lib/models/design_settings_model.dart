class DesignSettingsModel {
  final String id;
  final String companyId;
  final String headerTextColor; // hex color code
  final int headerTextSize;
  final String? logoUrl; // URL to Cloudinary
  final String? topHeaderUrl; // URL to Cloudinary
  final double? logoX;
  final double? logoY;
  final double? logoWidth;
  final double? logoHeight;
  final double? headerX;
  final double? headerY;
  final double? headerWidth;
  final double? headerHeight;
  final bool logoFlipH;
  final bool logoFlipV;
  final bool headerFlipH;
  final bool headerFlipV;
  final String tableHeaderColor;
  /// JSON-String mit Positionen aller Layout-Elemente
  /// Format: {"elementId": {"x": .., "y": .., "w": .., "h": .., "fh": false, "fv": false}, ...}
  final String? layoutJson;
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
    this.logoWidth,
    this.logoHeight,
    this.headerX,
    this.headerY,
    this.headerWidth,
    this.headerHeight,
    this.logoFlipH = false,
    this.logoFlipV = false,
    this.headerFlipH = false,
    this.headerFlipV = false,
    this.tableHeaderColor = '#fda085',
    this.layoutJson,
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
      'logo_width': logoWidth,
      'logo_height': logoHeight,
      'header_x': headerX,
      'header_y': headerY,
      'header_width': headerWidth,
      'header_height': headerHeight,
      'logo_flip_h': logoFlipH,
      'logo_flip_v': logoFlipV,
      'header_flip_h': headerFlipH,
      'header_flip_v': headerFlipV,
      'table_header_color': tableHeaderColor,
      'layout_json': layoutJson,
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
      logoX: (map['logo_x'] as num?)?.toDouble(),
      logoY: (map['logo_y'] as num?)?.toDouble(),
      logoWidth: (map['logo_width'] as num?)?.toDouble(),
      logoHeight: (map['logo_height'] as num?)?.toDouble(),
      headerX: (map['header_x'] as num?)?.toDouble(),
      headerY: (map['header_y'] as num?)?.toDouble(),
      headerWidth: (map['header_width'] as num?)?.toDouble(),
      headerHeight: (map['header_height'] as num?)?.toDouble(),
      logoFlipH: map['logo_flip_h'] as bool? ?? false,
      logoFlipV: map['logo_flip_v'] as bool? ?? false,
      headerFlipH: map['header_flip_h'] as bool? ?? false,
      headerFlipV: map['header_flip_v'] as bool? ?? false,
      tableHeaderColor: map['table_header_color'] as String? ?? '#fda085',
      layoutJson: map['layout_json'] as String?,
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
    double? logoWidth,
    double? logoHeight,
    double? headerX,
    double? headerY,
    double? headerWidth,
    double? headerHeight,
    bool? logoFlipH,
    bool? logoFlipV,
    bool? headerFlipH,
    bool? headerFlipV,
    String? tableHeaderColor,
    String? layoutJson,
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
      logoWidth: logoWidth ?? this.logoWidth,
      logoHeight: logoHeight ?? this.logoHeight,
      headerX: headerX ?? this.headerX,
      headerY: headerY ?? this.headerY,
      headerWidth: headerWidth ?? this.headerWidth,
      headerHeight: headerHeight ?? this.headerHeight,
      logoFlipH: logoFlipH ?? this.logoFlipH,
      logoFlipV: logoFlipV ?? this.logoFlipV,
      headerFlipH: headerFlipH ?? this.headerFlipH,
      headerFlipV: headerFlipV ?? this.headerFlipV,
      tableHeaderColor: tableHeaderColor ?? this.tableHeaderColor,
      layoutJson: layoutJson ?? this.layoutJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'DesignSettingsModel(id: $id, companyId: $companyId, logoUrl: $logoUrl)';
}

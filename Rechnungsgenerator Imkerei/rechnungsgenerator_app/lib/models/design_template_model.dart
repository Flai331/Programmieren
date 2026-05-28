import 'dart:convert';

/// Lokale Design-Vorlage (gespeichert als JSON-Datei via path_provider).
class DesignTemplateModel {
  final String id;
  final String name;
  final String? description;
  final String tableHeaderColor;
  final String headerTextColor;
  final int headerTextSize;
  final String? logoUrl;
  final String? topHeaderUrl;
  final String? layoutJson;
  final DateTime createdAt;

  const DesignTemplateModel({
    required this.id,
    required this.name,
    this.description,
    this.tableHeaderColor = '#fda085',
    this.headerTextColor = '#000000',
    this.headerTextSize = 20,
    this.logoUrl,
    this.topHeaderUrl,
    this.layoutJson,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'tableHeaderColor': tableHeaderColor,
        'headerTextColor': headerTextColor,
        'headerTextSize': headerTextSize,
        'logoUrl': logoUrl,
        'topHeaderUrl': topHeaderUrl,
        'layoutJson': layoutJson,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DesignTemplateModel.fromJson(Map<String, dynamic> j) =>
      DesignTemplateModel(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        tableHeaderColor: j['tableHeaderColor'] as String? ?? '#fda085',
        headerTextColor: j['headerTextColor'] as String? ?? '#000000',
        headerTextSize: j['headerTextSize'] as int? ?? 20,
        logoUrl: j['logoUrl'] as String?,
        topHeaderUrl: j['topHeaderUrl'] as String?,
        layoutJson: j['layoutJson'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  static List<DesignTemplateModel> listFromJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => DesignTemplateModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<DesignTemplateModel> templates) =>
      jsonEncode(templates.map((t) => t.toJson()).toList());
}

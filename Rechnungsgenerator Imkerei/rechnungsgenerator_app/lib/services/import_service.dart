import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import '../utils/feedback_service.dart';
import 'database_service.dart';
import '../utils/invoice_number_generator.dart';

/// Was ein Import bewirkt hat – für die Rückmeldung an den Nutzer.
class ImportResult {
  final bool companyImported;
  final bool designImported;
  final bool logoImported;
  final bool headerImported;
  final int customers;
  final int articles;
  final int invoices;

  /// Letzte Rechnungsnummer aus der Quelle, falls vorhanden.
  final String? lastInvoiceNumber;

  /// Hinweise, die der Nutzer sehen soll (z.B. was NICHT enthalten war).
  final List<String> notes;

  const ImportResult({
    this.companyImported = false,
    this.designImported = false,
    this.logoImported = false,
    this.headerImported = false,
    this.customers = 0,
    this.articles = 0,
    this.invoices = 0,
    this.lastInvoiceNumber,
    this.notes = const [],
  });

  bool get isEmpty =>
      !companyImported &&
      !designImported &&
      customers == 0 &&
      articles == 0 &&
      invoices == 0;
}

/// Fehler beim Lesen einer Import-Datei, mit einer Erklärung für den Nutzer.
class ImportFormatException implements Exception {
  final String message;
  const ImportFormatException(this.message);
  @override
  String toString() => message;
}

/// Liest den Export des Rechnungsgenerators (WebApp) ein.
///
/// Der Generator speichert ausschließlich die Vorlage – Absenderdaten, Logo,
/// Briefkopf und Farben. Rechnungen und Kunden legt er nicht an, er erzeugt
/// nur PDFs. Kunden, Artikel und Rechnungen werden trotzdem unterstützt,
/// falls sie aus einer anderen Quelle stammen.
class ImportParser {
  /// Rohdaten einlesen und prüfen.
  static Map<String, dynamic> decode(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      throw const ImportFormatException('Die Datei ist leer.');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw const ImportFormatException(
          'Die Datei ist kein gültiges JSON. Stammt sie wirklich aus dem '
          'Export des Rechnungsgenerators?');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ImportFormatException(
          'Unerwarteter Aufbau – erwartet wird ein JSON-Objekt.');
    }

    // Auch eine roh kopierte invoiceDesign-Struktur annehmen: Sie hat kein
    // Hüllen-Objekt, aber die Absenderfelder.
    if (!decoded.containsKey('design') &&
        decoded.keys.any((k) => k.startsWith('sender'))) {
      return {'design': decoded};
    }

    if (!decoded.containsKey('design') &&
        !decoded.containsKey('customers') &&
        !decoded.containsKey('invoices') &&
        !decoded.containsKey('articles')) {
      throw const ImportFormatException(
          'In der Datei ist nichts zum Übernehmen: weder Vorlage noch '
          'Kunden, Artikel oder Rechnungen.');
    }
    return decoded;
  }

  static Map<String, dynamic>? _design(Map<String, dynamic> data) {
    final d = data['design'];
    return d is Map<String, dynamic> ? d : null;
  }

  static String _str(Map<String, dynamic>? m, String key) {
    final v = m?[key];
    return v == null ? '' : v.toString().trim();
  }

  static String? _strOrNull(Map<String, dynamic>? m, String key) {
    final v = _str(m, key);
    return v.isEmpty ? null : v;
  }

  /// Absenderdaten der Vorlage als Firma.
  ///
  /// [existing] wird übernommen, damit ein Import bestehende Angaben
  /// ergänzt statt sie zu überschreiben, wenn die Quelle ein Feld leer lässt.
  static CompanyModel? toCompany(
    Map<String, dynamic> data, {
    CompanyModel? existing,
  }) {
    final design = _design(data);
    if (design == null) return null;

    final name = _str(design, 'senderName');
    // Ohne Namen ist es keine brauchbare Absenderangabe.
    if (name.isEmpty && existing == null) return null;

    String pick(String key, String? vorhanden) {
      final neu = _str(design, key);
      return neu.isNotEmpty ? neu : (vorhanden ?? '');
    }

    String? pickOrNull(String key, String? vorhanden) =>
        _strOrNull(design, key) ?? vorhanden;

    // Der Generator führt PLZ und Ort in einem Feld – hier wieder trennen.
    final ortRoh = pick('senderCity', null);
    final ort = ortRoh.isNotEmpty
        ? splitCity(ortRoh)
        : (zipcode: existing?.zipcode ?? '', city: existing?.city ?? '');

    return CompanyModel(
      id: existing?.id ?? 'default',
      name: name.isNotEmpty ? name : (existing?.name ?? ''),
      email: pick('senderEmail', existing?.email),
      street: pick('senderStreet', existing?.street),
      city: ort.city,
      zipcode: ort.zipcode.isNotEmpty ? ort.zipcode : (existing?.zipcode ?? ''),
      phone: pick('senderPhone', existing?.phone),
      taxId: pickOrNull('senderTaxId', existing?.taxId),
      website: pickOrNull('senderWebsite', existing?.website),
      accountHolder:
          pickOrNull('senderAccountHolder', existing?.accountHolder),
      iban: pickOrNull('senderIban', existing?.iban),
      bic: pickOrNull('senderBic', existing?.bic),
      bank: pickOrNull('senderBank', existing?.bank),
      paypal: pickOrNull('senderPaypal', existing?.paypal),
      invoiceNumberPattern: existing?.invoiceNumberPattern ??
          InvoiceNumberGenerator.defaultPattern,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Der Rechnungsgenerator trennt PLZ und Ort nicht – beides steht in
  /// `senderCity`. Für die Anzeige reicht das; hier wird nur versucht, eine
  /// führende Postleitzahl abzutrennen.
  static ({String zipcode, String city}) splitCity(String value) {
    final m = RegExp(r'^\s*(\d{4,5})\s+(.+)$').firstMatch(value);
    if (m == null) return (zipcode: '', city: value.trim());
    return (zipcode: m.group(1)!, city: m.group(2)!.trim());
  }

  /// Farbe und Schriftgröße der Kopfzeile.
  static ({String? color, int? size}) headerStyle(Map<String, dynamic> data) {
    final design = _design(data);
    final farbe = _strOrNull(design, 'headerTextColor');
    final groesse = int.tryParse(_str(design, 'headerTextSize'));
    return (color: farbe, size: groesse);
  }

  /// Position und Größe des Briefkopf-Bildes.
  static ({double? x, double? y, double? width, double? height}) headerBox(
      Map<String, dynamic> data) {
    final box = data['topHeader'];
    if (box is! Map) return (x: null, y: null, width: null, height: null);
    double? num(String key) {
      final v = box[key];
      if (v == null) return null;
      return double.tryParse(v.toString());
    }

    return (x: num('x'), y: num('y'), width: num('width'), height: num('height'));
  }

  /// Bilddaten als Data-URL (`data:image/png;base64,…`) oder null.
  static String? logoDataUrl(Map<String, dynamic> data) =>
      _dataUrl(_strOrNull(_design(data), 'logo'));

  static String? headerDataUrl(Map<String, dynamic> data) =>
      _dataUrl(_strOrNull(_design(data), 'topHeader'));

  static String? _dataUrl(String? value) {
    if (value == null) return null;
    return value.startsWith('data:image/') ? value : null;
  }

  /// Rohdaten aus einer Data-URL. Null, wenn sie nicht lesbar ist.
  static List<int>? bytesFromDataUrl(String dataUrl) {
    final komma = dataUrl.indexOf(',');
    if (komma < 0) return null;
    try {
      return base64Decode(dataUrl.substring(komma + 1));
    } catch (_) {
      return null;
    }
  }

  /// Dateiendung passend zur Data-URL, Vorgabe `.png`.
  static String extensionFromDataUrl(String dataUrl) {
    final m = RegExp(r'^data:image/([a-zA-Z0-9+]+)').firstMatch(dataUrl);
    final typ = m?.group(1)?.toLowerCase();
    return switch (typ) {
      'jpeg' || 'jpg' => '.jpg',
      'webp' => '.webp',
      'gif' => '.gif',
      _ => '.png',
    };
  }

  /// Design-Einstellungen aus der Vorlage.
  ///
  /// [logoPath] und [headerPath] sind die bereits gespeicherten Bilddateien;
  /// die Data-URLs aus der Quelle werden vorher auf die Platte geschrieben.
  static DesignSettingsModel toDesignSettings(
    Map<String, dynamic> data, {
    required String companyId,
    DesignSettingsModel? existing,
    String? logoPath,
    String? headerPath,
  }) {
    final stil = headerStyle(data);
    final box = headerBox(data);
    return DesignSettingsModel(
      id: existing?.id ?? 'default',
      companyId: companyId,
      headerTextColor: stil.color ?? existing?.headerTextColor ?? '#000000',
      headerTextSize: stil.size ?? existing?.headerTextSize ?? 16,
      logoUrl: logoPath ?? existing?.logoUrl,
      topHeaderUrl: headerPath ?? existing?.topHeaderUrl,
      logoX: existing?.logoX,
      logoY: existing?.logoY,
      logoWidth: existing?.logoWidth,
      logoHeight: existing?.logoHeight,
      headerX: box.x ?? existing?.headerX,
      headerY: box.y ?? existing?.headerY,
      headerWidth: box.width ?? existing?.headerWidth,
      headerHeight: box.height ?? existing?.headerHeight,
      layoutJson: existing?.layoutJson,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static String? lastInvoiceNumber(Map<String, dynamic> data) {
    final v = data['lastInvoiceNumber'];
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  /// Optionale Kunden aus der Quelle.
  static List<CustomerModel> toCustomers(Map<String, dynamic> data) {
    final liste = data['customers'];
    if (liste is! List) return const [];
    final result = <CustomerModel>[];
    for (final eintrag in liste) {
      if (eintrag is! Map) continue;
      final m = eintrag.cast<String, dynamic>();
      final name = _str(m, 'name');
      if (name.isEmpty) continue;
      final ort = splitCity(_str(m, 'city'));
      result.add(CustomerModel(
        id: _strOrNull(m, 'id') ?? 'import-${result.length}',
        customerNumber: int.tryParse(_str(m, 'customerNumber')),
        name: name,
        street: _str(m, 'street'),
        zipcode: _str(m, 'zipcode').isNotEmpty
            ? _str(m, 'zipcode')
            : ort.zipcode,
        city: _str(m, 'zipcode').isNotEmpty ? _str(m, 'city') : ort.city,
        phone: _str(m, 'phone'),
        email: _str(m, 'email'),
        createdAt: DateTime.now(),
      ));
    }
    return result;
  }

  /// Vorschau: Was steckt in der Datei?
  static List<String> describe(Map<String, dynamic> data) {
    final zeilen = <String>[];
    final design = _design(data);
    if (design != null) {
      final name = _str(design, 'senderName');
      zeilen.add(name.isEmpty ? 'Vorlage (ohne Absendername)' : 'Absender: $name');
      if (logoDataUrl(data) != null) zeilen.add('Logo');
      if (headerDataUrl(data) != null) zeilen.add('Briefkopf-Bild');
      final stil = headerStyle(data);
      if (stil.color != null) zeilen.add('Farbe der Kopfzeile: ${stil.color}');
    }
    final kunden = toCustomers(data).length;
    if (kunden > 0) zeilen.add('$kunden Kunden');
    final nummer = lastInvoiceNumber(data);
    if (nummer != null) zeilen.add('Letzte Rechnungsnummer: $nummer');
    if (zeilen.isEmpty) zeilen.add('Keine übernehmbaren Daten gefunden');
    return zeilen;
  }
}

/// Führt einen Import tatsächlich aus: Bilder auf die Platte, Datensätze in
/// die Datenbank.
///
/// Die Zuordnung selbst steckt in [ImportParser] und ist ohne Datenbank
/// prüfbar; hier passieren nur die Seiteneffekte.
class ImportRunner {
  final DatabaseService _db;

  ImportRunner([DatabaseService? db]) : _db = db ?? DatabaseService();

  /// Verzeichnis für importierte Bilder, in Tests überschreibbar.
  static Directory? overrideImageDir;

  static Future<Directory> _imageDir() async {
    final dir = overrideImageDir ??
        Directory(p.join(
            (await getApplicationDocumentsDirectory()).path, 'design'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Data-URL als Datei ablegen und den Pfad liefern.
  static Future<String?> saveImage(String dataUrl, String basename) async {
    final bytes = ImportParser.bytesFromDataUrl(dataUrl);
    if (bytes == null || bytes.isEmpty) return null;
    try {
      final dir = await _imageDir();
      final datei = File(
          p.join(dir.path, '$basename${ImportParser.extensionFromDataUrl(dataUrl)}'));
      await datei.writeAsBytes(bytes);
      return datei.path;
    } catch (_) {
      return null;
    }
  }

  /// Import ausführen. [raw] ist der Inhalt der gewählten Datei.
  Future<ImportResult> run(String raw) async {
    final data = ImportParser.decode(raw);
    final hinweise = <String>[];

    // Bestehende Firma weiterverwenden, damit vorhandene Angaben erhalten
    // bleiben, die die Quelle nicht kennt (z.B. die Postleitzahl).
    final firmen = await _db.getAllCompanies();
    final bestehend = firmen.isNotEmpty ? firmen.first : null;

    final firma = ImportParser.toCompany(data, existing: bestehend);
    var firmaUebernommen = false;
    if (firma != null) {
      if (bestehend == null) {
        await _db.insertCompany(firma);
      } else {
        await _db.updateCompany(firma);
      }
      firmaUebernommen = true;
    }

    final companyId = firma?.id ?? bestehend?.id;

    var logo = false, briefkopf = false, designUebernommen = false;
    if (companyId != null) {
      final logoUrl = ImportParser.logoDataUrl(data);
      final headerUrl = ImportParser.headerDataUrl(data);
      final logoPfad =
          logoUrl == null ? null : await saveImage(logoUrl, 'logo');
      final headerPfad =
          headerUrl == null ? null : await saveImage(headerUrl, 'briefkopf');
      logo = logoPfad != null;
      briefkopf = headerPfad != null;
      if (logoUrl != null && logoPfad == null) {
        hinweise.add('Das Logo konnte nicht gelesen werden.');
      }
      if (headerUrl != null && headerPfad == null) {
        hinweise.add('Der Briefkopf konnte nicht gelesen werden.');
      }

      final vorhandenesDesign = await _db.getDesignSettings(companyId);
      final design = ImportParser.toDesignSettings(
        data,
        companyId: companyId,
        existing: vorhandenesDesign,
        logoPath: logoPfad,
        headerPath: headerPfad,
      );
      if (vorhandenesDesign == null) {
        await _db.insertDesignSettings(design);
      } else {
        await _db.updateDesignSettings(design);
      }
      designUebernommen = true;
    }

    var kundenZahl = 0;
    for (final kunde in ImportParser.toCustomers(data)) {
      await _db.insertCustomer(kunde);
      kundenZahl++;
    }

    final letzteNummer = ImportParser.lastInvoiceNumber(data);
    if (letzteNummer != null) {
      hinweise.add(
          'Zuletzt vergebene Rechnungsnummer war $letzteNummer. Prüf das '
          'Nummernmuster unter Einstellungen, damit die Zählung dort '
          'weiterläuft.');
    }
    if (!data.containsKey('invoices')) {
      hinweise.add(
          'Rechnungen sind nicht dabei: Der Rechnungsgenerator legt keine an, '
          'er erzeugt nur PDFs. Übernommen wurde die Vorlage.');
    }

    FeedbackService.log('📥 Import: Firma=$firmaUebernommen, '
        'Design=$designUebernommen, Kunden=$kundenZahl');

    return ImportResult(
      companyImported: firmaUebernommen,
      designImported: designUebernommen,
      logoImported: logo,
      headerImported: briefkopf,
      customers: kundenZahl,
      lastInvoiceNumber: letzteNummer,
      notes: hinweise,
    );
  }
}

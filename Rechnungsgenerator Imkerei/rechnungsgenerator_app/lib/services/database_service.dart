import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';
import '../utils/feedback_service.dart';

/// Lokale SQLite-Datenbank via sqflite (offline-only, Play-Store-ready).
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  DatabaseService._internal();
  factory DatabaseService() => _instance;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    FeedbackService.log('🗄️ SQLite-Datenbank bereit');
    return _database!;
  }

  /// Nur für Tests: eine schon offene Datenbank unterschieben.
  ///
  /// Der Dienst ist ein Singleton und öffnet sonst die Datei auf dem Gerät.
  /// Damit laufen die Dienste in Tests gegen eine Datenbank im Speicher –
  /// `null` gibt den Platz wieder frei.
  @visibleForTesting
  set databaseForTests(Database? db) => _database = db;

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'beebrain.db');

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Schema-Version. Bei Erhöhung immer auch [_onUpgrade] ergänzen, sonst
  /// verlieren bestehende Installationen beim Update ihre Tabellen.
  static const int _dbVersion = 7;

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    FeedbackService.log('🗄️ SQLite-Migration $oldVersion → $newVersion');
    if (oldVersion < 2) {
      await _createHiveActionsTable(db);
    }
    if (oldVersion < 3) {
      // Bei einer Neuanlage ab v3 ist die Spalte schon im CREATE enthalten,
      // deshalb nur ergänzen, wenn sie fehlt.
      await addColumnIfMissing(db, 'hive_actions', 'season_task', 'TEXT');
    }
    if (oldVersion < 4) {
      await addColumnIfMissing(db, 'hives', 'position', 'TEXT');
    }
    if (oldVersion < 5) {
      await createStockTables(db);
    }
    if (oldVersion < 6) {
      await migrateHoneyStatesToTicks(db);
    }
    if (oldVersion < 7) {
      await createPersonalizationTables(db);
    }
  }

  /// Schritt auf v6: Die Eimer-Zustände werden eine Hakenliste.
  ///
  /// „noch zu impfen" und „noch zu rühren" fallen weg – in einer Hakenliste
  /// sagt das leere Kästchen das schon. Grob kristallin und kandiert sind
  /// keine Schritte mehr, sondern eine Markierung neben der Liste: sie wandern
  /// in die neue Spalte, und der Eimer geht auf den ersten Haken zurück, genau
  /// wie nach dem Melitherm.
  ///
  /// Die Abbildung kommt aus [HoneyStates.legacy], damit Dart und SQLite nicht
  /// auseinanderlaufen können.
  ///
  /// Der Verlauf in `honey_bucket_events` bleibt unangetastet: dort steht, was
  /// damals geschah, und das umzuschreiben wäre Geschichtsfälschung. Beim
  /// Anzeigen bringt [HoneyStates.normalize] die alten Werte auf die heutigen
  /// Beschriftungen.
  @visibleForTesting
  static Future<void> migrateHoneyStatesToTicks(Database db) async {
    await addColumnIfMissing(db, 'honey_buckets', 'crystallization', 'TEXT');

    // Zuerst die Markierung aus dem alten Zustand retten, sonst ist die
    // Information nach dem Umschreiben verloren.
    final markiert = await db.rawUpdate(
      'UPDATE honey_buckets SET crystallization = state WHERE state IN (?, ?)',
      [HoneyCrystallization.coarse, HoneyCrystallization.solid],
    );

    var umgeschrieben = 0;
    for (final paar in HoneyStates.legacy.entries) {
      umgeschrieben += await db.rawUpdate(
        'UPDATE honey_buckets SET state = ? WHERE state = ?',
        [paar.value, paar.key],
      );
    }
    FeedbackService.log(
        '🗄️ Eimer-Zustände auf Haken umgestellt: $umgeschrieben Eimer, '
        'davon $markiert kristallin');
  }

  /// Spalte nachrüsten. SQLite kennt kein `ADD COLUMN IF NOT EXISTS`, ein
  /// zweiter Versuch würde also mit einem Fehler abbrechen.
  @visibleForTesting
  static Future<void> addColumnIfMissing(
      Database db, String table, String column, String type) async {
    final spalten = await db.rawQuery('PRAGMA table_info($table)');
    final vorhanden = spalten.any((s) => s['name'] == column);
    if (vorhanden) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    FeedbackService.log('🗄️ Spalte $table.$column ergänzt');
  }

  /// DDL der Maßnahmen-Tabelle. Als Konstante, damit Neuanlage, Migration
  /// und Test garantiert dasselbe Schema verwenden.
  @visibleForTesting
  static const String hiveActionsTableSql = '''
      CREATE TABLE IF NOT EXISTS hive_actions (
        id TEXT PRIMARY KEY,
        hive_id TEXT NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        note TEXT,
        brood_frames INTEGER,
        bee_frames INTEGER,
        temper INTEGER,
        queen_seen INTEGER,
        swarm_cells INTEGER,
        amount REAL,
        unit TEXT,
        treatment TEXT,
        photo_paths TEXT,
        season_task TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''';

  @visibleForTesting
  static const String hiveActionsIndexSql =
      'CREATE INDEX IF NOT EXISTS idx_hive_actions_hive '
      'ON hive_actions (hive_id, date DESC)';

  Future<void> _createHiveActionsTable(Database db) async {
    await db.execute(hiveActionsTableSql);
    await db.execute(hiveActionsIndexSql);
  }

  /// DDL des Lagers. Der Bestand ist keine Spalte: Er ergibt sich aus der
  /// Summe der Bewegungen, damit es zu jedem Bestand eine Historie gibt.
  @visibleForTesting
  static const String stockItemsTableSql = '''
      CREATE TABLE IF NOT EXISTS stock_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        unit TEXT NOT NULL,
        min_quantity REAL,
        price_per_unit REAL,
        variety TEXT,
        jar_size_g INTEGER,
        note TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''';

  @visibleForTesting
  static const String stockMovementsTableSql = '''
      CREATE TABLE IF NOT EXISTS stock_movements (
        id TEXT PRIMARY KEY,
        item_id TEXT NOT NULL,
        date TEXT NOT NULL,
        quantity REAL NOT NULL,
        reason TEXT NOT NULL,
        note TEXT,
        hive_action_id TEXT,
        invoice_id TEXT,
        created_at TEXT,
        FOREIGN KEY (item_id) REFERENCES stock_items (id) ON DELETE CASCADE
      )
    ''';

  @visibleForTesting
  static const String stockMovementsIndexSql =
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_item '
      'ON stock_movements (item_id, date DESC)';

  /// DDL der Honig-Eimer. Ein Eimer ist ein Einzelstück: eigene Sorte,
  /// eigenes Erntedatum, eigener Zustand, eigener Platz. Der aktuelle
  /// Inhalt ist keine Spalte – er ergibt sich aus der Einwaage minus allem,
  /// was abgefüllt wurde.
  @visibleForTesting
  static const String honeyBucketsTableSql = '''
      CREATE TABLE IF NOT EXISTS honey_buckets (
        id TEXT PRIMARY KEY,
        code TEXT UNIQUE NOT NULL,
        number INTEGER NOT NULL,
        variety TEXT NOT NULL,
        variety_name TEXT,
        harvest_date TEXT NOT NULL,
        bucket_size_kg REAL,
        filled_kg REAL NOT NULL,
        water_content REAL,
        state TEXT NOT NULL,
        crystallization TEXT,
        location TEXT,
        label_photo TEXT,
        note TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''';

  /// DDL des Eimer-Verlaufs. Ein Protokoll mit typabhängig leeren Spalten,
  /// wie es [hiveActionsTableSql] für die Stockkarte eines Volkes verwendet.
  @visibleForTesting
  static const String honeyEventsTableSql = '''
      CREATE TABLE IF NOT EXISTS honey_bucket_events (
        id TEXT PRIMARY KEY,
        bucket_id TEXT NOT NULL,
        date TEXT NOT NULL,
        kind TEXT NOT NULL,
        state TEXT,
        removed_kg REAL,
        jar_item_id TEXT,
        jar_count INTEGER,
        location TEXT,
        note TEXT,
        photo TEXT,
        created_at TEXT,
        FOREIGN KEY (bucket_id) REFERENCES honey_buckets (id) ON DELETE CASCADE
      )
    ''';

  @visibleForTesting
  static const String honeyEventsIndexSql =
      'CREATE INDEX IF NOT EXISTS idx_honey_events_bucket '
      'ON honey_bucket_events (bucket_id, date DESC)';

  /// Der Migrationsschritt auf Version 5, vollständig. Als statische
  /// Methode, damit ein Test genau diesen Schritt gegen eine echte
  /// Datenbank fahren kann statt die Reihenfolge nachzubauen.
  @visibleForTesting
  /// DDL der anpassbaren Verzeichnisse.
  ///
  /// Eine Tabelle für alle sechs Verzeichnisse, mit typabhängig leeren
  /// Spalten – `marks` und `needs_attention` bedeuten nur bei den
  /// Honig-Zuständen etwas, `direction` nur bei den Buchungsgründen. Dasselbe
  /// Muster wie beim Eimer-Verlauf.
  ///
  /// `entry_key` statt `key`: KEY ist in SQL ein Schlüsselwort, und ein
  /// Spaltenname, der je nach Stelle anders gelesen wird, ist eine Falle.
  @visibleForTesting
  static const String catalogEntriesTableSql = '''
      CREATE TABLE IF NOT EXISTS catalog_entries (
        catalog TEXT NOT NULL,
        entry_key TEXT NOT NULL,
        label TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        color INTEGER,
        marks TEXT,
        needs_attention INTEGER,
        direction TEXT,
        archived INTEGER NOT NULL DEFAULT 0,
        built_in INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (catalog, entry_key)
      )
    ''';

  /// DDL der einstellbaren Zahlen und Schalter.
  ///
  /// Alles als Text gespeichert, gelesen wird mit `double.tryParse`: ein
  /// Wert, der nicht lesbar ist, fällt damit auf die Vorgabe zurück statt die
  /// App zu zerlegen.
  @visibleForTesting
  static const String appSettingsTableSql = '''
      CREATE TABLE IF NOT EXISTS app_settings (
        name TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''';

  /// Schritt auf v7: die Tabellen für die anpassbaren Verzeichnisse.
  ///
  /// Gesät werden sie nicht hier, sondern beim Start durch den
  /// PersonalizationService – der kennt die Werkseinstellung, und so gilt für
  /// Neuanlage und Migration derselbe Weg.
  @visibleForTesting
  static Future<void> createPersonalizationTables(Database db) async {
    await db.execute(catalogEntriesTableSql);
    await db.execute(appSettingsTableSql);
  }

  static Future<void> createStockTables(Database db) async {
    await db.execute(stockItemsTableSql);
    await db.execute(stockMovementsTableSql);
    await db.execute(stockMovementsIndexSql);
    await db.execute(honeyBucketsTableSql);
    await db.execute(honeyEventsTableSql);
    await db.execute(honeyEventsIndexSql);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE companies (
        id TEXT PRIMARY KEY,
        name TEXT,
        email TEXT,
        street TEXT,
        city TEXT,
        zipcode TEXT,
        phone TEXT,
        tax_id TEXT,
        website TEXT,
        account_holder TEXT,
        iban TEXT,
        bic TEXT,
        bank TEXT,
        paypal TEXT,
        invoice_number_pattern TEXT DEFAULT 'RE-{YEAR}-{SEQ:3}',
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        customer_number INTEGER,
        name TEXT,
        street TEXT,
        city TEXT,
        zipcode TEXT,
        phone TEXT,
        email TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        invoice_number TEXT,
        company_id TEXT,
        customer_id TEXT,
        date TEXT,
        payment_terms INTEGER DEFAULT 14,
        additional_info TEXT,
        tax_rate REAL,
        subtotal REAL,
        vat REAL,
        total REAL,
        synced INTEGER DEFAULT 0,
        header_text TEXT,
        header_text_size INTEGER DEFAULT 24,
        is_gross_price INTEGER DEFAULT 1,
        status TEXT DEFAULT 'draft',
        document_type TEXT DEFAULT 'invoice',
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        description TEXT,
        quantity REAL,
        unit TEXT,
        price REAL,
        tax_rate REAL,
        created_at TEXT,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE design_settings (
        id TEXT PRIMARY KEY,
        company_id TEXT,
        header_text_color TEXT,
        header_text_size INTEGER,
        logo_url TEXT,
        top_header_url TEXT,
        logo_x REAL,
        logo_y REAL,
        header_x REAL,
        header_y REAL,
        header_width REAL,
        header_height REAL,
        layout_json TEXT,
        table_header_color TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE address_templates (
        id TEXT PRIMARY KEY,
        company_id TEXT,
        name TEXT,
        street TEXT,
        city TEXT,
        zipcode TEXT,
        phone TEXT,
        email TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE articles (
        id TEXT PRIMARY KEY,
        description TEXT,
        quantity REAL,
        unit TEXT,
        price REAL,
        tax_rate REAL,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE letters (
        id TEXT PRIMARY KEY,
        company_id TEXT,
        customer_id TEXT,
        letter_form TEXT,
        envelope_format TEXT,
        letter_date TEXT,
        location TEXT,
        ref_your TEXT,
        ref_your_date TEXT,
        ref_our TEXT,
        ref_our_date TEXT,
        subject TEXT,
        salutation TEXT,
        body TEXT,
        closing TEXT,
        signer_name TEXT,
        recipient_zusatz TEXT,
        recipient_name TEXT,
        recipient_street TEXT,
        recipient_city TEXT,
        recipient_country TEXT,
        show_fold_marks INTEGER DEFAULT 1,
        show_punch_mark INTEGER DEFAULT 1,
        status TEXT DEFAULT 'draft',
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE hives (
        id TEXT PRIMARY KEY,
        number INTEGER,
        name TEXT,
        qr_id TEXT UNIQUE,
        queen_year INTEGER,
        queen_origin TEXT,
        location TEXT,
        position TEXT,
        status TEXT DEFAULT 'aktiv',
        notes TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await _createHiveActionsTable(db);
    await createStockTables(db);
    await createPersonalizationTables(db);

    FeedbackService.log('🗄️ SQLite-Schema erstellt (v$_dbVersion)');
  }

  // ============ COMPANY OPERATIONS ============

  Future<void> insertCompany(CompanyModel company) async {
    try {
      final db = await database;
      await db.insert(
        'companies',
        company.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      FeedbackService.logDbOperation('INSERT', 'companies', id: company.id);
    } catch (e) {
      FeedbackService.logError('insertCompany: $e', context: 'companies');
      rethrow;
    }
  }

  Future<CompanyModel?> getCompany(String id) async {
    final db = await database;
    final result = await db.query('companies', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? CompanyModel.fromMap(result.first) : null;
  }

  Future<List<CompanyModel>> getAllCompanies() async {
    try {
      final db = await database;
      final result = await db.query('companies');
      return result.map((map) => CompanyModel.fromMap(map)).toList();
    } catch (e) {
      FeedbackService.logApiCall('/companies', 'GET', error: e.toString());
      return [];
    }
  }

  Future<void> updateCompany(CompanyModel company) async {
    try {
      final db = await database;
      await db.update(
        'companies',
        company.toMap(),
        where: 'id = ?',
        whereArgs: [company.id],
      );
      FeedbackService.logDbOperation('UPDATE', 'companies', id: company.id);
    } catch (e) {
      FeedbackService.logError('updateCompany: $e', context: 'companies');
      rethrow;
    }
  }

  Future<void> deleteCompany(String id) async {
    final db = await database;
    await db.delete('companies', where: 'id = ?', whereArgs: [id]);
    FeedbackService.logDbOperation('DELETE', 'companies', id: id);
  }

  // ============ CUSTOMER OPERATIONS ============

  Future<void> insertCustomer(CustomerModel customer) async {
    try {
      final db = await database;
      var data = customer.toMap();
      if (customer.customerNumber == null) {
        final next = await getNextCustomerNumber();
        data['customer_number'] = next;
      }
      await db.insert(
        'customers',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      FeedbackService.logDbOperation('INSERT', 'customers', id: customer.id);
    } catch (e) {
      FeedbackService.logError('insertCustomer: $e', context: 'customers');
      rethrow;
    }
  }

  Future<int> getNextCustomerNumber() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
          'SELECT MAX(customer_number) as max_num FROM customers');
      final current = result.first['max_num'] as int?;
      return (current ?? 0) + 1;
    } catch (_) {
      return 1;
    }
  }

  Future<CustomerModel?> getCustomer(String id) async {
    final db = await database;
    final result = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? CustomerModel.fromMap(result.first) : null;
  }

  Future<List<CustomerModel>> getAllCustomers() async {
    try {
      final db = await database;
      final result = await db.query('customers');
      return result.map((map) => CustomerModel.fromMap(map)).toList();
    } catch (e) {
      FeedbackService.logApiCall('/customers', 'GET', error: e.toString());
      return [];
    }
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    final db = await database;
    await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
    FeedbackService.logDbOperation('UPDATE', 'customers', id: customer.id);
  }

  Future<void> deleteCustomer(String id) async {
    final db = await database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
    FeedbackService.logDbOperation('DELETE', 'customers', id: id);
  }

  // ============ INVOICE OPERATIONS ============

  Future<void> insertInvoice(InvoiceModel invoice) async {
    try {
      final db = await database;
      await db.insert(
        'invoices',
        invoice.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      FeedbackService.logDbOperation('INSERT', 'invoices', id: invoice.id);
    } catch (e) {
      FeedbackService.logError('insertInvoice: $e', context: 'invoices');
      rethrow;
    }
  }

  Future<InvoiceModel?> getInvoice(String id) async {
    final db = await database;
    final result = await db.query('invoices', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? InvoiceModel.fromMap(result.first) : null;
  }

  Future<InvoiceModel?> getInvoiceByNumber(String invoiceNumber) async {
    final db = await database;
    final result = await db.query(
      'invoices',
      where: 'invoice_number = ?',
      whereArgs: [invoiceNumber],
    );
    return result.isNotEmpty ? InvoiceModel.fromMap(result.first) : null;
  }

  Future<List<InvoiceModel>> getInvoicesByCompany(String companyId) async {
    final db = await database;
    final result = await db.query(
      'invoices',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'date DESC',
    );
    return result.map((map) => InvoiceModel.fromMap(map)).toList();
  }

  Future<List<InvoiceModel>> getAllInvoices() async {
    try {
      final db = await database;
      final result = await db.query('invoices', orderBy: 'date DESC');
      return result.map((map) => InvoiceModel.fromMap(map)).toList();
    } catch (e) {
      FeedbackService.logApiCall('/invoices', 'GET', error: e.toString());
      return [];
    }
  }

  /// Offline-only → immer leer.
  Future<List<InvoiceModel>> getUnsyncedInvoices() async => [];

  Future<void> updateInvoice(InvoiceModel invoice) async {
    final db = await database;
    await db.update(
      'invoices',
      invoice.toMap(),
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
    FeedbackService.logDbOperation('UPDATE', 'invoices', id: invoice.id);
  }

  Future<void> deleteInvoice(String id) async {
    final db = await database;
    await db.delete('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
    await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
    FeedbackService.logDbOperation('DELETE', 'invoices', id: id);
  }

  Future<void> updateInvoiceStatus(String id, String status) async {
    try {
      final db = await database;
      await db.update(
        'invoices',
        {'status': status},
        where: 'id = ?',
        whereArgs: [id],
      );
      FeedbackService.logDbOperation('UPDATE_STATUS', 'invoices', id: id);
    } catch (e) {
      FeedbackService.logError('updateInvoiceStatus: $e', context: 'invoices');
      rethrow;
    }
  }

  Future<String?> getLastInvoiceNumber() async {
    final db = await database;
    final result = await db.query(
      'invoices',
      columns: ['invoice_number'],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return result.isNotEmpty ? result.first['invoice_number'] as String? : null;
  }

  Future<List<String>> getAllInvoiceNumbers() async {
    final db = await database;
    final result = await db.query('invoices', columns: ['invoice_number']);
    return result
        .map((r) => r['invoice_number'] as String)
        .where((n) => n.isNotEmpty)
        .toList();
  }

  // ============ INVOICE ITEM OPERATIONS ============

  Future<void> insertInvoiceItem(InvoiceItemModel item) async {
    final db = await database;
    await db.insert(
      'invoice_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<InvoiceItemModel>> getInvoiceItems(String invoiceId) async {
    final db = await database;
    final result = await db.query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'created_at ASC',
    );
    return result.map((map) => InvoiceItemModel.fromMap(map)).toList();
  }

  Future<void> updateInvoiceItem(InvoiceItemModel item) async {
    final db = await database;
    await db.update(
      'invoice_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteInvoiceItem(String id) async {
    final db = await database;
    await db.delete('invoice_items', where: 'id = ?', whereArgs: [id]);
  }

  // ============ ARTICLE TEMPLATE OPERATIONS ============

  Future<List<InvoiceItemModel>> getAllArticles() async {
    try {
      final db = await database;
      final result = await db.query('articles', orderBy: 'created_at DESC');
      return result.map((map) => InvoiceItemModel.fromMap({
            ...map,
            'invoice_id': '',
          })).toList();
    } catch (e) {
      FeedbackService.logError('getAllArticles: $e', context: 'articles');
      rethrow;
    }
  }

  Future<void> insertArticle(InvoiceItemModel article) async {
    final db = await database;
    await db.insert(
      'articles',
      {
        'id': article.id,
        'description': article.description,
        'quantity': article.quantity,
        'unit': article.unit,
        'price': article.price,
        'tax_rate': article.taxRate,
        'created_at': article.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    FeedbackService.logDbOperation('INSERT', 'articles', id: article.id);
  }

  Future<void> updateArticle(InvoiceItemModel article) async {
    final db = await database;
    await db.update(
      'articles',
      {
        'description': article.description,
        'quantity': article.quantity,
        'unit': article.unit,
        'price': article.price,
        'tax_rate': article.taxRate,
      },
      where: 'id = ?',
      whereArgs: [article.id],
    );
    FeedbackService.logDbOperation('UPDATE', 'articles', id: article.id);
  }

  Future<void> deleteArticle(String id) async {
    final db = await database;
    await db.delete('articles', where: 'id = ?', whereArgs: [id]);
    FeedbackService.logDbOperation('DELETE', 'articles', id: id);
  }

  // ============ DESIGN SETTINGS OPERATIONS ============

  Future<void> insertDesignSettings(DesignSettingsModel settings) async {
    try {
      final db = await database;
      await db.insert(
        'design_settings',
        settings.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      FeedbackService.logDbOperation('UPSERT', 'design_settings',
          id: settings.companyId);
    } catch (e) {
      FeedbackService.logError('insertDesignSettings: $e',
          context: 'design_settings');
      rethrow;
    }
  }

  Future<DesignSettingsModel?> getDesignSettings(String companyId) async {
    final db = await database;
    final result = await db.query(
      'design_settings',
      where: 'company_id = ?',
      whereArgs: [companyId],
    );
    return result.isNotEmpty ? DesignSettingsModel.fromMap(result.first) : null;
  }

  Future<void> updateDesignSettings(DesignSettingsModel settings) async {
    final db = await database;
    await db.update(
      'design_settings',
      settings.toMap(),
      where: 'company_id = ?',
      whereArgs: [settings.companyId],
    );
    FeedbackService.logDbOperation('UPDATE', 'design_settings',
        id: settings.companyId);
  }

  // ============ ADDRESS TEMPLATE OPERATIONS ============

  Future<void> insertAddressTemplate(AddressTemplateModel template) async {
    final db = await database;
    await db.insert(
      'address_templates',
      template.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AddressTemplateModel>> getAddressTemplates(
      String companyId) async {
    final db = await database;
    final result = await db.query(
      'address_templates',
      where: 'company_id = ?',
      whereArgs: [companyId],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => AddressTemplateModel.fromMap(map)).toList();
  }

  Future<void> updateAddressTemplate(AddressTemplateModel template) async {
    final db = await database;
    await db.update(
      'address_templates',
      template.toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }

  Future<void> deleteAddressTemplate(String id) async {
    final db = await database;
    await db.delete('address_templates', where: 'id = ?', whereArgs: [id]);
  }

  // ============ LETTER OPERATIONS ============

  Future<List<LetterModel>> getAllLetters() async {
    try {
      final db = await database;
      final result = await db.query('letters', orderBy: 'created_at DESC');
      return result.map((map) => LetterModel.fromMap(map)).toList();
    } catch (e) {
      FeedbackService.logError('getAllLetters: $e', context: 'letters');
      return [];
    }
  }

  Future<LetterModel?> getLetter(String id) async {
    final db = await database;
    final result = await db.query('letters', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? LetterModel.fromMap(result.first) : null;
  }

  Future<void> insertLetter(LetterModel letter) async {
    final db = await database;
    await db.insert(
      'letters',
      letter.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    FeedbackService.logDbOperation('INSERT', 'letters', id: letter.id);
  }

  Future<void> updateLetter(LetterModel letter) async {
    final db = await database;
    await db.update(
      'letters',
      letter.toMap(),
      where: 'id = ?',
      whereArgs: [letter.id],
    );
    FeedbackService.logDbOperation('UPDATE', 'letters', id: letter.id);
  }

  Future<void> deleteLetter(String id) async {
    final db = await database;
    await db.delete('letters', where: 'id = ?', whereArgs: [id]);
    FeedbackService.logDbOperation('DELETE', 'letters', id: id);
  }

  Future<void> updateLetterStatus(String id, String status) async {
    final db = await database;
    await db.update(
      'letters',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============ HIVE OPERATIONS (Imkerei) ============

  Future<List<HiveModel>> getAllHives() async {
    try {
      final db = await database;
      final result = await db.query('hives', orderBy: 'number ASC');
      return result.map((m) => HiveModel.fromMap(m)).toList();
    } catch (e) {
      FeedbackService.logError('getAllHives: $e', context: 'hives');
      return [];
    }
  }

  Future<HiveModel?> getHive(String id) async {
    final db = await database;
    final result = await db.query('hives', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? HiveModel.fromMap(result.first) : null;
  }

  Future<HiveModel?> getHiveByQrId(String qrId) async {
    final db = await database;
    final result =
        await db.query('hives', where: 'qr_id = ?', whereArgs: [qrId]);
    return result.isNotEmpty ? HiveModel.fromMap(result.first) : null;
  }

  Future<void> insertHive(HiveModel hive) async {
    final db = await database;
    await db.insert(
      'hives',
      hive.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    FeedbackService.logDbOperation('INSERT', 'hives', id: hive.id);
  }

  Future<void> updateHive(HiveModel hive) async {
    final db = await database;
    await db.update(
      'hives',
      hive.toMap(),
      where: 'id = ?',
      whereArgs: [hive.id],
    );
    FeedbackService.logDbOperation('UPDATE', 'hives', id: hive.id);
  }

  Future<void> deleteHive(String id) async {
    final db = await database;
    // Maßnahmen hängen am Volk und werden mitgelöscht (Fremdschlüssel sind
    // in sqflite standardmäßig nicht aktiv, deshalb explizit).
    await db.delete('hive_actions', where: 'hive_id = ?', whereArgs: [id]);
    await db.delete('hives', where: 'id = ?', whereArgs: [id]);
    FeedbackService.logDbOperation('DELETE', 'hives', id: id);
  }

  Future<int> getNextHiveNumber() async {
    try {
      final db = await database;
      final result =
          await db.rawQuery('SELECT MAX(number) as max_num FROM hives');
      final current = result.first['max_num'] as int?;
      return (current ?? 0) + 1;
    } catch (_) {
      return 1;
    }
  }

  // ============ HIVE ACTION OPERATIONS (Maßnahmen) ============

  /// Maßnahmen eines Volkes, neueste zuerst.
  Future<List<HiveActionModel>> getHiveActions(String hiveId) async {
    try {
      final db = await database;
      final result = await db.query(
        'hive_actions',
        where: 'hive_id = ?',
        whereArgs: [hiveId],
        orderBy: 'date DESC, created_at DESC',
      );
      return result.map((m) => HiveActionModel.fromMap(m)).toList();
    } catch (e) {
      FeedbackService.logError('getHiveActions: $e', context: 'hive_actions');
      return [];
    }
  }

  /// Alle Maßnahmen über alle Völker, neueste zuerst.
  Future<List<HiveActionModel>> getAllHiveActions({int? limit}) async {
    try {
      final db = await database;
      final result = await db.query(
        'hive_actions',
        orderBy: 'date DESC, created_at DESC',
        limit: limit,
      );
      return result.map((m) => HiveActionModel.fromMap(m)).toList();
    } catch (e) {
      FeedbackService.logError('getAllHiveActions: $e', context: 'hive_actions');
      return [];
    }
  }

  /// Jeweils jüngste Maßnahme je Volk – für die Völker-Übersicht.
  Future<Map<String, HiveActionModel>> getLatestActionPerHive() async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT a.* FROM hive_actions a
        JOIN (
          SELECT hive_id, MAX(date) AS max_date
          FROM hive_actions GROUP BY hive_id
        ) neueste
          ON a.hive_id = neueste.hive_id AND a.date = neueste.max_date
      ''');
      final map = <String, HiveActionModel>{};
      for (final row in result) {
        final action = HiveActionModel.fromMap(row);
        // Bei gleichem Datum gewinnt der zuletzt erfasste Eintrag.
        final vorhanden = map[action.hiveId];
        if (vorhanden == null ||
            action.createdAt.isAfter(vorhanden.createdAt)) {
          map[action.hiveId] = action;
        }
      }
      return map;
    } catch (e) {
      FeedbackService.logError('getLatestActionPerHive: $e',
          context: 'hive_actions');
      return {};
    }
  }

  Future<HiveActionModel?> getHiveAction(String id) async {
    final db = await database;
    final result =
        await db.query('hive_actions', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? HiveActionModel.fromMap(result.first) : null;
  }

  Future<void> insertHiveAction(HiveActionModel action) async {
    final db = await database;
    await db.insert(
      'hive_actions',
      action.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    FeedbackService.logDbOperation('INSERT', 'hive_actions', id: action.id);
  }

  Future<void> updateHiveAction(HiveActionModel action) async {
    final db = await database;
    await db.update(
      'hive_actions',
      action.toMap(),
      where: 'id = ?',
      whereArgs: [action.id],
    );
    FeedbackService.logDbOperation('UPDATE', 'hive_actions', id: action.id);
  }

  Future<void> deleteHiveAction(String id) async {
    final db = await database;
    await db.delete('hive_actions', where: 'id = ?', whereArgs: [id]);
    FeedbackService.logDbOperation('DELETE', 'hive_actions', id: id);
  }

  /// Anzahl Maßnahmen je Typ – Grundlage für Auswertungen.
  Future<Map<String, int>> countActionsByType() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT type, COUNT(*) AS anzahl FROM hive_actions GROUP BY type',
      );
      return {
        for (final r in result)
          r['type'] as String: (r['anzahl'] as num).toInt(),
      };
    } catch (e) {
      FeedbackService.logError('countActionsByType: $e',
          context: 'hive_actions');
      return {};
    }
  }

  // ============ STOCK OPERATIONS (Lager) ============

  Future<List<StockItemModel>> getAllStockItems() async {
    try {
      final db = await database;
      final result = await db.query('stock_items', orderBy: 'name COLLATE NOCASE ASC');
      return result.map((m) => StockItemModel.fromMap(m)).toList();
    } catch (e) {
      FeedbackService.logError('getAllStockItems: $e', context: 'stock_items');
      return [];
    }
  }

  Future<StockItemModel?> getStockItem(String id) async {
    final db = await database;
    final result =
        await db.query('stock_items', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? StockItemModel.fromMap(result.first) : null;
  }

  Future<void> insertStockItem(StockItemModel item) async {
    final db = await database;
    await db.insert(
      'stock_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    FeedbackService.logDbOperation('INSERT', 'stock_items', id: item.id);
  }

  Future<void> updateStockItem(StockItemModel item) async {
    final db = await database;
    await db.update(
      'stock_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    FeedbackService.logDbOperation('UPDATE', 'stock_items', id: item.id);
  }

  Future<void> deleteStockItem(String id) async {
    final db = await database;
    // Bewegungen hängen am Posten. Fremdschlüssel sind in sqflite
    // standardmäßig nicht aktiv, deshalb explizit löschen.
    await db.delete('stock_movements', where: 'item_id = ?', whereArgs: [id]);
    await db.delete('stock_items', where: 'id = ?', whereArgs: [id]);
    FeedbackService.logDbOperation('DELETE', 'stock_items', id: id);
  }

  /// Abfrage hinter [getStockBalances]. Als Konstante, damit ein Test
  /// genau die Abfrage prüft, die auch die App stellt.
  @visibleForTesting
  static const String stockBalancesSql =
      'SELECT item_id, SUM(quantity) AS bestand '
      'FROM stock_movements GROUP BY item_id';

  /// Bestand je Posten: die Summe aller Bewegungen.
  ///
  /// Posten ohne Bewegung fehlen in der Rückgabe – der Aufrufer behandelt
  /// einen fehlenden Eintrag als Bestand 0.
  Future<Map<String, double>> getStockBalances() async {
    try {
      final db = await database;
      final result = await db.rawQuery(stockBalancesSql);
      return {
        for (final r in result)
          r['item_id'] as String: (r['bestand'] as num?)?.toDouble() ?? 0,
      };
    } catch (e) {
      FeedbackService.logError('getStockBalances: $e',
          context: 'stock_movements');
      return {};
    }
  }

  /// Bewegungen eines Postens, neueste zuerst.
  Future<List<StockMovementModel>> getStockMovements(String itemId,
      {int? limit}) async {
    try {
      final db = await database;
      final result = await db.query(
        'stock_movements',
        where: 'item_id = ?',
        whereArgs: [itemId],
        orderBy: 'date DESC, created_at DESC',
        limit: limit,
      );
      return result.map((m) => StockMovementModel.fromMap(m)).toList();
    } catch (e) {
      FeedbackService.logError('getStockMovements: $e',
          context: 'stock_movements');
      return [];
    }
  }

  Future<void> insertStockMovement(StockMovementModel movement) async {
    final db = await database;
    await db.insert(
      'stock_movements',
      movement.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    FeedbackService.logDbOperation('INSERT', 'stock_movements',
        id: movement.id);
  }

  Future<void> deleteStockMovement(String id) async {
    final db = await database;
    await db.delete('stock_movements', where: 'id = ?', whereArgs: [id]);
    FeedbackService.logDbOperation('DELETE', 'stock_movements', id: id);
  }

  /// Bewegungen einer Maßnahme – damit eine geänderte oder gelöschte
  /// Maßnahme ihre Buchung nicht im Lager zurücklässt.
  Future<List<StockMovementModel>> getStockMovementsForAction(
      String hiveActionId) async {
    try {
      final db = await database;
      final result = await db.query(
        'stock_movements',
        where: 'hive_action_id = ?',
        whereArgs: [hiveActionId],
      );
      return result.map((m) => StockMovementModel.fromMap(m)).toList();
    } catch (e) {
      FeedbackService.logError('getStockMovementsForAction: $e',
          context: 'stock_movements');
      return [];
    }
  }

  Future<void> deleteStockMovementsForAction(String hiveActionId) async {
    final db = await database;
    await db.delete('stock_movements',
        where: 'hive_action_id = ?', whereArgs: [hiveActionId]);
  }

  /// Bewegungen, die zu einer Rechnung gehören. Grundlage dafür, dass eine
  /// zweimal gespeicherte Rechnung den Bestand nicht zweimal mindert.
  Future<List<StockMovementModel>> getStockMovementsForInvoice(
      String invoiceId) async {
    try {
      final db = await database;
      final result = await db.query(
        'stock_movements',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );
      return result.map((m) => StockMovementModel.fromMap(m)).toList();
    } catch (e) {
      FeedbackService.logError('getStockMovementsForInvoice: $e',
          context: 'stock_movements');
      return [];
    }
  }

  Future<void> deleteStockMovementsForInvoice(String invoiceId) async {
    final db = await database;
    await db.delete('stock_movements',
        where: 'invoice_id = ?', whereArgs: [invoiceId]);
  }

  // ============ HONEY BUCKET OPERATIONS (Eimer) ============

  /// Alle Eimer, neueste Ernte zuerst.
  Future<List<HoneyBucketModel>> getAllHoneyBuckets() async {
    try {
      final db = await database;
      final result = await db.query('honey_buckets',
          orderBy: 'harvest_date DESC, number DESC');
      return result.map((m) => HoneyBucketModel.fromMap(m)).toList();
    } catch (e) {
      FeedbackService.logError('getAllHoneyBuckets: $e',
          context: 'honey_buckets');
      return [];
    }
  }

  Future<HoneyBucketModel?> getHoneyBucket(String id) async {
    final db = await database;
    final result =
        await db.query('honey_buckets', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? HoneyBucketModel.fromMap(result.first) : null;
  }

  /// Eimer über den Code, der auf ihm steht – z.B. 'SO-042'.
  Future<HoneyBucketModel?> getHoneyBucketByCode(String code) async {
    final db = await database;
    final result =
        await db.query('honey_buckets', where: 'code = ?', whereArgs: [code]);
    return result.isNotEmpty ? HoneyBucketModel.fromMap(result.first) : null;
  }

  Future<void> insertHoneyBucket(HoneyBucketModel bucket) async {
    final db = await database;
    await db.insert(
      'honey_buckets',
      bucket.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    FeedbackService.logDbOperation('INSERT', 'honey_buckets', id: bucket.id);
  }

  Future<void> updateHoneyBucket(HoneyBucketModel bucket) async {
    final db = await database;
    await db.update(
      'honey_buckets',
      bucket.toMap(),
      where: 'id = ?',
      whereArgs: [bucket.id],
    );
    FeedbackService.logDbOperation('UPDATE', 'honey_buckets', id: bucket.id);
  }

  Future<void> deleteHoneyBucket(String id) async {
    final db = await database;
    // Der Verlauf hängt am Eimer. Fremdschlüssel sind in sqflite
    // standardmäßig nicht aktiv, deshalb explizit löschen.
    await db
        .delete('honey_bucket_events', where: 'bucket_id = ?', whereArgs: [id]);
    await db.delete('honey_buckets', where: 'id = ?', whereArgs: [id]);
    FeedbackService.logDbOperation('DELETE', 'honey_buckets', id: id);
  }

  /// Höchste bisher vergebene Eimernummer. 0, wenn es keine gibt.
  ///
  /// Die Nummer ist global laufend, nicht je Sorte: Dadurch genügen die
  /// drei Ziffern zur Identifikation, auch wenn das Sortenkürzel auf dem
  /// Eimer verwischt ist.
  Future<int> getHighestBucketNumber() async {
    try {
      final db = await database;
      final result = await db
          .rawQuery('SELECT MAX(number) AS max_num FROM honey_buckets');
      return (result.first['max_num'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Alle vergebenen Codes – Grundlage für den Abgleich einer Kamera-Lesung.
  Future<List<String>> getAllBucketCodes() async {
    try {
      final db = await database;
      final result = await db.query('honey_buckets', columns: ['code']);
      return result
          .map((r) => (r['code'] as String?) ?? '')
          .where((c) => c.isNotEmpty)
          .toList();
    } catch (e) {
      FeedbackService.logError('getAllBucketCodes: $e',
          context: 'honey_buckets');
      return [];
    }
  }

  /// Verlauf eines Eimers, neuestes Ereignis zuerst.
  Future<List<HoneyBucketEventModel>> getHoneyEvents(String bucketId) async {
    try {
      final db = await database;
      final result = await db.query(
        'honey_bucket_events',
        where: 'bucket_id = ?',
        whereArgs: [bucketId],
        orderBy: 'date DESC, created_at DESC',
      );
      return result.map((m) => HoneyBucketEventModel.fromMap(m)).toList();
    } catch (e) {
      FeedbackService.logError('getHoneyEvents: $e',
          context: 'honey_bucket_events');
      return [];
    }
  }

  /// Abfrage hinter [getBottledKgPerBucket]. Erwartet die Ereignisart als
  /// Parameter. Als Konstante, damit ein Test dieselbe Abfrage prüft.
  @visibleForTesting
  static const String bottledKgSql =
      'SELECT bucket_id, SUM(removed_kg) AS entnommen '
      'FROM honey_bucket_events WHERE kind = ? GROUP BY bucket_id';

  /// Abgefüllte Menge je Eimer. Eimer ohne Abfüllung fehlen in der Rückgabe –
  /// der Aufrufer behandelt einen fehlenden Eintrag als 0.
  Future<Map<String, double>> getBottledKgPerBucket() async {
    try {
      final db = await database;
      final result =
          await db.rawQuery(bottledKgSql, [HoneyEventKinds.bottling]);
      return {
        for (final r in result)
          r['bucket_id'] as String:
              (r['entnommen'] as num?)?.toDouble() ?? 0,
      };
    } catch (e) {
      FeedbackService.logError('getBottledKgPerBucket: $e',
          context: 'honey_bucket_events');
      return {};
    }
  }

  Future<void> insertHoneyEvent(HoneyBucketEventModel event) async {
    final db = await database;
    await db.insert(
      'honey_bucket_events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    FeedbackService.logDbOperation('INSERT', 'honey_bucket_events',
        id: event.id);
  }

  Future<void> deleteHoneyEvent(String id) async {
    final db = await database;
    await db.delete('honey_bucket_events', where: 'id = ?', whereArgs: [id]);
    FeedbackService.logDbOperation('DELETE', 'honey_bucket_events', id: id);
  }

  // ============ UTILITY OPERATIONS ============

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('invoice_items');
    await db.delete('invoices');
    await db.delete('customers');
    await db.delete('address_templates');
    await db.delete('design_settings');
    await db.delete('companies');
    await db.delete('letters');
    await db.delete('hive_actions');
    await db.delete('hives');
    await db.delete('articles');
    await db.delete('stock_movements');
    await db.delete('stock_items');
    await db.delete('honey_bucket_events');
    await db.delete('honey_buckets');
    FeedbackService.log('🗄️ Alle Daten gelöscht');
  }

  Future<void> closeDatabase() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

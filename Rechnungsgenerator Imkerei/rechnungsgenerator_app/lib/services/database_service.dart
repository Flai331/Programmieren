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

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'beebrain.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
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
        status TEXT DEFAULT 'aktiv',
        notes TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    FeedbackService.log('🗄️ SQLite-Schema erstellt (v1)');
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
    await db.delete('hives');
    await db.delete('articles');
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

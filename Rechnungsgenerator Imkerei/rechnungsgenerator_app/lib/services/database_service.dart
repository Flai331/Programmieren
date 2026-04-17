import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseService {
  static const String _dbName = 'rechnungsgenerator.db';
  static const int _dbVersion = 1;

  static final DatabaseService _instance = DatabaseService._internal();

  Database? _database;

  DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Companies table
    await db.execute('''
      CREATE TABLE companies (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        street TEXT NOT NULL,
        city TEXT NOT NULL,
        zipcode TEXT NOT NULL,
        phone TEXT NOT NULL,
        tax_id TEXT,
        website TEXT,
        account_holder TEXT,
        iban TEXT,
        bic TEXT,
        bank TEXT,
        paypal TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // Customers table
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        street TEXT NOT NULL,
        city TEXT NOT NULL,
        zipcode TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // Invoices table
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        invoice_number TEXT NOT NULL UNIQUE,
        company_id TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        date TEXT NOT NULL,
        payment_terms INTEGER NOT NULL,
        additional_info TEXT,
        tax_rate REAL NOT NULL,
        subtotal REAL NOT NULL,
        vat REAL NOT NULL,
        total REAL NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (company_id) REFERENCES companies(id),
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    // Invoice Items table
    await db.execute('''
      CREATE TABLE invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        description TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        price REAL NOT NULL,
        tax_rate REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id)
      )
    ''');

    // Design Settings table
    await db.execute('''
      CREATE TABLE design_settings (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL UNIQUE,
        header_text_color TEXT NOT NULL DEFAULT '#000000',
        header_text_size INTEGER NOT NULL DEFAULT 16,
        logo_url TEXT,
        top_header_url TEXT,
        logo_x REAL,
        logo_y REAL,
        header_x REAL,
        header_y REAL,
        header_width REAL,
        header_height REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (company_id) REFERENCES companies(id)
      )
    ''');

    // Address Templates table
    await db.execute('''
      CREATE TABLE address_templates (
        id TEXT PRIMARY KEY,
        company_id TEXT NOT NULL,
        name TEXT NOT NULL,
        street TEXT NOT NULL,
        city TEXT NOT NULL,
        zipcode TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (company_id) REFERENCES companies(id)
      )
    ''');

    // Create indices for faster queries
    await db.execute('CREATE INDEX idx_invoices_company_id ON invoices(company_id)');
    await db.execute('CREATE INDEX idx_invoices_customer_id ON invoices(customer_id)');
    await db.execute('CREATE INDEX idx_invoice_items_invoice_id ON invoice_items(invoice_id)');
    await db.execute('CREATE INDEX idx_address_templates_company_id ON address_templates(company_id)');
  }

  // ============ COMPANY OPERATIONS ============

  Future<void> insertCompany(CompanyModel company) async {
    final db = await database;
    await db.insert(
      'companies',
      company.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<CompanyModel?> getCompany(String id) async {
    final db = await database;
    final result = await db.query(
      'companies',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? CompanyModel.fromMap(result.first) : null;
  }

  Future<List<CompanyModel>> getAllCompanies() async {
    final db = await database;
    final result = await db.query('companies');
    return result.map((map) => CompanyModel.fromMap(map)).toList();
  }

  Future<void> updateCompany(CompanyModel company) async {
    final db = await database;
    await db.update(
      'companies',
      company.toMap(),
      where: 'id = ?',
      whereArgs: [company.id],
    );
  }

  Future<void> deleteCompany(String id) async {
    final db = await database;
    await db.delete('companies', where: 'id = ?', whereArgs: [id]);
  }

  // ============ CUSTOMER OPERATIONS ============

  Future<void> insertCustomer(CustomerModel customer) async {
    final db = await database;
    await db.insert(
      'customers',
      customer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<CustomerModel?> getCustomer(String id) async {
    final db = await database;
    final result = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? CustomerModel.fromMap(result.first) : null;
  }

  Future<List<CustomerModel>> getAllCustomers() async {
    final db = await database;
    final result = await db.query('customers');
    return result.map((map) => CustomerModel.fromMap(map)).toList();
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    final db = await database;
    await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<void> deleteCustomer(String id) async {
    final db = await database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  // ============ INVOICE OPERATIONS ============

  Future<void> insertInvoice(InvoiceModel invoice) async {
    final db = await database;
    await db.insert(
      'invoices',
      invoice.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<InvoiceModel?> getInvoice(String id) async {
    final db = await database;
    final result = await db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [id],
    );
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
    final db = await database;
    final result = await db.query('invoices', orderBy: 'date DESC');
    return result.map((map) => InvoiceModel.fromMap(map)).toList();
  }

  Future<List<InvoiceModel>> getUnsyncedInvoices() async {
    final db = await database;
    final result = await db.query(
      'invoices',
      where: 'synced = ?',
      whereArgs: [0],
    );
    return result.map((map) => InvoiceModel.fromMap(map)).toList();
  }

  Future<void> updateInvoice(InvoiceModel invoice) async {
    final db = await database;
    await db.update(
      'invoices',
      invoice.toMap(),
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
  }

  Future<void> deleteInvoice(String id) async {
    final db = await database;
    // Delete items first
    await db.delete('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
    // Then invoice
    await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  Future<String?> getLastInvoiceNumber() async {
    final db = await database;
    final result = await db.query(
      'invoices',
      columns: ['invoice_number'],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return result.isNotEmpty ? result.first['invoice_number'] as String : null;
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

  // ============ DESIGN SETTINGS OPERATIONS ============

  Future<void> insertDesignSettings(DesignSettingsModel settings) async {
    final db = await database;
    await db.insert(
      'design_settings',
      settings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

  Future<List<AddressTemplateModel>> getAddressTemplates(String companyId) async {
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

  // ============ UTILITY OPERATIONS ============

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('invoice_items');
    await db.delete('invoices');
    await db.delete('customers');
    await db.delete('address_templates');
    await db.delete('design_settings');
    await db.delete('companies');
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

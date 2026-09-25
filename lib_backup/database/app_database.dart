import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final path = p.join(await getDatabasesPath(), 'ultra_enterprise.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE units(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL,
            name TEXT NOT NULL,
            status TEXT DEFAULT 'ACTIVE'
          )
        ''');
        await db.execute('''
          CREATE TABLE customers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_code TEXT,
            customer_name TEXT NOT NULL,
            primary_mobile TEXT,
            email TEXT,
            address TEXT,
            city TEXT,
            postal_pincode TEXT,
            gstin TEXT,
            opening_balance_cr REAL DEFAULT 0,
            opening_balance_dr REAL DEFAULT 0,
            bank_name TEXT,
            bank_account_no TEXT,
            ifsc_code TEXT,
            branch_address TEXT,
            shipping_contact_mobile TEXT,
            shipping_address TEXT,
            shipping_city TEXT,
            shipping_pincode TEXT,
            shipping_gstin TEXT,
            status TEXT DEFAULT 'ACTIVE'
          )
        ''');
        await db.execute('''
          CREATE TABLE products(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_code TEXT,
            product_name TEXT NOT NULL,
            unit_id INTEGER,
            hsn TEXT,
            rate REAL DEFAULT 0,
            opening_stock REAL DEFAULT 0,
            current_stock REAL DEFAULT 0,
            reorder_level REAL DEFAULT 0,
            status TEXT DEFAULT 'ACTIVE'
          )
        ''');
        await db.execute('''
          CREATE TABLE sales_invoices(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT NOT NULL UNIQUE,
            invoice_no INTEGER,
            transaction_date TEXT,
            po_no TEXT,
            po_date TEXT,
            state_zone TEXT,
            challan_no TEXT,
            challan_date TEXT,
            total_packages INTEGER DEFAULT 0,
            vehicle_dispatch_mode TEXT,
            due_days INTEGER DEFAULT 0,
            eway_bill_no TEXT,
            customer_id INTEGER,
            taxable_total REAL DEFAULT 0,
            cgst_total REAL DEFAULT 0,
            sgst_total REAL DEFAULT 0,
            igst_total REAL DEFAULT 0,
            grand_total REAL DEFAULT 0,
            status TEXT DEFAULT 'DRAFT'
          )
        ''');
        await db.execute('''
          CREATE TABLE sales_invoice_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_id INTEGER,
            product_id INTEGER,
            description TEXT,
            uom TEXT,
            hsn TEXT,
            quantity REAL,
            rate REAL,
            cgst_percent REAL,
            sgst_percent REAL,
            igst_percent REAL,
            taxable REAL,
            cgst REAL,
            sgst REAL,
            igst REAL,
            total REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_queue(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity_type TEXT,
            entity_id INTEGER,
            payload TEXT,
            status TEXT DEFAULT 'PENDING',
            created_at TEXT
          )
        ''');

        await db.insert('units', {'code': 'PCS', 'name': 'Pieces'});
        await db.insert('units', {'code': 'BOX', 'name': 'Box'});
        await db.insert('customers', {
          'customer_code': 'CUST001',
          'customer_name': 'Test Customer',
          'address': 'Test Address',
          'city': 'Chennai',
          'postal_pincode': '600001',
          'gstin': 'TESTGSTIN',
          'bank_name': 'Test Bank',
          'bank_account_no': '0000000000',
          'shipping_address': 'Test Address'
        });
        await db.insert('products', {
          'product_code': 'PROD001',
          'product_name': 'Test Product',
          'unit_id': 1,
          'hsn': '123456',
          'rate': 100,
          'opening_stock': 100,
          'current_stock': 100
        });
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          for (final col in [
            'primary_mobile TEXT',
            'email TEXT',
            'opening_balance_cr REAL DEFAULT 0',
            'opening_balance_dr REAL DEFAULT 0',
            'ifsc_code TEXT',
            'branch_address TEXT',
            'shipping_contact_mobile TEXT',
            'shipping_city TEXT',
            'shipping_pincode TEXT',
            'shipping_gstin TEXT',
          ]) {
            try {
              await db.execute('ALTER TABLE customers ADD COLUMN $col');
            } catch (_) {
              // column already exists — ignore
            }
          }
        }
      },
    );
  }

  Database get db => _db!;

  Future<List<Map<String, dynamic>>> units() =>
      db.query('units', orderBy: 'id DESC');

  Future<List<Map<String, dynamic>>> customers() =>
      db.query('customers', where: 'status = ?', whereArgs: ['ACTIVE'], orderBy: 'id DESC');

  Future<List<Map<String, dynamic>>> products() =>
      db.rawQuery('''
        SELECT p.*, COALESCE(u.code, '') AS uom_code
        FROM products p
        LEFT JOIN units u ON u.id = p.unit_id
        WHERE p.status = 'ACTIVE'
        ORDER BY p.id DESC
      ''');

  Future<int> insertCustomer(Map<String, dynamic> row) =>
      db.insert('customers', row);

  Future<int> insertProduct(Map<String, dynamic> row) =>
      db.insert('products', row);

  Future<int> insertUnit(Map<String, dynamic> row) =>
      db.insert('units', row);

  Future<int> insertQueue(Map<String, dynamic> row) =>
      db.insert('sync_queue', row);

  Future<List<Map<String, dynamic>>> queue() =>
      db.query('sync_queue', orderBy: 'id DESC');

  String newUuid() => const Uuid().v4();
}

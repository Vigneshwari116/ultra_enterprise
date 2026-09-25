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
      version: 8,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE units(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
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
            shipping_consignee_name TEXT,
            shipping_contact_mobile TEXT,
            shipping_address TEXT,
            shipping_city TEXT,
            shipping_pincode TEXT,
            shipping_gstin TEXT,
            status TEXT DEFAULT 'ACTIVE'
          )
        ''');
        await db.execute('''
          CREATE TABLE suppliers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            supplier_code TEXT,
            supplier_name TEXT NOT NULL,
            contact_name TEXT,
            primary_mobile TEXT,
            email TEXT,
            address TEXT,
            city TEXT,
            postal_pincode TEXT,
            gstin TEXT,
            pan_no TEXT,
            opening_balance_cr REAL DEFAULT 0,
            opening_balance_dr REAL DEFAULT 0,
            bank_name TEXT,
            bank_account_no TEXT,
            ifsc_code TEXT,
            branch_address TEXT,
            shipping_consignee_name TEXT,
            shipping_address TEXT,
            shipping_city TEXT,
            shipping_pincode TEXT,
            shipping_alt_code TEXT,
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
        await db.execute('''
          CREATE TABLE purchase_orders(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT NOT NULL UNIQUE,
            po_no INTEGER,
            po_date TEXT,
            delivery_due_date TEXT,
            supplier_ref_no TEXT,
            total_packages INTEGER DEFAULT 0,
            delivery_mode TEXT,
            remarks TEXT,
            supplier_id INTEGER,
            taxable_total REAL DEFAULT 0,
            cgst_total REAL DEFAULT 0,
            sgst_total REAL DEFAULT 0,
            igst_total REAL DEFAULT 0,
            grand_total REAL DEFAULT 0,
            status TEXT DEFAULT 'DRAFT'
          )
        ''');
        await db.execute('''
          CREATE TABLE purchase_order_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            purchase_order_id INTEGER,
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
          CREATE TABLE receipts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER,
            receipt_date TEXT,
            amount REAL DEFAULT 0,
            narration TEXT,
            created_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE purchase_vouchers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT NOT NULL UNIQUE,
            voucher_no INTEGER,
            voucher_date TEXT,
            supplier_invoice_no TEXT,
            supplier_invoice_date TEXT,
            purchase_order_id INTEGER,
            supplier_id INTEGER,
            taxable_total REAL DEFAULT 0,
            cgst_total REAL DEFAULT 0,
            sgst_total REAL DEFAULT 0,
            igst_total REAL DEFAULT 0,
            grand_total REAL DEFAULT 0,
            status TEXT DEFAULT 'POSTED'
          )
        ''');
        await db.execute('''
          CREATE TABLE purchase_voucher_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            voucher_id INTEGER,
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
          CREATE TABLE payments(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            supplier_id INTEGER,
            payment_date TEXT,
            amount REAL DEFAULT 0,
            payment_mode TEXT,
            reference_no TEXT,
            narration TEXT,
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
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE units ADD COLUMN description TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE customers ADD COLUMN shipping_consignee_name TEXT');
          } catch (_) {}
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS suppliers(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              supplier_code TEXT,
              supplier_name TEXT NOT NULL,
              contact_name TEXT,
              primary_mobile TEXT,
              email TEXT,
              address TEXT,
              city TEXT,
              postal_pincode TEXT,
              gstin TEXT,
              pan_no TEXT,
              opening_balance_cr REAL DEFAULT 0,
              opening_balance_dr REAL DEFAULT 0,
              bank_name TEXT,
              bank_account_no TEXT,
              ifsc_code TEXT,
              branch_address TEXT,
              shipping_consignee_name TEXT,
              shipping_address TEXT,
              shipping_city TEXT,
              shipping_pincode TEXT,
              shipping_alt_code TEXT,
              status TEXT DEFAULT 'ACTIVE'
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS receipts(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              customer_id INTEGER,
              receipt_date TEXT,
              amount REAL DEFAULT 0,
              narration TEXT,
              created_at TEXT
            )
          ''');
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS purchase_orders(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              uuid TEXT NOT NULL UNIQUE,
              po_no INTEGER,
              po_date TEXT,
              delivery_due_date TEXT,
              supplier_ref_no TEXT,
              total_packages INTEGER DEFAULT 0,
              delivery_mode TEXT,
              remarks TEXT,
              supplier_id INTEGER,
              taxable_total REAL DEFAULT 0,
              cgst_total REAL DEFAULT 0,
              sgst_total REAL DEFAULT 0,
              igst_total REAL DEFAULT 0,
              grand_total REAL DEFAULT 0,
              status TEXT DEFAULT 'DRAFT'
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS purchase_order_items(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              purchase_order_id INTEGER,
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
        }
        if (oldVersion < 7) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS purchase_vouchers(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              uuid TEXT NOT NULL UNIQUE,
              voucher_no INTEGER,
              voucher_date TEXT,
              supplier_invoice_no TEXT,
              supplier_invoice_date TEXT,
              purchase_order_id INTEGER,
              supplier_id INTEGER,
              taxable_total REAL DEFAULT 0,
              cgst_total REAL DEFAULT 0,
              sgst_total REAL DEFAULT 0,
              igst_total REAL DEFAULT 0,
              grand_total REAL DEFAULT 0,
              status TEXT DEFAULT 'POSTED'
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS purchase_voucher_items(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              voucher_id INTEGER,
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
        }
        if (oldVersion < 8) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS payments(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              supplier_id INTEGER,
              payment_date TEXT,
              amount REAL DEFAULT 0,
              payment_mode TEXT,
              reference_no TEXT,
              narration TEXT,
              created_at TEXT
            )
          ''');
        }
      },
    );
  }

  Database get db => _db!;

  Future<List<Map<String, dynamic>>> units() =>
      db.query('units', orderBy: 'id DESC');

  Future<int> deleteUnit(int id) => db.delete('units', where: 'id = ?', whereArgs: [id]);

  Future<List<Map<String, dynamic>>> customers() =>
      db.query('customers', where: 'status = ?', whereArgs: ['ACTIVE'], orderBy: 'id DESC');

  Future<int> updateCustomer(int id, Map<String, dynamic> row) =>
      db.update('customers', row, where: 'id = ?', whereArgs: [id]);

  Future<List<Map<String, dynamic>>> suppliers() =>
      db.query('suppliers', where: 'status = ?', whereArgs: ['ACTIVE'], orderBy: 'id DESC');

  Future<int> insertSupplier(Map<String, dynamic> row) => db.insert('suppliers', row);

  Future<int> updateSupplier(int id, Map<String, dynamic> row) =>
      db.update('suppliers', row, where: 'id = ?', whereArgs: [id]);

  Future<int> deleteSupplier(int id) =>
      db.update('suppliers', {'status': 'INACTIVE'}, where: 'id = ?', whereArgs: [id]);

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

  /// Next sequential Sales Voucher number, shown read-only on the Sales
  /// Invoice screen before the record is actually saved.
  Future<int> nextSalesVoucherNo() async {
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM sales_invoices');
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count + 1;
  }

  // ---- Sales Reports (Ledger / Audit / Ledger-wise) ----

  /// All posted sales invoices joined with the customer's name, newest first.
  Future<List<Map<String, dynamic>>> salesInvoicesWithParty() => db.rawQuery('''
        SELECT si.*, COALESCE(c.customer_name, '-') AS party_name
        FROM sales_invoices si
        LEFT JOIN customers c ON c.id = si.customer_id
        ORDER BY si.transaction_date DESC, si.id DESC
      ''');

  Future<int> insertReceipt(Map<String, dynamic> row) => db.insert('receipts', row);

  Future<List<Map<String, dynamic>>> allReceipts() =>
      db.query('receipts', orderBy: 'receipt_date DESC, id DESC');

  Future<List<Map<String, dynamic>>> receiptsForCustomer(int customerId) => db.query(
    'receipts',
    where: 'customer_id = ?',
    whereArgs: [customerId],
    orderBy: 'receipt_date ASC, id ASC',
  );

  Future<List<Map<String, dynamic>>> salesInvoicesForCustomer(int customerId) => db.query(
    'sales_invoices',
    where: 'customer_id = ?',
    whereArgs: [customerId],
    orderBy: 'transaction_date ASC, id ASC',
  );

  // ---- Purchase Orders ----

  Future<int> nextPurchaseOrderNo() async {
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM purchase_orders');
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count + 1;
  }

  Future<List<Map<String, dynamic>>> purchaseOrdersWithParty() => db.rawQuery('''
        SELECT po.*, COALESCE(s.supplier_name, '-') AS party_name
        FROM purchase_orders po
        LEFT JOIN suppliers s ON s.id = po.supplier_id
        ORDER BY po.po_date DESC, po.id DESC
      ''');

  // ---- Purchase Vouchers ----

  Future<int> nextPurchaseVoucherNo() async {
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM purchase_vouchers');
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count + 1;
  }

  /// Purchase orders not yet fully received against — used to populate the
  /// "Against PO" picker on the Purchase Voucher screen.
  Future<List<Map<String, dynamic>>> openPurchaseOrders() => db.rawQuery('''
        SELECT po.*, COALESCE(s.supplier_name, '-') AS party_name
        FROM purchase_orders po
        LEFT JOIN suppliers s ON s.id = po.supplier_id
        WHERE po.status != 'RECEIVED'
        ORDER BY po.id DESC
      ''');

  Future<List<Map<String, dynamic>>> purchaseOrderItems(int purchaseOrderId) =>
      db.query('purchase_order_items', where: 'purchase_order_id = ?', whereArgs: [purchaseOrderId]);

  Future<List<Map<String, dynamic>>> purchaseVouchersWithParty() => db.rawQuery('''
        SELECT pv.*, COALESCE(s.supplier_name, '-') AS party_name, po.po_no AS linked_po_no
        FROM purchase_vouchers pv
        LEFT JOIN suppliers s ON s.id = pv.supplier_id
        LEFT JOIN purchase_orders po ON po.id = pv.purchase_order_id
        ORDER BY pv.voucher_date DESC, pv.id DESC
      ''');

  /// Increments stock on hand for a product — called for every line item
  /// when a Purchase Voucher (actual goods receipt) is posted.
  Future<void> incrementStock(int productId, double qty) => db.rawUpdate(
    'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
    [qty, productId],
  );

  Future<void> markPurchaseOrderReceived(int purchaseOrderId) => db.update(
    'purchase_orders',
    {'status': 'RECEIVED'},
    where: 'id = ?',
    whereArgs: [purchaseOrderId],
  );

  // ---- Purchase Payments (DR side of the supplier ledger) ----

  Future<int> insertPayment(Map<String, dynamic> row) => db.insert('payments', row);

  Future<List<Map<String, dynamic>>> allPayments() =>
      db.query('payments', orderBy: 'payment_date DESC, id DESC');

  Future<List<Map<String, dynamic>>> paymentsForSupplier(int supplierId) => db.query(
    'payments',
    where: 'supplier_id = ?',
    whereArgs: [supplierId],
    orderBy: 'payment_date ASC, id ASC',
  );

  /// Total ever paid to a single supplier — used for the per-row "Paid
  /// Amount (DR)" figure on the Ledger View tab.
  Future<double> totalPaidToSupplier(int supplierId) async {
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM payments WHERE supplier_id = ?',
      [supplierId],
    );
    return ((result.first['total'] ?? 0) as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> purchaseVouchersForSupplier(int supplierId) => db.query(
    'purchase_vouchers',
    where: 'supplier_id = ?',
    whereArgs: [supplierId],
    orderBy: 'voucher_date ASC, id ASC',
  );

  Future<List<Map<String, dynamic>>> purchaseVoucherItems(int voucherId) =>
      db.query('purchase_voucher_items', where: 'voucher_id = ?', whereArgs: [voucherId]);

  Future<Map<String, dynamic>?> supplierById(int id) async {
    final rows = await db.query('suppliers', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  String newUuid() => const Uuid().v4();

  // ---- Dashboard analytics ----

  Future<int> pendingPurchaseOrderCount() async {
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM purchase_orders WHERE status IS NULL OR status != 'RECEIVED'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> customerOutstandingTotal() async {
    final ob = await db.rawQuery(
      "SELECT COALESCE(SUM(opening_balance_dr - opening_balance_cr), 0) AS t FROM customers WHERE status = 'ACTIVE'",
    );
    final inv = await db.rawQuery('SELECT COALESCE(SUM(grand_total), 0) AS t FROM sales_invoices');
    final rec = await db.rawQuery('SELECT COALESCE(SUM(amount), 0) AS t FROM receipts');
    final opening = (ob.first['t'] as num?)?.toDouble() ?? 0;
    final invoices = (inv.first['t'] as num?)?.toDouble() ?? 0;
    final receipts = (rec.first['t'] as num?)?.toDouble() ?? 0;
    return opening + invoices - receipts;
  }

  Future<double> supplierOutstandingTotal() async {
    final ob = await db.rawQuery(
      "SELECT COALESCE(SUM(opening_balance_cr - opening_balance_dr), 0) AS t FROM suppliers WHERE status = 'ACTIVE'",
    );
    final pv = await db.rawQuery('SELECT COALESCE(SUM(grand_total), 0) AS t FROM purchase_vouchers');
    final paid = await db.rawQuery('SELECT COALESCE(SUM(amount), 0) AS t FROM payments');
    final opening = (ob.first['t'] as num?)?.toDouble() ?? 0;
    final purchases = (pv.first['t'] as num?)?.toDouble() ?? 0;
    final payments = (paid.first['t'] as num?)?.toDouble() ?? 0;
    return opening + purchases - payments;
  }

  Future<double> monthlyPurchaseExpenses() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1).toIso8601String().split('T').first;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(grand_total), 0) AS t FROM purchase_vouchers WHERE voucher_date >= ?',
      [start],
    );
    return (result.first['t'] as num?)?.toDouble() ?? 0;
  }

  Future<int> runningProjectsCount() async {
    final invoices = await db.rawQuery('SELECT COUNT(DISTINCT customer_id) AS c FROM sales_invoices');
    final count = Sqflite.firstIntValue(invoices) ?? 0;
    return count > 0 ? count : 1;
  }
}

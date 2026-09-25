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
      version: 14,
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
        await db.execute('''
          CREATE TABLE ledger_accounts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            group_name TEXT,
            head TEXT,
            group_wise TEXT,
            cr_amount REAL DEFAULT 0,
            dr_amount REAL DEFAULT 0,
            updated_time TEXT,
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
        if (oldVersion < 14) {
          try {
            await db.execute('ALTER TABLE adjustment_notes ADD COLUMN note_bill_no TEXT');
          } catch (_) {}
        }
        if (oldVersion < 13) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS material_types(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              type_code TEXT NOT NULL,
              description TEXT,
              created_at TEXT
            )
          ''');
          for (final col in [
            'material_type_id INTEGER',
            'raw_material_size TEXT',
            'finishing_size TEXT',
            'purchase_rate REAL DEFAULT 0',
            'sales_rate REAL DEFAULT 0',
            'units_bound REAL DEFAULT 1',
            'image_base64 TEXT',
            'log_date TEXT',
          ]) {
            try {
              await db.execute('ALTER TABLE products ADD COLUMN $col');
            } catch (_) {}
          }
        }
        if (oldVersion < 12) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS adjustment_notes(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              uuid TEXT NOT NULL UNIQUE,
              note_type TEXT NOT NULL,
              note_no INTEGER,
              issue_date TEXT,
              original_invoice_ref TEXT,
              original_invoice_date TEXT,
              reversal_reason TEXT,
              eway_bill TEXT,
              logistics TEXT,
              party_kind TEXT,
              party_id INTEGER,
              address TEXT,
              city TEXT,
              pincode TEXT,
              gstin TEXT,
              narration TEXT,
              taxable_total REAL DEFAULT 0,
              tax_total REAL DEFAULT 0,
              grand_total REAL DEFAULT 0,
              created_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS adjustment_note_items(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              note_id INTEGER,
              product_id INTEGER,
              description TEXT,
              uom TEXT,
              hsn TEXT,
              quantity REAL,
              rate REAL,
              cgst_percent REAL,
              sgst_percent REAL,
              igst_percent REAL,
              extended_value REAL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS journal_vouchers(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              voucher_date TEXT,
              narration TEXT,
              total_amount REAL DEFAULT 0,
              created_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS journal_voucher_lines(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              voucher_id INTEGER,
              line_no INTEGER,
              dr_account_key TEXT,
              dr_account_label TEXT,
              cr_account_key TEXT,
              cr_account_label TEXT,
              amount REAL DEFAULT 0
            )
          ''');
        }
        if (oldVersion < 11) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS delivery_challans(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              uuid TEXT NOT NULL UNIQUE,
              dc_type TEXT NOT NULL,
              serial_no INTEGER,
              doc_id TEXT,
              document_date TEXT,
              po_ref_no TEXT,
              po_ref_date TEXT,
              total_packages INTEGER DEFAULT 0,
              vehicle_dispatch TEXT,
              credit_due_days INTEGER DEFAULT 0,
              eway_bill_no TEXT,
              validity_days INTEGER DEFAULT 0,
              party_kind TEXT,
              party_id INTEGER,
              billing_address TEXT,
              city TEXT,
              pincode TEXT,
              gstin TEXT,
              account_ref TEXT,
              delivery_site_address TEXT,
              fwd_charge REAL DEFAULT 0,
              base_value REAL DEFAULT 0,
              tax_total REAL DEFAULT 0,
              grand_total REAL DEFAULT 0,
              total_pcs REAL DEFAULT 0,
              status TEXT DEFAULT 'POSTED',
              created_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS delivery_challan_items(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              challan_id INTEGER,
              product_id INTEGER,
              description TEXT,
              uom TEXT,
              hsn TEXT,
              quantity REAL,
              rate REAL,
              cgst_percent REAL,
              sgst_percent REAL,
              igst_percent REAL,
              extended_value REAL,
              remarks TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS quotations(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              uuid TEXT NOT NULL UNIQUE,
              ref_no TEXT,
              serial_no INTEGER,
              quotation_date TEXT,
              validity_days INTEGER DEFAULT 0,
              reference_name TEXT,
              reference_date TEXT,
              party_kind TEXT,
              party_id INTEGER,
              address TEXT,
              city TEXT,
              pincode TEXT,
              gstin TEXT,
              salutation TEXT,
              subject TEXT,
              body_text TEXT,
              freight REAL DEFAULT 0,
              net_total REAL DEFAULT 0,
              total_qty REAL DEFAULT 0,
              status TEXT DEFAULT 'PENDING',
              created_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS quotation_items(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              quotation_id INTEGER,
              product_id INTEGER,
              description TEXT,
              uom TEXT,
              quantity REAL,
              rate REAL,
              line_total REAL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS quotation_terms(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              quotation_id INTEGER,
              sort_order INTEGER,
              text TEXT
            )
          ''');
        }
        if (oldVersion < 10) {
          for (final col in [
            'po_bill_no TEXT',
            'state_zone TEXT',
            'due_days INTEGER DEFAULT 0',
            'estimated_freight REAL DEFAULT 0',
          ]) {
            try {
              await db.execute('ALTER TABLE purchase_orders ADD COLUMN $col');
            } catch (_) {}
          }
        }
        if (oldVersion < 9) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS ledger_accounts(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              group_name TEXT,
              head TEXT,
              group_wise TEXT,
              cr_amount REAL DEFAULT 0,
              dr_amount REAL DEFAULT 0,
              updated_time TEXT,
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

  Future<int> updateUnit(int id, Map<String, dynamic> row) =>
      db.update('units', row, where: 'id = ?', whereArgs: [id]);

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
        SELECT p.*, COALESCE(u.code, '') AS uom_code,
          COALESCE(mt.type_code, '') AS material_type_code
        FROM products p
        LEFT JOIN units u ON u.id = p.unit_id
        LEFT JOIN material_types mt ON mt.id = p.material_type_id
        WHERE p.status = 'ACTIVE'
        ORDER BY p.id DESC
      ''');

  Future<int> updateProduct(int id, Map<String, dynamic> row) =>
      db.update('products', row, where: 'id = ?', whereArgs: [id]);

  Future<int> deleteProduct(int id) =>
      db.update('products', {'status': 'INACTIVE'}, where: 'id = ?', whereArgs: [id]);

  Future<List<Map<String, dynamic>>> materialTypes() =>
      db.query('material_types', orderBy: 'type_code ASC');

  Future<int> insertMaterialType(Map<String, dynamic> row) {
    row['created_at'] = DateTime.now().toIso8601String();
    return db.insert('material_types', row);
  }

  Future<int> updateMaterialType(int id, Map<String, dynamic> row) =>
      db.update('material_types', row, where: 'id = ?', whereArgs: [id]);

  Future<int> deleteMaterialType(int id) =>
      db.delete('material_types', where: 'id = ?', whereArgs: [id]);

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

  Future<List<Map<String, dynamic>>> salesInvoiceItems(int invoiceId) => db.query(
        'sales_invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );

  /// Header + customer fields + line items for tax-invoice PDF reprint.
  Future<Map<String, dynamic>?> salesInvoicePrintBundle(int invoiceId) async {
    final rows = await db.rawQuery('''
      SELECT si.*,
        COALESCE(c.customer_name, '-') AS customer_name,
        COALESCE(c.address, '') AS customer_address,
        COALESCE(c.gstin, '') AS customer_gstin,
        COALESCE(c.primary_mobile, '') AS customer_mobile,
        COALESCE(c.bank_name, '') AS bank_name,
        COALESCE(c.bank_account_no, '') AS bank_account_no,
        COALESCE(c.ifsc_code, '') AS ifsc_code,
        COALESCE(c.branch_address, '') AS branch_address,
        COALESCE(c.shipping_address, '') AS shipping_address
      FROM sales_invoices si
      LEFT JOIN customers c ON c.id = si.customer_id
      WHERE si.id = ?
      LIMIT 1
    ''', [invoiceId]);
    if (rows.isEmpty) return null;
    final items = await salesInvoiceItems(invoiceId);
    return {'invoice': rows.first, 'items': items};
  }

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
        SELECT po.*, COALESCE(s.supplier_name, '-') AS party_name,
          (SELECT COALESCE(SUM(poi.quantity), 0) FROM purchase_order_items poi WHERE poi.purchase_order_id = po.id) AS total_qty
        FROM purchase_orders po
        LEFT JOIN suppliers s ON s.id = po.supplier_id
        ORDER BY po.po_date DESC, po.id DESC
      ''');

  Future<Map<String, dynamic>?> purchaseOrderPrintBundle(int purchaseOrderId) async {
    final rows = await db.rawQuery('''
        SELECT po.*,
          s.supplier_name, s.address, s.city, s.postal_pincode, s.gstin, s.primary_mobile,
          s.bank_name, s.bank_account_no, s.ifsc_code, s.branch_address
        FROM purchase_orders po
        LEFT JOIN suppliers s ON s.id = po.supplier_id
        WHERE po.id = ?
      ''', [purchaseOrderId]);
    if (rows.isEmpty) return null;
    final items = await purchaseOrderItems(purchaseOrderId);
    return {'order': rows.first, 'items': items};
  }

  Future<void> updatePurchaseOrderStatus(int purchaseOrderId, String status) => db.update(
        'purchase_orders',
        {'status': status},
        where: 'id = ?',
        whereArgs: [purchaseOrderId],
      );

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

  Future<List<Map<String, dynamic>>> ledgerAccounts() =>
      db.query('ledger_accounts', orderBy: 'id DESC');

  Future<int> insertLedger(Map<String, dynamic> row) async {
    row['created_at'] = DateTime.now().toIso8601String();
    return db.insert('ledger_accounts', row);
  }

  Future<int> updateLedger(int id, Map<String, dynamic> row) =>
      db.update('ledger_accounts', row, where: 'id = ?', whereArgs: [id]);

  Future<int> runningProjectsCount() async {
    final invoices = await db.rawQuery('SELECT COUNT(DISTINCT customer_id) AS c FROM sales_invoices');
    final count = Sqflite.firstIntValue(invoices) ?? 0;
    return count > 0 ? count : 1;
  }

  // ---- Delivery Challan ----

  Future<int> nextDeliveryChallanSerial(String dcType) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM delivery_challans WHERE dc_type = ?',
      [dcType],
    );
    return (Sqflite.firstIntValue(result) ?? 0) + 1;
  }

  Future<List<Map<String, dynamic>>> deliveryChallansList({String? dcType}) async {
    final where = dcType == null ? '' : 'WHERE dc.dc_type = ?';
    final args = dcType == null ? <Object>[] : [dcType];
    return db.rawQuery('''
      SELECT dc.*,
        CASE
          WHEN dc.party_kind = 'SUPPLIER' THEN (SELECT supplier_name FROM suppliers WHERE id = dc.party_id)
          WHEN dc.party_kind = 'CUSTOMER' THEN (SELECT customer_name FROM customers WHERE id = dc.party_id)
          ELSE '-'
        END AS party_name
      FROM delivery_challans dc
      $where
      ORDER BY dc.document_date DESC, dc.id DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> deliveryChallanItems(int challanId) =>
      db.query('delivery_challan_items', where: 'challan_id = ?', whereArgs: [challanId]);

  Future<Map<String, dynamic>?> deliveryChallanPrintBundle(int challanId) async {
    final rows = await db.rawQuery('''
      SELECT dc.*,
        CASE
          WHEN dc.party_kind = 'SUPPLIER' THEN (SELECT supplier_name FROM suppliers WHERE id = dc.party_id)
          WHEN dc.party_kind = 'CUSTOMER' THEN (SELECT customer_name FROM customers WHERE id = dc.party_id)
          ELSE '-'
        END AS party_name
      FROM delivery_challans dc
      WHERE dc.id = ?
    ''', [challanId]);
    if (rows.isEmpty) return null;
    return {'challan': rows.first, 'items': await deliveryChallanItems(challanId)};
  }

  // ---- Quotation ----

  Future<int> nextQuotationSerial() async {
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM quotations');
    return (Sqflite.firstIntValue(result) ?? 0) + 1;
  }

  Future<List<Map<String, dynamic>>> quotationsWithParty() => db.rawQuery('''
        SELECT q.*,
          CASE
            WHEN q.party_kind = 'SUPPLIER' THEN (SELECT supplier_name FROM suppliers WHERE id = q.party_id)
            WHEN q.party_kind = 'CUSTOMER' THEN (SELECT customer_name FROM customers WHERE id = q.party_id)
            ELSE '-'
          END AS party_name,
          (SELECT COALESCE(SUM(quantity), 0) FROM quotation_items WHERE quotation_id = q.id) AS total_qty
        FROM quotations q
        ORDER BY q.quotation_date DESC, q.id DESC
      ''');

  Future<List<Map<String, dynamic>>> quotationItems(int quotationId) =>
      db.query('quotation_items', where: 'quotation_id = ?', whereArgs: [quotationId], orderBy: 'id ASC');

  Future<List<Map<String, dynamic>>> quotationTerms(int quotationId) =>
      db.query('quotation_terms', where: 'quotation_id = ?', whereArgs: [quotationId], orderBy: 'sort_order ASC');

  Future<void> updateQuotationStatus(int quotationId, String status) => db.update(
        'quotations',
        {'status': status},
        where: 'id = ?',
        whereArgs: [quotationId],
      );

  Future<List<Map<String, dynamic>>> adjustmentNotesWithParty() => db.rawQuery('''
        SELECT an.*,
          CASE
            WHEN an.party_kind = 'SUPPLIER' THEN (SELECT supplier_name FROM suppliers WHERE id = an.party_id)
            WHEN an.party_kind = 'CUSTOMER' THEN (SELECT customer_name FROM customers WHERE id = an.party_id)
            ELSE '-'
          END AS party_name
        FROM adjustment_notes an
        ORDER BY an.issue_date DESC, an.id DESC
      ''');

  Future<List<Map<String, dynamic>>> adjustmentNoteItems(int noteId) =>
      db.query('adjustment_note_items', where: 'note_id = ?', whereArgs: [noteId]);

  Future<Map<String, dynamic>?> adjustmentNotePrintBundle(int noteId) async {
    final rows = await adjustmentNotesWithParty();
    final note = rows.where((r) => r['id'] == noteId).toList();
    if (note.isEmpty) return null;
    return {'note': note.first, 'items': await adjustmentNoteItems(noteId)};
  }

  Future<List<Map<String, dynamic>>> journalSummaryLines() => db.rawQuery('''
        SELECT jv.id AS voucher_id, jv.voucher_date, jv.narration, jv.total_amount,
          jvl.line_no, jvl.dr_account_label, jvl.cr_account_label, jvl.amount
        FROM journal_voucher_lines jvl
        INNER JOIN journal_vouchers jv ON jv.id = jvl.voucher_id
        ORDER BY jv.voucher_date DESC, jv.id DESC, jvl.line_no ASC
      ''');

  Future<int> nextAdjustmentNoteNo(String noteType) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM adjustment_notes WHERE note_type = ?',
      [noteType],
    );
    return (Sqflite.firstIntValue(result) ?? 0) + 1;
  }

  Future<List<Map<String, String>>> masterAccountDirectory() async {
    final options = <Map<String, String>>[];
    for (final l in await ledgerAccounts()) {
      options.add({'key': 'LEDGER:${l['id']}', 'label': '${l['name']}'});
    }
    for (final c in await customers()) {
      options.add({'key': 'CUSTOMER:${c['id']}', 'label': '${c['customer_name']}'});
    }
    for (final s in await suppliers()) {
      options.add({'key': 'SUPPLIER:${s['id']}', 'label': '${s['supplier_name']}'});
    }
    return options;
  }

  Future<List<Map<String, dynamic>>> cashPassbookEntries() async {
    return db.rawQuery('''
      SELECT 'CR' AS side, r.id AS entry_id, r.receipt_date AS entry_date, r.amount AS amount,
        r.narration AS narration, c.customer_name AS party_name, 'CUSTOMER' AS party_kind
      FROM receipts r
      LEFT JOIN customers c ON c.id = r.customer_id
      UNION ALL
      SELECT 'DR' AS side, p.id AS entry_id, p.payment_date AS entry_date, p.amount AS amount,
        p.narration AS narration, s.supplier_name AS party_name, 'SUPPLIER' AS party_kind
      FROM payments p
      LEFT JOIN suppliers s ON s.id = p.supplier_id
      ORDER BY entry_date DESC, entry_id DESC
    ''');
  }

  Future<Map<String, dynamic>?> quotationPrintBundle(int quotationId) async {
    final rows = await quotationsWithParty();
    final q = rows.where((r) => r['id'] == quotationId).toList();
    if (q.isEmpty) return null;
    return {
      'quotation': q.first,
      'items': await quotationItems(quotationId),
      'terms': await quotationTerms(quotationId),
    };
  }
}

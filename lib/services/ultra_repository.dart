import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../config/ultra_config.dart';
import '../database/app_database.dart';
import 'api_service.dart';

/// Single entry point for app data: server-first when [UltraConfig.persistLocally] is false.
class UltraRepository {
  UltraRepository._();
  static final UltraRepository instance = UltraRepository._();

  final _api = ApiService.instance;
  final _db = AppDatabase.instance;

  String newUuid() => const Uuid().v4();

  // ---- HTTP helpers ----

  bool _isApiNotFound(Object e) {
    final msg = e.toString();
    return msg.contains('404') || msg.contains('Route not found');
  }

  Future<dynamic> _safeGet(String path) async {
    try {
      return await _api.get(path);
    } catch (e) {
      if (_isApiNotFound(e)) return null;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    return _asRowList(await _safeGet(path)).map(_flattenEnvelopeRow).toList();
  }

  /// Merges VPS envelope rows `{ id, status, data: "{...json...}" }` into flat maps.
  Map<String, dynamic> _flattenEnvelopeRow(Map<String, dynamic> row) {
    final out = Map<String, dynamic>.from(row);
    final data = out.remove('data');
    Map<String, dynamic>? inner;
    if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          inner = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    } else if (data is Map) {
      inner = Map<String, dynamic>.from(data);
    }
    if (inner != null) {
      for (final entry in inner.entries) {
        out.putIfAbsent(entry.key, () => entry.value);
      }
    }
    return out;
  }

  Map<String, dynamic> _normalizeSalesInvoiceItem(Map<String, dynamic> it) {
    final out = Map<String, dynamic>.from(it);
    out['hsn'] ??= out['hsn_code'];
    out['taxable'] ??= out['taxable_amount'];
    out['cgst'] ??= out['cgst_amount'];
    out['sgst'] ??= out['sgst_amount'];
    out['igst'] ??= out['igst_amount'];
    out['total'] ??= out['compound_total'];
    return out;
  }

  Map<String, dynamic> _normalizePurchaseVoucherItem(Map<String, dynamic> it) {
    final out = Map<String, dynamic>.from(it);
    out['hsn'] ??= out['hsn_code'];
    out['taxable'] ??= out['taxable_amount'];
    out['cgst'] ??= out['cgst_amount'];
    out['sgst'] ??= out['sgst_amount'];
    out['igst'] ??= out['igst_amount'];
    out['total'] ??= out['compound_total'] ?? out['line_total'];
    out['quantity'] ??= out['qty'];
    out['rate'] ??= out['unit_rate'];
    return out;
  }

  Map<String, dynamic> _normalizePurchaseVoucherRow(Map<String, dynamic> row) {
    final out = _flattenEnvelopeRow(row);
    out['party_name'] ??= out['supplier_name'];
    out['voucher_date'] ??= out['transaction_date'];
    return out;
  }

  Future<Map<String, dynamic>> _enrichPurchaseVoucherWithSupplier(
    Map<String, dynamic> voucher,
  ) async {
    final out = Map<String, dynamic>.from(voucher);
    final sid = out['supplier_id'];
    final supplierId = sid is int ? sid : (sid is num ? sid.toInt() : null);
    if (supplierId == null) return out;
    if (out['supplier_name'] != null && '${out['address'] ?? ''}'.trim().isNotEmpty) {
      return out;
    }
    final supplier = await supplierById(supplierId);
    if (supplier == null) return out;
    for (final key in [
      'supplier_name',
      'address',
      'city',
      'postal_pincode',
      'gstin',
      'primary_mobile',
      'bank_name',
      'bank_account_no',
      'ifsc_code',
      'branch_address',
    ]) {
      out.putIfAbsent(key, () => supplier[key]);
    }
    out['party_name'] ??= supplier['supplier_name'];
    return out;
  }

  List<Map<String, dynamic>> _asRowList(dynamic decoded) {
    if (decoded == null) return [];
    if (decoded is List) {
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (decoded is Map) {
      for (final key in [
        'results',
        'data',
        'items',
        'invoices',
        'customers',
        'units',
        'products',
        'suppliers',
        'material_types',
        'material-types',
        'orders',
        'quotations',
        'notes',
        'vouchers',
      ]) {
        final inner = decoded[key];
        if (inner is List) {
          return inner.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    }
    return [];
  }

  Map<String, dynamic> _asRow(dynamic decoded) {
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw Exception('Unexpected API response shape');
  }

  int _idFromResponse(dynamic decoded) {
    final row = _asRow(decoded);
    for (final key in [
      'customer',
      'invoice',
      'unit',
      'supplier',
      'product',
      'material_type',
      'order',
      'challan',
      'quotation',
      'note',
      'voucher',
    ]) {
      final nested = row[key];
      if (nested is Map) {
        final id = nested['id'];
        if (id is int) return id;
        if (id is num) return id.toInt();
      }
    }
    final id = row['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    if (id is String) {
      final parsed = int.tryParse(id.trim());
      if (parsed != null) return parsed;
    }
    throw Exception('API response missing id');
  }

  Map<String, dynamic> _normalizeProductRow(Map<String, dynamic> row) {
    final out = Map<String, dynamic>.from(row);
    out['product_code'] ??= out['barcode'];
    out['product_name'] ??= out['name'];
    out['sales_rate'] ??= out['rate'];
    return out;
  }

  /// Maps Material Master form fields to live Product API JSON.
  Map<String, dynamic> _mapProductToApi(Map<String, dynamic> row) {
    final code = '${row['product_code'] ?? row['barcode'] ?? ''}'.trim();
    final body = <String, dynamic>{
      'product_name': row['product_name'],
      'barcode': code,
      'hsn': row['hsn'],
      'unit_id': row['unit_id'],
      'material_type_id': row['material_type_id'],
      'sales_rate': row['sales_rate'] ?? row['rate'],
      'purchase_rate': row['purchase_rate'],
    };
    final gst = row['gst_rate'] ?? row['gst_percent'];
    if (gst != null) {
      body['gst_rate'] = gst;
    }
    body.removeWhere((_, v) => v == null || (v is String && v.isEmpty));
    return body;
  }

  Map<String, dynamic> _mapCustomerToApi(Map<String, dynamic> row) {
    final out = Map<String, dynamic>.from(row);
    if (out.containsKey('bank_name')) {
      out['bank_identifier_name'] = out.remove('bank_name');
    }
    return out;
  }

  static const _stateZoneIdByLabel = {
    'Intra State': 1,
    'Inter State': 2,
    'INTRA': 1,
    'INTER': 2,
  };

  Map<String, dynamic> _mapSalesInvoiceToApi(Map<String, dynamic> body) {
    final out = Map<String, dynamic>.from(body);
    final zone = out.remove('state_zone');
    if (zone != null && out['state_zone_id'] == null) {
      final id = _stateZoneIdByLabel['$zone'] ??
          _stateZoneIdByLabel['${zone.toString().toUpperCase()}'];
      if (id != null) out['state_zone_id'] = id;
    }
    if (out.containsKey('challan_no')) {
      out['challan_dc_no'] = out.remove('challan_no');
    }
    if (out.containsKey('challan_date')) {
      out['challan_dc_date'] = out.remove('challan_date');
    }
    return out;
  }

  Map<String, dynamic> _normalizeSalesInvoiceRow(Map<String, dynamic> inv) {
    final out = Map<String, dynamic>.from(inv);
    out['party_name'] = out['party_name'] ?? out['customer_name'];
    out['state_zone'] = out['state_zone'] ?? out['state_zone_name'] ?? out['state_zone_code'];
    out['challan_no'] = out['challan_no'] ?? out['challan_dc_no'];
    out['challan_date'] = out['challan_date'] ?? out['challan_dc_date'];
    out['customer_address'] = out['customer_address'] ?? out['address'];
    out['customer_gstin'] = out['customer_gstin'] ?? out['gstin'];
    out['bank_name'] = out['bank_name'] ?? out['bank_identifier_name'];
    return out;
  }

  Future<Map<String, dynamic>?> _getDocument(String path) async {
    try {
      final decoded = await _api.get(path);
      if (decoded == null) return null;
      final row = _asRow(decoded);
      if (row['invoice'] is Map) {
        final invoice = _normalizeSalesInvoiceRow(
          _flattenEnvelopeRow(Map<String, dynamic>.from(row['invoice'] as Map)),
        );
        final items = _asRowList(row['items']).map(_normalizeSalesInvoiceItem).toList();
        return {...row, 'invoice': invoice, 'items': items};
      }
      if (row['voucher'] is Map) {
        var voucher = _normalizePurchaseVoucherRow(
          Map<String, dynamic>.from(row['voucher'] as Map),
        );
        voucher = await _enrichPurchaseVoucherWithSupplier(voucher);
        final items =
            _asRowList(row['items']).map(_normalizePurchaseVoucherItem).toList();
        return {'voucher': voucher, 'items': items};
      }
      final items = row['items'];
      if (items != null) {
        final normalizedItems = _asRowList(items);
        if (path.contains('purchase-vouchers')) {
          return {
            ...row,
            'items': normalizedItems.map(_normalizePurchaseVoucherItem).toList(),
          };
        }
        return {
          ...row,
          'items': normalizedItems.map(_normalizeSalesInvoiceItem).toList(),
        };
      }
      return _flattenEnvelopeRow(row);
    } catch (_) {
      return null;
    }
  }

  // ---- Masters ----

  Future<List<Map<String, dynamic>>> units() async {
    if (UltraConfig.persistLocally) return _db.units();
    return await _getList('/api/units');
  }

  Future<int> insertUnit(Map<String, dynamic> row) async {
    if (UltraConfig.persistLocally) return _db.insertUnit(row);
    return _idFromResponse(await _api.post('/api/units', row));
  }

  Future<int> updateUnit(int id, Map<String, dynamic> row) async {
    if (UltraConfig.persistLocally) return _db.updateUnit(id, row);
    await _api.put('/api/units/$id', row);
    return id;
  }

  Future<int> deleteUnit(int id) async {
    if (UltraConfig.persistLocally) return _db.deleteUnit(id);
    await _api.delete('/api/units/$id');
    return id;
  }

  Future<List<Map<String, dynamic>>> customers() async {
    if (UltraConfig.persistLocally) return _db.customers();
    return await _getList('/api/customers');
  }

  Future<int> insertCustomer(Map<String, dynamic> row) async {
    if (UltraConfig.persistLocally) return _db.insertCustomer(row);
    return _idFromResponse(await _api.post('/api/customers', _mapCustomerToApi(row)));
  }

  Future<int> updateCustomer(int id, Map<String, dynamic> row) async {
    if (UltraConfig.persistLocally) return _db.updateCustomer(id, row);
    await _api.put('/api/customers/$id', _mapCustomerToApi(row));
    return id;
  }

  Future<List<Map<String, dynamic>>> suppliers() async {
    if (UltraConfig.persistLocally) return _db.suppliers();
    return await _getList('/api/suppliers');
  }

  Future<int> insertSupplier(Map<String, dynamic> row) async {
    if (UltraConfig.persistLocally) return _db.insertSupplier(row);
    return _idFromResponse(await _api.post('/api/suppliers', row));
  }

  Future<int> updateSupplier(int id, Map<String, dynamic> row) async {
    if (UltraConfig.persistLocally) return _db.updateSupplier(id, row);
    await _api.put('/api/suppliers/$id', row);
    return id;
  }

  Future<List<Map<String, dynamic>>> products() async {
    if (UltraConfig.persistLocally) return _db.products();
    return (await _getList('/api/products')).map(_normalizeProductRow).toList();
  }

  Future<int> insertProduct(Map<String, dynamic> row) async {
    if (UltraConfig.persistLocally) return _db.insertProduct(row);
    return _idFromResponse(await _api.post('/api/products', _mapProductToApi(row)));
  }

  Future<int> updateProduct(int id, Map<String, dynamic> row) async {
    if (UltraConfig.persistLocally) return _db.updateProduct(id, row);
    await _api.put('/api/products/$id', _mapProductToApi(row));
    return id;
  }

  Future<List<Map<String, dynamic>>> ledgerAccounts() async {
    if (UltraConfig.persistLocally) return _db.ledgerAccounts();
    return await _getList('/api/ledger-accounts');
  }

  Future<int> insertLedger(Map<String, dynamic> row) async {
    if (UltraConfig.persistLocally) return _db.insertLedger(row);
    return _idFromResponse(await _api.post('/api/ledger-accounts', row));
  }

  Future<int> updateLedger(int id, Map<String, dynamic> row) async {
    if (UltraConfig.persistLocally) return _db.updateLedger(id, row);
    await _api.put('/api/ledger-accounts/$id', row);
    return id;
  }

  Future<List<Map<String, dynamic>>> materialTypes() async {
    if (UltraConfig.persistLocally) return _db.materialTypes();
    return await _getList('/api/material-types');
  }

  Future<int> insertMaterialType(Map<String, dynamic> row) async {
    if (UltraConfig.persistLocally) return _db.insertMaterialType(row);
    return _idFromResponse(await _api.post('/api/material-types', row));
  }

  Future<int> updateMaterialType(int id, Map<String, dynamic> row) async {
    if (UltraConfig.persistLocally) return _db.updateMaterialType(id, row);
    await _api.put('/api/material-types/$id', row);
    return id;
  }

  Future<int> deleteMaterialType(int id) async {
    if (UltraConfig.persistLocally) return _db.deleteMaterialType(id);
    await _api.delete('/api/material-types/$id');
    return id;
  }

  // ---- Sales invoices ----

  Future<int> nextSalesVoucherNo() async {
    if (UltraConfig.persistLocally) return _db.nextSalesVoucherNo();
    final list = await salesInvoicesWithParty();
    var max = 0;
    for (final row in list) {
      final n = (row['invoice_no'] as num?)?.toInt() ?? 0;
      if (n > max) max = n;
    }
    return max + 1;
  }

  Future<List<Map<String, dynamic>>> salesInvoicesWithParty() async {
    if (UltraConfig.persistLocally) return _db.salesInvoicesWithParty();
    final rows = await _getList('/api/sales-invoices');
    return rows.map(_normalizeSalesInvoiceRow).toList();
  }

  Future<int> createSalesInvoice(Map<String, dynamic> body) async {
    if (UltraConfig.persistLocally) {
      return _createSalesInvoiceLocal(body);
    }
    return _idFromResponse(
      await _api.post('/api/sales-invoices', _mapSalesInvoiceToApi(body)),
    );
  }

  Future<int> _createSalesInvoiceLocal(Map<String, dynamic> body) async {
    final items = (body.remove('items') as List?)?.cast<Map<String, dynamic>>() ?? [];
    final invoiceId = await _db.db.insert('sales_invoices', body);
    for (final it in items) {
      await _db.db.insert('sales_invoice_items', {...it, 'invoice_id': invoiceId});
    }
    return invoiceId;
  }

  Future<Map<String, dynamic>?> salesInvoicePrintBundle(int invoiceId) async {
    if (UltraConfig.persistLocally) return _db.salesInvoicePrintBundle(invoiceId);
    final doc = await _getDocument('/api/sales-invoices/$invoiceId');
    if (doc == null) return null;
    final raw = Map<String, dynamic>.from(doc['invoice'] as Map? ?? doc);
    final items = _asRowList(doc['items'] ?? raw.remove('items')).map(_normalizeSalesInvoiceItem).toList();
    final invoice = _normalizeSalesInvoiceRow(_flattenEnvelopeRow(raw));
    return {'invoice': invoice, 'items': items};
  }

  // ---- Purchase orders ----

  Future<int> nextPurchaseOrderNo() async {
    if (UltraConfig.persistLocally) return _db.nextPurchaseOrderNo();
    final list = await _getList('/api/purchase-orders');
    var max = 0;
    for (final row in list) {
      final n = (row['po_no'] as num?)?.toInt() ?? 0;
      if (n > max) max = n;
    }
    return max + 1;
  }

  Future<int> createPurchaseOrder(Map<String, dynamic> body) async {
    if (UltraConfig.persistLocally) return _createWithItems('purchase_orders', 'purchase_order_items', body, 'purchase_order_id');
    return _idFromResponse(await _api.post('/api/purchase-orders', body));
  }

  Future<Map<String, dynamic>?> purchaseOrderPrintBundle(int id) async {
    if (UltraConfig.persistLocally) return _db.purchaseOrderPrintBundle(id);
    final doc = await _getDocument('/api/purchase-orders/$id');
    if (doc == null) return null;
    final order = Map<String, dynamic>.from(doc['order'] as Map? ?? doc);
    final items = _asRowList(doc['items'] ?? order.remove('items'));
    return {'order': _flattenEnvelopeRow(order), 'items': items};
  }

  // ---- Delivery challans ----

  Future<int> createDeliveryChallan(Map<String, dynamic> body) async {
    if (UltraConfig.persistLocally) {
      return _createWithItems('delivery_challans', 'delivery_challan_items', body, 'challan_id');
    }
    return _idFromResponse(await _api.post('/api/delivery-challans', body));
  }

  Future<Map<String, dynamic>?> deliveryChallanPrintBundle(int id) async {
    if (UltraConfig.persistLocally) return _db.deliveryChallanPrintBundle(id);
    final doc = await _getDocument('/api/delivery-challans/$id');
    if (doc == null) return null;
    final challan = Map<String, dynamic>.from(doc['challan'] as Map? ?? doc);
    final items = _asRowList(doc['items'] ?? challan.remove('items'));
    return {'challan': _flattenEnvelopeRow(challan), 'items': items};
  }

  Future<int> nextDeliveryChallanSerial(String dcType) async {
    if (UltraConfig.persistLocally) return _db.nextDeliveryChallanSerial(dcType);
    final list = await _getList('/api/delivery-challans?dc_type=$dcType');
    return list.length + 1;
  }

  Future<List<Map<String, dynamic>>> deliveryChallansList({String? dcType}) async {
    if (UltraConfig.persistLocally) return _db.deliveryChallansList(dcType: dcType);
    final path = dcType == null ? '/api/delivery-challans' : '/api/delivery-challans?dc_type=$dcType';
    return await _getList(path);
  }

  Future<List<Map<String, dynamic>>> purchaseOrdersWithParty() async {
    if (UltraConfig.persistLocally) return _db.purchaseOrdersWithParty();
    return await _getList('/api/purchase-orders');
  }

  Future<void> updatePurchaseOrderStatus(int purchaseOrderId, String status) async {
    if (UltraConfig.persistLocally) {
      await _db.updatePurchaseOrderStatus(purchaseOrderId, status);
      return;
    }
    await _api.put('/api/purchase-orders/$purchaseOrderId/status', {'status': status});
  }

  Future<int> nextQuotationSerial() async {
    if (UltraConfig.persistLocally) return _db.nextQuotationSerial();
    final list = await _getList('/api/quotations');
    return list.length + 1;
  }

  Future<List<Map<String, dynamic>>> quotationsWithParty() async {
    if (UltraConfig.persistLocally) return _db.quotationsWithParty();
    return await _getList('/api/quotations');
  }

  Future<void> updateQuotationStatus(int quotationId, String status) async {
    if (UltraConfig.persistLocally) {
      await _db.updateQuotationStatus(quotationId, status);
      return;
    }
    await _api.put('/api/quotations/$quotationId/status', {'status': status});
  }

  Future<int> nextAdjustmentNoteNo(String noteType) async {
    if (UltraConfig.persistLocally) return _db.nextAdjustmentNoteNo(noteType);
    final list = await _getList('/api/adjustment-notes?note_type=$noteType');
    return list.length + 1;
  }

  Future<List<Map<String, dynamic>>> cashPassbookEntries() async {
    if (UltraConfig.persistLocally) return _db.cashPassbookEntries();
    return await _getList('/api/cash-passbook');
  }

  // ---- Quotations ----

  Future<int> createQuotation(Map<String, dynamic> body) async {
    if (UltraConfig.persistLocally) return _createQuotationLocal(body);
    return _idFromResponse(await _api.post('/api/quotations', body));
  }

  Future<int> _createQuotationLocal(Map<String, dynamic> body) async {
    final items = (body.remove('items') as List?)?.cast<Map<String, dynamic>>() ?? [];
    final terms = (body.remove('terms') as List?)?.cast<Map<String, dynamic>>() ?? [];
    final id = await _db.db.insert('quotations', body);
    for (final it in items) {
      await _db.db.insert('quotation_items', {...it, 'quotation_id': id});
    }
    for (final t in terms) {
      await _db.db.insert('quotation_terms', {...t, 'quotation_id': id});
    }
    return id;
  }

  Future<Map<String, dynamic>?> quotationPrintBundle(int id) async {
    if (UltraConfig.persistLocally) return _db.quotationPrintBundle(id);
    final doc = await _getDocument('/api/quotations/$id');
    if (doc == null) return null;
    final quotation = Map<String, dynamic>.from(doc['quotation'] as Map? ?? doc);
    final items = _asRowList(doc['items'] ?? quotation.remove('items'));
    final terms = _asRowList(doc['terms'] ?? quotation.remove('terms'));
    return {'quotation': _flattenEnvelopeRow(quotation), 'items': items, 'terms': terms};
  }

  // ---- Purchase vouchers ----

  Future<int> createPurchaseVoucher(Map<String, dynamic> body) async {
    if (UltraConfig.persistLocally) {
      final items = (body.remove('items') as List?)?.cast<Map<String, dynamic>>() ?? [];
      final poId = body['purchase_order_id'] as int?;
      final id = await _createWithItems('purchase_vouchers', 'purchase_voucher_items', body, 'voucher_id');
      for (final it in items) {
        final productId = it['product_id'] as int?;
        final qty = (it['quantity'] as num?)?.toDouble() ?? 0;
        if (productId != null) await incrementStock(productId, qty);
      }
      if (poId != null) await markPurchaseOrderReceived(poId);
      return id;
    }
    return _idFromResponse(await _api.post('/api/purchase-vouchers', body));
  }

  Future<int> nextPurchaseVoucherNo() async {
    if (UltraConfig.persistLocally) return _db.nextPurchaseVoucherNo();
    final list = await _getList('/api/purchase-vouchers');
    var max = 0;
    for (final row in list) {
      final n = (row['voucher_no'] as num?)?.toInt() ?? 0;
      if (n > max) max = n;
    }
    return max + 1;
  }

  Future<List<Map<String, dynamic>>> openPurchaseOrders() async {
    if (UltraConfig.persistLocally) return _db.openPurchaseOrders();
    return await _getList('/api/purchase-orders?status=open');
  }

  Future<List<Map<String, dynamic>>> purchaseOrderItems(int purchaseOrderId) async {
    if (UltraConfig.persistLocally) return _db.purchaseOrderItems(purchaseOrderId);
    final bundle = await purchaseOrderPrintBundle(purchaseOrderId);
    if (bundle == null) return [];
    return _asRowList(bundle['items']);
  }

  Future<void> incrementStock(int productId, double qty) async {
    if (UltraConfig.persistLocally) {
      await _db.incrementStock(productId, qty);
      return;
    }
    await _api.post('/api/stock/adjust', {
      'product_id': productId,
      'quantity_delta': qty,
      'reason': 'PURCHASE_VOUCHER',
    });
  }

  Future<void> markPurchaseOrderReceived(int purchaseOrderId) async {
    if (UltraConfig.persistLocally) {
      await _db.markPurchaseOrderReceived(purchaseOrderId);
      return;
    }
    await updatePurchaseOrderStatus(purchaseOrderId, 'RECEIVED');
  }

  // ---- Transactions ----

  Future<int> createAdjustmentNote(Map<String, dynamic> body) async {
    if (UltraConfig.persistLocally) return _createAdjustmentNoteLocal(body);
    return _idFromResponse(await _api.post('/api/adjustment-notes', body));
  }

  Future<int> _createAdjustmentNoteLocal(Map<String, dynamic> body) async {
    final items = (body.remove('items') as List?)?.cast<Map<String, dynamic>>() ?? [];
    final id = await _db.db.insert('adjustment_notes', body);
    for (final it in items) {
      await _db.db.insert('adjustment_note_items', {...it, 'note_id': id});
    }
    return id;
  }

  Future<Map<String, dynamic>?> adjustmentNotePrintBundle(int id) async {
    if (UltraConfig.persistLocally) return _db.adjustmentNotePrintBundle(id);
    final doc = await _getDocument('/api/adjustment-notes/$id');
    if (doc == null) return null;
    final note = Map<String, dynamic>.from(doc['note'] as Map? ?? doc);
    final items = _asRowList(doc['items'] ?? note.remove('items'));
    return {'note': _flattenEnvelopeRow(note), 'items': items};
  }

  Future<List<Map<String, dynamic>>> adjustmentNotesWithParty() async {
    if (UltraConfig.persistLocally) return _db.adjustmentNotesWithParty();
    return await _getList('/api/adjustment-notes');
  }

  Future<int> insertReceipt(Map<String, dynamic> row) async {
    if (UltraConfig.persistLocally) return _db.insertReceipt(row);
    return _idFromResponse(await _api.post('/api/receipts', row));
  }

  Future<int> insertPayment(Map<String, dynamic> row) async {
    if (UltraConfig.persistLocally) return _db.insertPayment(row);
    return _idFromResponse(await _api.post('/api/payments', row));
  }

  Future<List<Map<String, dynamic>>> allReceipts() async {
    if (UltraConfig.persistLocally) return _db.allReceipts();
    return await _getList('/api/receipts');
  }

  Future<List<Map<String, dynamic>>> allPayments() async {
    if (UltraConfig.persistLocally) return _db.allPayments();
    return await _getList('/api/payments');
  }

  Future<List<Map<String, dynamic>>> purchaseVouchersWithParty() async {
    if (UltraConfig.persistLocally) return _db.purchaseVouchersWithParty();
    final vouchers =
        (await _getList('/api/purchase-vouchers')).map(_normalizePurchaseVoucherRow).toList();
    final supplierRows = await suppliers();
    final names = <int, String>{};
    for (final s in supplierRows) {
      final id = s['id'];
      if (id is int) {
        names[id] = '${s['supplier_name'] ?? '-'}';
      } else if (id is num) {
        names[id.toInt()] = '${s['supplier_name'] ?? '-'}';
      }
    }
    for (final v in vouchers) {
      final sid = v['supplier_id'];
      final supplierId = sid is int ? sid : (sid is num ? sid.toInt() : null);
      v['party_name'] ??= (supplierId != null ? names[supplierId] : null) ?? '-';
    }
    return vouchers;
  }

  Future<List<Map<String, dynamic>>> purchaseVoucherItems(int voucherId) async {
    if (UltraConfig.persistLocally) return _db.purchaseVoucherItems(voucherId);
    final doc = await _getDocument('/api/purchase-vouchers/$voucherId');
    if (doc == null) return [];
    return _asRowList(doc['items']).map(_normalizePurchaseVoucherItem).toList();
  }

  Future<Map<String, dynamic>?> purchaseVoucherPrintBundle(int voucherId) async {
    if (UltraConfig.persistLocally) return _db.purchaseVoucherPrintBundle(voucherId);
    final doc = await _getDocument('/api/purchase-vouchers/$voucherId');
    if (doc == null) return null;
    var voucher = _normalizePurchaseVoucherRow(
      Map<String, dynamic>.from(doc['voucher'] as Map? ?? doc),
    );
    voucher = await _enrichPurchaseVoucherWithSupplier(voucher);
    return {
      'voucher': voucher,
      'items': _asRowList(doc['items']).map(_normalizePurchaseVoucherItem).toList(),
    };
  }

  Future<Map<String, dynamic>?> supplierById(int id) async {
    if (UltraConfig.persistLocally) return _db.supplierById(id);
    try {
      return _flattenEnvelopeRow(_asRow(await _api.get('/api/suppliers/$id')));
    } catch (_) {
      for (final s in await suppliers()) {
        if (s['id'] == id) return s;
      }
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> purchaseVouchersForSupplier(int supplierId) async {
    if (UltraConfig.persistLocally) return _db.purchaseVouchersForSupplier(supplierId);
    final all = await purchaseVouchersWithParty();
    return all.where((v) => v['supplier_id'] == supplierId).toList();
  }

  Future<List<Map<String, dynamic>>> paymentsForSupplier(int supplierId) async {
    if (UltraConfig.persistLocally) return _db.paymentsForSupplier(supplierId);
    final all = await allPayments();
    return all.where((p) => p['supplier_id'] == supplierId).toList();
  }

  Future<int> createJournalVoucher(Map<String, dynamic> body) async {
    if (UltraConfig.persistLocally) return _createJournalLocal(body);
    return _idFromResponse(await _api.post('/api/journal-vouchers', body));
  }

  Future<int> _createJournalLocal(Map<String, dynamic> body) async {
    final lines = (body.remove('lines') as List?)?.cast<Map<String, dynamic>>() ?? [];
    final id = await _db.db.insert('journal_vouchers', body);
    for (final line in lines) {
      await _db.db.insert('journal_voucher_lines', {...line, 'voucher_id': id});
    }
    return id;
  }

  Future<List<Map<String, dynamic>>> journalSummaryLines() async {
    if (UltraConfig.persistLocally) return _db.journalSummaryLines();
    return await _getList('/api/journal-vouchers/summary');
  }

  Future<List<Map<String, String>>> masterAccountDirectory() async {
    if (UltraConfig.persistLocally) return _db.masterAccountDirectory();
    final options = <Map<String, String>>[];
    for (final l in await ledgerAccounts()) {
      options.add({
        'key': 'LEDGER:${l['id']}',
        'label': '${l['account_name'] ?? l['name'] ?? ''}',
      });
    }
    for (final c in await customers()) {
      options.add({'key': 'CUSTOMER:${c['id']}', 'label': '${c['customer_name']}'});
    }
    for (final s in await suppliers()) {
      options.add({'key': 'SUPPLIER:${s['id']}', 'label': '${s['supplier_name']}'});
    }
    return options;
  }

  // ---- Local insert helper ----

  Future<int> _createWithItems(
    String headerTable,
    String itemTable,
    Map<String, dynamic> body,
    String fkColumn,
  ) async {
    final items = (body.remove('items') as List?)?.cast<Map<String, dynamic>>() ?? [];
    final id = await _db.db.insert(headerTable, body);
    for (final it in items) {
      await _db.db.insert(itemTable, {...it, fkColumn: id});
    }
    return id;
  }

  /// Expose DB only when local persistence is enabled (reports, dashboards).
  AppDatabase get localDb {
    if (!UltraConfig.persistLocally) {
      throw StateError('Local database is disabled; use UltraRepository API methods.');
    }
    return _db;
  }
}

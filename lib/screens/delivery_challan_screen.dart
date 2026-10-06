import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ultra_repository.dart';
import '../widgets/compact_date_picker.dart';
import '../widgets/delivery_challan_document.dart';
import '../widgets/enterprise_form_fields.dart';
import '../widgets/enterprise_widgets.dart';
import '../widgets/invoice.dart';
import '../widgets/transaction_line_math.dart';
import 'product_catalog_refresh.dart';

final deliveryChallanScreenKey = GlobalKey<DeliveryChallanScreenState>();

abstract class DeliveryChallanScreenState extends State<DeliveryChallanScreen> {
  void openHistory();
  void openEntry();
  Future<void> refreshProductCatalog();
}

enum DcKind { inward, outward, proforma }

extension DcKindX on DcKind {
  String get dbType => switch (this) {
        DcKind.inward => 'INWARD',
        DcKind.outward => 'OUTWARD',
        DcKind.proforma => 'PROFORMA',
      };

  String get headerTitle => switch (this) {
        DcKind.proforma => 'PROFORMA INVOICE ENGINE TERMINAL',
        _ => 'DELIVERY CHALLAN ENGINE TERMINAL',
      };

  Color get accent => switch (this) {
        DcKind.proforma => teal,
        _ => const Color(0xFFE67E22),
      };

  String get saveLabel => switch (this) {
        DcKind.inward => 'SAVE & PRINT INWARD VOUCHER',
        DcKind.outward => 'SAVE & PRINT OUTWARD VOUCHER',
        DcKind.proforma => 'SAVE & PRINT PROFORMA VOUCHER',
      };

  String get historyRegisterLabel => switch (this) {
        DcKind.inward => 'DC INWARD REGISTER',
        DcKind.outward => 'DC OUTWARD REGISTER',
        DcKind.proforma => 'PROFORMA ESTIMATES',
      };
}

class DeliveryChallanScreen extends StatefulWidget {
  const DeliveryChallanScreen({super.key});
  @override
  DeliveryChallanScreenState createState() => _DeliveryChallanScreenState();
}

class _DeliveryChallanScreenState extends DeliveryChallanScreenState {
  final repo = UltraRepository.instance;
  DcKind kind = DcKind.outward;
  bool showHistory = false;
  String historyRegister = 'INWARD';
  final historySearch = TextEditingController();

  String serialNo = '';
  String docDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final poRef = TextEditingController();
  String poRefDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final packages = TextEditingController();
  final vehicle = TextEditingController();
  final creditDays = TextEditingController(text: '0');
  final validityDays = TextEditingController(text: '0');
  final eway = TextEditingController();
  final fwd = TextEditingController(text: '0');
  final billingAddress = TextEditingController();
  final city = TextEditingController();
  final pin = TextEditingController();
  final gstin = TextEditingController();
  final accountRef = TextEditingController();
  final deliverySite = TextEditingController();

  String? partyKey;
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> units = [];
  List<Map<String, dynamic>> historyRows = [];
  final rows = [_DcRow()];

  late final Future<void> Function() _productCatalogRefreshHandler;

  @override
  void initState() {
    super.initState();
    _productCatalogRefreshHandler = refreshProductCatalog;
    registerProductCatalogRefresh(_productCatalogRefreshHandler);
    load();
  }

  @override
  Future<void> refreshProductCatalog() async {
    products = await repo.products();
    units = await repo.units();
    if (mounted) setState(() {});
  }

  @override
  void openHistory() {
    setState(() => showHistory = true);
    refreshHistory();
  }

  @override
  void openEntry() {
    setState(() => showHistory = false);
  }

  Future<void> load() async {
    customers = await repo.customers();
    suppliers = await repo.suppliers();
    products = await repo.products();
    units = await repo.units();
    await refreshSerial();
    if (mounted) setState(() {});
  }

  Future<void> refreshSerial() async {
    serialNo = '${await repo.nextDeliveryChallanSerial(kind.dbType)}';
  }

  Future<void> refreshHistory() async {
    historyRows = await repo.deliveryChallansList();
    if (mounted) setState(() {});
  }

  void _fillParty(String key) {
    partyKey = key;
    final parts = key.split(':');
    if (parts.length != 2) return;
    final kindStr = parts[0];
    final id = int.tryParse(parts[1]);
    if (id == null) return;
    Map<String, dynamic>? p;
    if (kindStr == 'SUPPLIER') {
      for (final s in suppliers) {
        if (s['id'] == id) {
          p = s;
          break;
        }
      }
    } else {
      for (final c in customers) {
        if (c['id'] == id) {
          p = c;
          break;
        }
      }
    }
    if (p == null) return;
    billingAddress.text = p['address'] ?? '';
    city.text = p['city'] ?? '';
    pin.text = p['postal_pincode'] ?? '';
    gstin.text = p['gstin'] ?? '';
    accountRef.text = p['bank_account_no'] ?? p['customer_code'] ?? '';
    deliverySite.text = p['shipping_address'] ?? p['address'] ?? '';
  }

  TransactionLineTotals _lineTotals(_DcRow r) => TransactionLineTotals.compute(
        qty: r.qty,
        rate: r.rate,
        cgstPct: r.cgstPct,
        sgstPct: r.sgstPct,
        igstPct: r.igstPct,
      );

  double get baseValue => rows.fold(0, (s, r) => s + _lineTotals(r).taxable);
  double get cgstTotal => rows.fold(0, (s, r) => s + _lineTotals(r).cgst);
  double get sgstTotal => rows.fold(0, (s, r) => s + _lineTotals(r).sgst);
  double get igstTotal => rows.fold(0, (s, r) => s + _lineTotals(r).igst);
  double get taxTotal => cgstTotal + sgstTotal + igstTotal;
  double get fwdVal => double.tryParse(fwd.text.trim()) ?? 0;
  double get grandTotal => baseValue + taxTotal + fwdVal;
  double get totalPcs => rows.fold<double>(0, (s, r) => s + r.qty);

  double _availableStock(int? productId) {
    if (productId == null) return 0;
    for (final p in products) {
      if (coerceCatalogId(p['id']) == productId) {
        return repo.productStockOnHand(p);
      }
    }
    return 0;
  }

  List<DropdownMenuItem<String>> get _partyItems {
    final items = <DropdownMenuItem<String>>[];
    if (kind == DcKind.inward) {
      for (final s in suppliers) {
        items.add(DropdownMenuItem(
          value: 'SUPPLIER:${s['id']}',
          child: Text('${s['supplier_name']}', style: const TextStyle(color: red, fontSize: 11)),
        ));
      }
      return items;
    }
    for (final c in customers) {
      items.add(DropdownMenuItem(
        value: 'CUSTOMER:${c['id']}',
        child: Text('${c['customer_name']}', style: const TextStyle(color: Color(0xFF1A5FB4), fontSize: 11)),
      ));
    }
    return items;
  }

  void _disposeAllRows() {
    for (final r in rows) {
      r.dispose();
    }
  }

  @override
  void dispose() {
    unregisterProductCatalogRefresh(_productCatalogRefreshHandler);
    _disposeAllRows();
    for (final c in [poRef, packages, vehicle, creditDays, validityDays, eway, fwd, billingAddress, city, pin, gstin, accountRef, deliverySite, historySearch]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(String current, ValueChanged<String> onPicked) async {
    final picked = await pickCompactDate(context, initialDate: DateTime.tryParse(current) ?? DateTime.now());
    if (picked != null) onPicked(formatIsoDate(picked));
  }

  String _display(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd-MM-yyyy').format(d);
  }

  String? _validateBeforeSave() {
    if (partyKey == null) {
      return kind == DcKind.inward
          ? 'Please select a supplier before saving.'
          : 'Please select a customer before saving.';
    }
    final parts = partyKey!.split(':');
    if (parts.length != 2) return 'Invalid party selection.';
    if (kind == DcKind.inward && parts[0] != 'SUPPLIER') {
      return 'DC Inward requires a supplier.';
    }
    if (kind != DcKind.inward && parts[0] != 'CUSTOMER') {
      return 'DC Outward and Proforma require a customer.';
    }
    if (docDate.trim().isEmpty) return 'Document date is required.';
    final validRows = rows.where((r) => r.productId != null).toList();
    if (validRows.isEmpty) return 'Add at least one product line.';
    for (final r in validRows) {
      if (r.qty <= 0) return 'Quantity must be greater than zero for ${r.description}.';
      if (r.rate <= 0) return 'Rate must be greater than zero for ${r.description}.';
      if (kind == DcKind.outward) {
        final avail = _availableStock(r.productId);
        if (r.qty > avail) {
          return 'Insufficient stock for ${r.description}: available ${avail.toStringAsFixed(0)}, requested ${r.qty.toStringAsFixed(0)}.';
        }
      }
    }
    return null;
  }

  Future<int?> _persistChallan() async {
    final validation = _validateBeforeSave();
    if (validation != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validation)));
      }
      return null;
    }
    final parts = partyKey!.split(':');
    final uuid = repo.newUuid();
    final docPrefix = kind == DcKind.proforma ? 'PI' : 'DC';
    final docId =
        '$docPrefix-${DateTime.now().year}-${uuid.replaceAll('-', '').substring(0, 6).toUpperCase()}';
    final items = rows
        .where((r) => r.productId != null)
        .map(
          (r) {
            final t = _lineTotals(r);
            return {
              'product_id': r.productId,
              'description': r.description,
              'uom': r.uom,
              'hsn': r.hsn,
              'quantity': r.qty,
              'rate': r.rate,
              'cgst_percent': r.cgstPct,
              'sgst_percent': r.sgstPct,
              'igst_percent': r.igstPct,
              'extended_value': t.total,
              'remarks': r.remarks,
            };
          },
        )
        .toList();
    try {
      return await repo.createDeliveryChallan({
        'uuid': uuid,
        'dc_type': kind.dbType,
        'serial_no': int.tryParse(serialNo),
        'doc_id': docId,
        'document_date': docDate,
        'po_ref_no': poRef.text,
        'po_ref_date': poRefDate,
        'total_packages': int.tryParse(packages.text) ?? 0,
        'vehicle_dispatch': vehicle.text,
        'credit_due_days': int.tryParse(creditDays.text) ?? 0,
        'eway_bill_no': eway.text,
        'validity_days': int.tryParse(validityDays.text) ?? 0,
        'party_kind': parts[0],
        'party_id': int.parse(parts[1]),
        'billing_address': billingAddress.text,
        'city': city.text,
        'pincode': pin.text,
        'gstin': gstin.text,
        'account_ref': accountRef.text,
        'delivery_site_address': deliverySite.text,
        'fwd_charge': fwdVal,
        'base_value': baseValue,
        'tax_total': taxTotal,
        'grand_total': grandTotal,
        'total_pcs': totalPcs,
        'created_at': DateTime.now().toIso8601String(),
        'items': items,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save Delivery Challan: $e')),
        );
      }
      return null;
    }
  }

  void _resetForm() {
    _disposeAllRows();
    setState(() {
      rows
        ..clear()
        ..add(_DcRow());
      partyKey = null;
      poRef.clear();
      packages.clear();
      vehicle.clear();
      creditDays.text = '0';
      validityDays.text = '0';
      eway.clear();
      fwd.text = '0';
      billingAddress.clear();
      city.clear();
      pin.clear();
      gstin.clear();
      accountRef.clear();
      deliverySite.clear();
    });
  }

  Future<void> _saveAndPrint() async {
    final id = await _persistChallan();
    if (id == null) return;
    try {
      await reprintDeliveryChallan(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('DOCUMENT SAVED — PRINT DIALOG OPENED')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document saved, but printing failed: $e')),
        );
      }
    }
    await load();
    historyRegister = kind.dbType;
    await refreshHistory();
    _resetForm();
  }

  List<Map<String, dynamic>> get _filteredHistory {
    final q = historySearch.text.trim().toLowerCase();
    return historyRows.where((r) {
      if (r['dc_type'] != historyRegister) return false;
      if (q.isEmpty) return true;
      final hay = '${r['serial_no']} ${r['doc_id']} ${r['po_ref_no']} ${r['party_name']}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (showHistory) return _historyView();
    return _entryView();
  }

  Widget _historyView() {
    final list = _filteredHistory;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(onPressed: () => setState(() => showHistory = false), icon: const Icon(Icons.arrow_back)),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('INVENTORY VOUCHERS DIRECTORY', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
                    Text('LOGISTICS DISPATCH MATERIAL MOVEMENT RUNNING AUDIT TRAILS',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF748094))),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined, color: Color(0xFFE67E22), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        switch (historyRegister) {
                          'INWARD' => 'DC INWARD REGISTER',
                          'OUTWARD' => 'DC OUTWARD REGISTER',
                          _ => 'PROFORMA ESTIMATES',
                        },
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
                onSelected: (v) => setState(() => historyRegister = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'INWARD', child: Text('DC INWARD REGISTER')),
                  PopupMenuItem(value: 'OUTWARD', child: Text('DC OUTWARD REGISTER')),
                  PopupMenuItem(value: 'PROFORMA', child: Text('PROFORMA ESTIMATES')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: historySearch,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'SEARCH ENTRIES BY AUTO NO, DC NO, PO REF, PARTY NAME...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(height: 16),
          ...list.map(_historyCard),
        ],
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> row) {
    final id = row['id'] as int;
    final type = '${row['dc_type']}';
    final amt = (row['grand_total'] as num?)?.toDouble() ?? 0;
    final pcs = (row['total_pcs'] as num?)?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: border), borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${row['party_name']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      color: const Color(0xFFE8ECF0),
                      child: Text(type, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'SERIAL NO: ${row['serial_no']}  ·  DOC ID: ${row['doc_id']}  ·  DATE: ${_display('${row['document_date']}')}  ·  PO REF: ${row['po_ref_no']}',
                  style: const TextStyle(fontSize: 10, color: teal, fontWeight: FontWeight.w600),
                ),
                if ('${row['vehicle_dispatch']}'.isNotEmpty)
                  Text('DISPATCH LOGISTICS VEHICLE: ${row['vehicle_dispatch']}',
                      style: const TextStyle(fontSize: 9.5, color: Color(0xFF748094))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹ ${amt.toStringAsFixed(2)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              Text('${pcs.toStringAsFixed(0)} PCS TOTAL', style: const TextStyle(fontSize: 9, color: Color(0xFF748094))),
            ],
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () async {
              try {
                await reprintDeliveryChallan(id);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to load Delivery Challan for reprint: $e')),
                  );
                }
              }
            },
            child: const Icon(Icons.print_outlined, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _entryView() {
    final accent = kind.accent;
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: enterpriseScrollColumn(children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF19232C),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < formTwoColumnMinWidth;
                final typeButtons = Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _typeBtn('DC INWARD', DcKind.inward, accent),
                    _typeBtn('DC OUTWARD', DcKind.outward, accent),
                    _typeBtn('PROFORMA', DcKind.proforma, accent),
                  ],
                );
                final totalBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹ ${grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Color(0xFFF4D53A),
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                    const Text('NET GRAND VALUE',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700)),
                  ],
                );
                final stats = Wrap(
                  spacing: 18,
                  runSpacing: 6,
                  children: [
                    _mini('TOTAL PCS', totalPcs.toStringAsFixed(0)),
                    _mini('TAXABLE', baseValue.toStringAsFixed(2)),
                    _mini('TOTAL TAX', taxTotal.toStringAsFixed(2)),
                  ],
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kind.headerTitle,
                          style: TextStyle(
                              color: accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      stats,
                      const SizedBox(height: 10),
                      typeButtons,
                      const SizedBox(height: 10),
                      Align(alignment: Alignment.centerLeft, child: totalBlock),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(kind.headerTitle,
                              style: TextStyle(
                                  color: accent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          stats,
                        ],
                      ),
                    ),
                    typeButtons,
                    const SizedBox(width: 14),
                    totalBlock,
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final stacked = c.maxWidth < formTwoColumnMinWidth;
                    final s1 = _section(
                      'SECTION 1: CONSIGNMENT METADATA',
                      [
                        _pair(
                          _ro(kind == DcKind.proforma ? 'PROFORMA SERIAL NO (AUTO)' : 'CHALLAN / DC NUMERIC NO *', serialNo),
                          _date('DOCUMENT DATE', docDate, (v) => setState(() => docDate = v)),
                        ),
                        _pair(
                          _field('PO REFERENCE NO', poRef, autofocus: true),
                          _date('PO REFERENCE DATE', poRefDate, (v) => setState(() => poRefDate = v)),
                        ),
                        _pair(
                          _field('TOTAL NO OF PACKAGES', packages),
                          _field('VEHICLE NO / DISPATCH MODE', vehicle),
                        ),
                        if (kind == DcKind.proforma)
                          _field('VALIDITY DAYS', validityDays)
                        else
                          _pair(_field('CREDIT DUE DAYS', creditDays), _field('E-WAY BILL NO (EWB)', eway)),
                      ],
                    );
                    final s2 = _section(
                      'SECTION 2: ACCOUNT / PARTY INFORMATION',
                      [
                        enterpriseInsetDropdown<String>(
                          label: 'SELECT TRANS-PARTY PROFILE (SUPPLIER / CUSTOMER) *',
                          value: partyKey,
                          hint: const Text('Choose supplier or customer', style: TextStyle(fontSize: 11)),
                          items: _partyItems,
                          onChanged: (v) => setState(() => _fillParty(v!)),
                        ),
                        const SizedBox(height: 10),
                        _field('OFFICIAL BILLING ADDRESS', billingAddress, maxLines: 2),
                        _pair(_field('CITY', city), _field('POSTAL PINCODE', pin)),
                        _pair(_field('PARTY GSTIN REFERENCE', gstin), _field('ACCOUNT REFERENCE NO', accountRef)),
                        _field('DELIVERY SITE DESTINATION ADDRESS', deliverySite, maxLines: 2),
                      ],
                    );
                    if (stacked) return Column(children: [s1, const SizedBox(height: 14), s2]);
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: s1), const SizedBox(width: 14), Expanded(child: s2)]);
                  },
                ),
                const SizedBox(height: 18),
                const Text('SECTION 3: MATERIAL MATRIX GRID ENTRY', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: navy)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(4), color: Colors.white),
                  child: enterpriseMatrixScroller(table: _matrix(context)),
                ),
                const SizedBox(height: 10),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => rows.add(_DcRow())),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+ ADD NEW MATERIAL ROW', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                  ),
                ),
                if (kind == DcKind.outward)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Available stock is shown per product. Outward quantity cannot exceed stock on hand.',
                      style: const TextStyle(fontSize: 9.5, color: Color(0xFF748094), fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 14),
                enterpriseValueWordsFooter(
                  valueInWords: _words(grandTotal),
                  chargeController: fwd,
                  onChargeChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _saveAndPrint,
                    icon: const Icon(Icons.print_outlined),
                    label: Text(kind.saveLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(backgroundColor: green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBtn(String label, DcKind k, Color accent) {
    final active = kind == k;
    return OutlinedButton(
      onPressed: () async {
        kind = k;
        partyKey = null;
        billingAddress.clear();
        city.clear();
        pin.clear();
        gstin.clear();
        accountRef.clear();
        deliverySite.clear();
        await refreshSerial();
        setState(() {});
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? accent : Colors.transparent,
        foregroundColor: active ? Colors.white : Colors.white70,
        side: BorderSide(color: active ? accent : Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }

  Table _matrix(BuildContext context) {
    final proforma = kind == DcKind.proforma;
    return Table(
      columnWidths: deliveryChallanMatrixColumns(
        proforma: proforma,
        includeRemarks: !proforma,
        showAvailableStock: kind == DcKind.outward,
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(color: navy2),
          children: [
            _h('SL'),
            _h('MATERIAL DESCRIPTION'),
            _h('UOM'),
            _h('HSN'),
            _h('QTY'),
            _h('RATE/VAL'),
            if (proforma) _h('CGST%'),
            if (proforma) _h('SGST%'),
            if (proforma) _h('IGST%'),
            if (kind == DcKind.outward) _h('AVAIL'),
            _h('LINE TOTAL'),
            if (!proforma) _h('REMARKS / DELIVERY PURPOSE'),
            const SizedBox.shrink(),
          ],
        ),
        ...List.generate(rows.length, (i) {
          final r = rows[i];
          final lineTotal = _lineTotals(r).total;
          return TableRow(
            children: [
              Text('${i + 1}', style: const TextStyle(fontSize: 9)),
              _prodDrop(i),
              _uomDrop(i),
              Text(r.hsn, style: const TextStyle(fontSize: 9)),
              _num(context, i, r.qtyController, (v) => r.qty = v),
              _num(context, i, r.rateController, (v) => r.rate = v),
              if (proforma) _num(context, i, r.cgstController, (v) => r.cgstPct = v),
              if (proforma) _num(context, i, r.sgstController, (v) => r.sgstPct = v),
              if (proforma) _num(context, i, r.igstController, (v) => r.igstPct = v),
              if (kind == DcKind.outward)
                Text(
                  r.productId == null ? '-' : _availableStock(r.productId).toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: r.productId != null && r.qty > _availableStock(r.productId) ? red : null,
                  ),
                ),
              Text(lineTotal.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
              if (!proforma)
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: enterpriseMatrixTextField(
                    context: context,
                    controller: r.remarksController,
                    onChanged: (v) => r.remarks = v,
                  ),
                ),
              IconButton(
                onPressed: rows.length == 1
                    ? null
                    : () => setState(() {
                          rows[i].dispose();
                          rows.removeAt(i);
                        }),
                icon: const Icon(Icons.delete_outline, color: red, size: 17),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _prodDrop(int i) => DropdownButton<int>(
        isExpanded: true,
        isDense: true,
        hint: const Text('Item Description', style: TextStyle(fontSize: 9)),
        value: rows[i].productId,
        items: products.map((p) => DropdownMenuItem(value: p['id'] as int, child: Text('${p['product_name']}', style: const TextStyle(fontSize: 9)))).toList(),
        onChanged: (v) {
          final p = products.firstWhere((x) => coerceCatalogId(x['id']) == v);
          setState(() => rows[i].setProduct(p, kind: kind));
        },
      );

  Widget _uomDrop(int i) => DropdownButton<int>(
        isExpanded: true,
        isDense: true,
        value: rows[i].unitId,
        hint: const Text('UOM', style: TextStyle(fontSize: 9)),
        items: units.map((u) => DropdownMenuItem(value: u['id'] as int, child: Text('${u['code']}', style: const TextStyle(fontSize: 9)))).toList(),
        onChanged: (v) {
          final u = units.firstWhere((x) => x['id'] == v);
          setState(() {
            rows[i].unitId = v;
            rows[i].uom = '${u['code']}';
          });
        },
      );

  Widget _num(
    BuildContext context,
    int i,
    TextEditingController controller,
    ValueChanged<double> on,
  ) =>
      Padding(
        padding: const EdgeInsets.all(2),
        child: enterpriseMatrixTextField(
          context: context,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          controller: controller,
          onChanged: (v) => setState(() => on(double.tryParse(v.trim()) ?? 0)),
        ),
      );

  Widget _h(String t) => Padding(padding: const EdgeInsets.all(6), child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w800)));

  Widget _mini(String l, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l, style: const TextStyle(color: Colors.white54, fontSize: 8)),
          Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
        ],
      );

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: navy)),
          const Divider(),
          ...children,
        ],
      );

  Widget _pair(Widget a, Widget b) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]),
      );

  Widget _field(String label, TextEditingController c, {int maxLines = 1, bool autofocus = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: enterpriseInsetTextField(label: label, controller: c, maxLines: maxLines, autofocus: autofocus),
      );

  Widget _ro(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: enterpriseInsetTextField(
          label: label,
          controller: TextEditingController(text: value),
          readOnly: true,
          filled: true,
        ),
      );

  Widget _date(String label, String iso, ValueChanged<String> on) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: enterpriseInsetDateField(
          label: label,
          isoDate: iso,
          onTap: () => _pickDate(iso, (v) => setState(() => on(v))),
        ),
      );

  String _words(double v) => formatUltraAmountInWords(v);
}

String _dcMatrixNum(double v) {
  if (v == 0) return '';
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
}

class _DcRow {
  int? productId;
  int? unitId;
  String description = '';
  String uom = 'PCS';
  String hsn = '';
  String remarks = '';
  double qty = 0;
  double rate = 0;
  double cgstPct = 9;
  double sgstPct = 9;
  double igstPct = 0;

  late final TextEditingController qtyController;
  late final TextEditingController rateController;
  late final TextEditingController cgstController;
  late final TextEditingController sgstController;
  late final TextEditingController igstController;
  late final TextEditingController remarksController;

  _DcRow() {
    qtyController = TextEditingController();
    rateController = TextEditingController();
    cgstController = TextEditingController(text: _dcMatrixNum(cgstPct));
    sgstController = TextEditingController(text: _dcMatrixNum(sgstPct));
    igstController = TextEditingController(text: _dcMatrixNum(igstPct));
    remarksController = TextEditingController();
  }

  void dispose() {
    qtyController.dispose();
    rateController.dispose();
    cgstController.dispose();
    sgstController.dispose();
    igstController.dispose();
    remarksController.dispose();
  }

  void setProduct(Map<String, dynamic> p, {required DcKind kind}) {
    productId = coerceCatalogId(p['id']);
    description = '${p['product_name'] ?? ''}';
    unitId = catalogUnitId(p);
    uom = catalogUomCode(p);
    hsn = catalogProductHsn(p);
    rate = kind == DcKind.inward ? catalogPurchaseRate(p) : catalogSalesRate(p);
    rateController.text = _dcMatrixNum(rate);
    final productGst = catalogTotalGstPercent(p);
    if (productGst != null && productGst > 0) {
      applyZoneGstSplit(
        interState: false,
        totalGstPercent: productGst,
        apply: (c, s, i) {
          cgstPct = c;
          sgstPct = s;
          igstPct = i;
        },
      );
    }
    cgstController.text = _dcMatrixNum(cgstPct);
    sgstController.text = _dcMatrixNum(sgstPct);
    igstController.text = _dcMatrixNum(igstPct);
  }
}

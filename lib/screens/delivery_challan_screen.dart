import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ultra_repository.dart';
import '../widgets/compact_date_picker.dart';
import '../widgets/delivery_challan_document.dart';
import '../widgets/enterprise_widgets.dart';

final deliveryChallanScreenKey = GlobalKey<DeliveryChallanScreenState>();

abstract class DeliveryChallanScreenState extends State<DeliveryChallanScreen> {
  void openHistory();
  void openEntry();
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

  @override
  void initState() {
    super.initState();
    load();
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

  double get baseValue => rows.fold(0, (s, r) => s + r.extended);
  double get taxTotal => kind == DcKind.proforma ? rows.fold(0, (s, r) => s + r.taxAmount) : 0;
  double get fwdVal => double.tryParse(fwd.text) ?? 0;
  double get grandTotal => baseValue + taxTotal + fwdVal;
  double get totalPcs => rows.fold<double>(0, (s, r) => s + r.qty);

  List<DropdownMenuItem<String>> get _partyItems {
    final items = <DropdownMenuItem<String>>[];
    for (final s in suppliers) {
      items.add(DropdownMenuItem(
        value: 'SUPPLIER:${s['id']}',
        child: Text('[SUPPLIER] ${s['supplier_name']}', style: const TextStyle(color: red, fontSize: 11)),
      ));
    }
    for (final c in customers) {
      items.add(DropdownMenuItem(
        value: 'CUSTOMER:${c['id']}',
        child: Text('[CUSTOMER] ${c['customer_name']}', style: const TextStyle(color: Color(0xFF1A5FB4), fontSize: 11)),
      ));
    }
    return items;
  }

  @override
  void dispose() {
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

  Future<void> _saveAndPrint() async {
    if (partyKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select trans-party profile (supplier / customer).')));
      return;
    }
    final parts = partyKey!.split(':');
    final uuid = repo.newUuid();
    final docId = 'DC-${DateTime.now().year}-${uuid.replaceAll('-', '').substring(0, 6).toUpperCase()}';
    final items = rows
        .map(
          (r) => {
            'product_id': r.productId,
            'description': r.description,
            'uom': r.uom,
            'hsn': r.hsn,
            'quantity': r.qty,
            'rate': r.rate,
            'cgst_percent': r.cgstPct,
            'sgst_percent': r.sgstPct,
            'igst_percent': r.igstPct,
            'extended_value': r.extended + (kind == DcKind.proforma ? r.taxAmount : 0),
            'remarks': r.remarks,
          },
        )
        .toList();
    final id = await repo.createDeliveryChallan({
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
    await reprintDeliveryChallan(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DELIVERY CHALLAN SAVED — PRINT OPENED')));
    }
    await load();
    setState(() {
      rows..clear()..add(_DcRow());
      poRef.clear();
      packages.clear();
      vehicle.clear();
      eway.clear();
      partyKey = null;
    });
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
          OutlinedButton(onPressed: () => reprintDeliveryChallan(id), child: const Icon(Icons.print_outlined, size: 18)),
        ],
      ),
    );
  }

  Widget _entryView() {
    final accent = kind.accent;
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF19232C),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kind.headerTitle, style: TextStyle(color: accent, fontSize: 14, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 18,
                        children: [
                          _mini('TOTAL PCS', totalPcs.toStringAsFixed(0)),
                          _mini('BASE VALUE', baseValue.toStringAsFixed(2)),
                          if (kind == DcKind.proforma) _mini('TOTAL TAX', taxTotal.toStringAsFixed(2)),
                        ],
                      ),
                    ],
                  ),
                ),
                _typeBtn('DC INWARD', DcKind.inward, accent),
                const SizedBox(width: 6),
                _typeBtn('DC OUTWARD', DcKind.outward, accent),
                const SizedBox(width: 6),
                _typeBtn('PROFORMA', DcKind.proforma, accent),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹ ${grandTotal.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFF4D53A), fontSize: 20, fontWeight: FontWeight.w900)),
                    const Text('NET GRAND VALUE', style: TextStyle(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final stacked = c.maxWidth < 980;
                    final s1 = _section(
                      'SECTION 1: CONSIGNMENT METADATA',
                      [
                        _pair(
                          _ro(kind == DcKind.proforma ? 'PROFORMA SERIAL NO (AUTO)' : 'CHALLAN / DC NUMERIC NO *', serialNo),
                          _date('DOCUMENT DATE', docDate, (v) => setState(() => docDate = v)),
                        ),
                        _pair(
                          _field('PO REFERENCE NO', poRef),
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
                        DropdownButtonFormField<String>(
                          value: partyKey,
                          isExpanded: true,
                          decoration: _dec('SELECT TRANS-PARTY PROFILE (SUPPLIER / CUSTOMER) *'),
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
                  decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(4), color: Colors.white),
                  child: _matrix(),
                ),
                const SizedBox(height: 10),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => rows.add(_DcRow())),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+ ADD NEW MATERIAL ROW', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        color: const Color(0xFF19232C),
                        child: Text('VALUE IN WORDS: ${_words(grandTotal)}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 110,
                      padding: const EdgeInsets.all(10),
                      color: const Color(0xFF19232C),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('FWD CHARGE', style: TextStyle(color: Colors.white54, fontSize: 8)),
                          TextField(
                            controller: fwd,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(color: Color(0xFFF4D53A), fontWeight: FontWeight.w900),
                            decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                          ),
                        ],
                      ),
                    ),
                  ],
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

  Widget _matrix() {
    final proforma = kind == DcKind.proforma;
    final widths = <int, TableColumnWidth>{
      0: const FixedColumnWidth(22),
      1: const FlexColumnWidth(2.2),
      2: const FixedColumnWidth(38),
      3: const FixedColumnWidth(42),
      4: const FixedColumnWidth(36),
      5: const FixedColumnWidth(40),
    };
    var col = 6;
    if (proforma) {
      widths[col++] = const FixedColumnWidth(32);
      widths[col++] = const FixedColumnWidth(32);
      widths[col++] = const FixedColumnWidth(32);
    }
    widths[col++] = const FixedColumnWidth(48);
    if (!proforma) widths[col++] = const FixedColumnWidth(56);
    widths[col] = const FixedColumnWidth(26);
    return Table(
      columnWidths: widths,
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
            _h('EXTENDED VAL'),
            if (!proforma) _h('REMARKS / DELIVERY PURPOSE'),
            const SizedBox.shrink(),
          ],
        ),
        ...List.generate(rows.length, (i) {
          final r = rows[i];
          return TableRow(
            children: [
              Text('${i + 1}', style: const TextStyle(fontSize: 9)),
              _prodDrop(i),
              _uomDrop(i),
              Text(r.hsn, style: const TextStyle(fontSize: 9)),
              _num(i, (v) => r.qty = v),
              _num(i, (v) => r.rate = v, rate: true),
              if (proforma) _num(i, (v) => r.cgstPct = v, pct: true, val: r.cgstPct),
              if (proforma) _num(i, (v) => r.sgstPct = v, pct: true, val: r.sgstPct),
              if (proforma) _num(i, (v) => r.igstPct = v, pct: true, val: r.igstPct),
              Text((proforma ? r.displayExtended : r.extended).toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
              if (!proforma)
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: TextField(
                    decoration: const InputDecoration(isDense: true, hintText: 'Delivery Purpose'),
                    style: const TextStyle(fontSize: 9),
                    onChanged: (v) => r.remarks = v,
                  ),
                ),
              IconButton(
                onPressed: rows.length == 1 ? null : () => setState(() => rows.removeAt(i)),
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
          final p = products.firstWhere((x) => x['id'] == v);
          setState(() => rows[i].setProduct(p));
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

  Widget _num(int i, ValueChanged<double> on, {bool rate = false, bool pct = false, double? val}) => Padding(
        padding: const EdgeInsets.all(2),
        child: TextField(
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 9),
          controller: pct ? TextEditingController(text: '${val ?? 0}') : null,
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(4)),
          onChanged: (v) => setState(() => on(double.tryParse(v) ?? 0)),
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
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]),
      );

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: border)),
      );

  Widget _field(String label, TextEditingController c, {int maxLines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(controller: c, maxLines: maxLines, decoration: _dec(label), style: const TextStyle(fontSize: 11.5)),
      );

  Widget _ro(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          readOnly: true,
          controller: TextEditingController(text: value),
          decoration: _dec(label).copyWith(fillColor: const Color(0xFFF1F3F7), filled: true),
        ),
      );

  Widget _date(String label, String iso, ValueChanged<String> on) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          readOnly: true,
          controller: TextEditingController(text: _display(iso)),
          decoration: _dec(label).copyWith(prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16)),
          onTap: () => _pickDate(iso, (v) => setState(() => on(v))),
        ),
      );

  String _words(double v) => v == 0 ? 'ZERO RUPEES ONLY' : '₹${v.toStringAsFixed(2)} ONLY';
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
  double igstPct = 18;

  void setProduct(Map<String, dynamic> p) {
    productId = p['id'] as int?;
    description = '${p['product_name']}';
    unitId = p['unit_id'] as int?;
    uom = '${p['uom_code'] ?? 'PCS'}';
    hsn = '${p['hsn'] ?? ''}';
    rate = (p['rate'] ?? 0).toDouble();
  }

  double get extended => qty * rate;
  double get taxAmount => extended * (cgstPct + sgstPct + igstPct) / 100;
  double get displayExtended => extended + taxAmount;
}

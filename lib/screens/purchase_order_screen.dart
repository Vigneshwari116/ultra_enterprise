import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ultra_repository.dart';
import '../widgets/compact_date_picker.dart';
import '../widgets/enterprise_form_fields.dart';
import '../widgets/enterprise_widgets.dart';
import '../widgets/purchase_order_document.dart';

class PurchaseOrderScreen extends StatefulWidget {
  const PurchaseOrderScreen({super.key});
  @override State<PurchaseOrderScreen> createState() => _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends State<PurchaseOrderScreen> {
  final repo = UltraRepository.instance;
  final supplierRef = TextEditingController();
  final packages = TextEditingController();
  final deliveryMode = TextEditingController();
  final remarks = TextEditingController();
  final dueDays = TextEditingController(text: '0');
  final freight = TextEditingController(text: '0');
  final supplierAddress = TextEditingController();
  final city = TextEditingController();
  final pin = TextEditingController();
  final gstin = TextEditingController();
  final bank = TextEditingController();
  final account = TextEditingController();
  final directorySearch = TextEditingController();

  String poDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String dueDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String poNo = '';
  String zone = '';

  bool showDirectory = false;
  String directoryPartyFilter = 'ALL';
  List<Map<String, dynamic>> directoryRows = [];

  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> units = [];
  int? supplierId;
  final rows = [_PoRow()];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    suppliers = await repo.suppliers();
    products = await repo.products();
    units = await repo.units();
    poNo = '${await repo.nextPurchaseOrderNo()}';
    directoryRows = await repo.purchaseOrdersWithParty();
    if (suppliers.isNotEmpty && supplierId == null) {
      supplierId = suppliers.first['id'] as int;
      fillSupplier(suppliers.first);
    }
    if (mounted) setState(() {});
  }

  void fillSupplier(Map<String, dynamic> s) {
    supplierAddress.text = s['address'] ?? '';
    city.text = s['city'] ?? '';
    pin.text = s['postal_pincode'] ?? '';
    gstin.text = s['gstin'] ?? '';
    bank.text = s['bank_name'] ?? '';
    account.text = s['bank_account_no'] ?? '';
  }

  void _syncDueDateFromDays() {
    final days = int.tryParse(dueDays.text) ?? 0;
    final base = DateTime.tryParse(poDate) ?? DateTime.now();
    dueDate = DateFormat('yyyy-MM-dd').format(base.add(Duration(days: days)));
  }

  double get taxable => rows.fold(0, (s, r) => s + r.taxable);
  double get cgst => rows.fold(0, (s, r) => s + r.cgst);
  double get sgst => rows.fold(0, (s, r) => s + r.sgst);
  double get igst => rows.fold(0, (s, r) => s + r.igst);
  double get gstTotal => cgst + sgst + igst;
  double get freightVal => double.tryParse(freight.text) ?? 0;
  double get total => taxable + gstTotal + freightVal;
  double get totalQty => rows.fold<double>(0, (s, r) => s + r.qty);

  @override
  void dispose() {
    for (final c in [
      supplierRef,
      packages,
      deliveryMode,
      remarks,
      dueDays,
      freight,
      supplierAddress,
      city,
      pin,
      gstin,
      bank,
      account,
      directorySearch,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(String currentIso, ValueChanged<String> onPicked) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(currentIso) ?? now;
    final picked = await pickCompactDate(
      context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      onPicked(formatIsoDate(picked));
      _syncDueDateFromDays();
    }
  }

  String _display(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd-MM-yyyy').format(d);
  }

  String _billNoForRow(Map<String, dynamic> po) {
    final stored = '${po['po_bill_no'] ?? ''}'.trim();
    if (stored.isNotEmpty) return stored;
    final uuid = '${po['uuid'] ?? ''}';
    final year = DateTime.tryParse('${po['po_date']}')?.year ?? DateTime.now().year;
    if (uuid.length >= 6) {
      return 'PO-$year-${uuid.replaceAll('-', '').substring(0, 6).toUpperCase()}';
    }
    return 'PO-$year-${po['po_no'] ?? ''}';
  }

  List<Map<String, dynamic>> get _filteredDirectory {
    final q = directorySearch.text.trim().toLowerCase();
    return directoryRows.where((row) {
      if (q.isNotEmpty) {
        final hay = [
          '${row['po_no']}',
          _billNoForRow(row),
          '${row['party_name']}',
          '${row['remarks']}',
        ].join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Future<int?> _persistOrder() async {
    if (supplierId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a supplier before saving.')));
      }
      return null;
    }
    if (zone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select tax matrix / state zone applicability.')));
      }
      return null;
    }
    _syncDueDateFromDays();
    final uuid = repo.newUuid();
    final billNo = 'PO-${DateTime.now().year}-${uuid.replaceAll('-', '').substring(0, 6).toUpperCase()}';
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
            'taxable': r.taxable,
            'cgst': r.cgst,
            'sgst': r.sgst,
            'igst': r.igst,
            'total': r.total,
          },
        )
        .toList();
    final orderId = await repo.createPurchaseOrder({
      'uuid': uuid,
      'po_bill_no': billNo,
      'po_no': int.tryParse(poNo),
      'po_date': poDate,
      'delivery_due_date': dueDate,
      'supplier_ref_no': supplierRef.text,
      'total_packages': int.tryParse(packages.text) ?? 0,
      'delivery_mode': deliveryMode.text,
      'remarks': remarks.text,
      'supplier_id': supplierId,
      'state_zone': zone,
      'due_days': int.tryParse(dueDays.text) ?? 0,
      'estimated_freight': freightVal,
      'taxable_total': taxable,
      'cgst_total': cgst,
      'sgst_total': sgst,
      'igst_total': igst,
      'grand_total': total,
      'status': 'PENDING',
      'items': items,
    });
    return orderId;
  }

  void _resetForm() {
    setState(() {
      rows
        ..clear()
        ..add(_PoRow());
      supplierRef.clear();
      packages.clear();
      deliveryMode.clear();
      remarks.clear();
      dueDays.text = '0';
      freight.text = '0';
      zone = '';
    });
  }

  Future<void> saveAndPrint() async {
    final orderId = await _persistOrder();
    if (orderId == null) return;
    await reprintPurchaseOrder(orderId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PURCHASE ORDER SAVED — PRINT DIALOG OPENED')));
    }
    await load();
    _resetForm();
  }

  @override
  Widget build(BuildContext context) {
    if (showDirectory) return _buildDirectoryView();
    return _buildEntryView();
  }

  Widget _buildDirectoryView() {
    final list = _filteredDirectory;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => showDirectory = false),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to PO entry',
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PURCHASE ORDERS LOGS DIRECTORY',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy, letterSpacing: .3)),
                    const SizedBox(height: 4),
                    Text('REAL-TIME PROCUREMENT ORDER REGISTER & SUPPLIER COMMITMENT TRACKER',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF748094), letterSpacing: .25)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: directorySearch,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'SEARCH LOGS BY SERIAL PO NO, SUPPLIER OR MATERIAL PARTICULARS...',
              hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF9AA5B4)),
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: border)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('FILTER BY PARTY: $directoryPartyFilter',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF748094))),
              const Spacer(),
              _directoryToggle('ALL', directoryPartyFilter == 'ALL', () => setState(() => directoryPartyFilter = 'ALL')),
              const SizedBox(width: 8),
              _directoryToggle('SUPPLIERS', directoryPartyFilter == 'SUPPLIERS', () => setState(() => directoryPartyFilter = 'SUPPLIERS')),
            ],
          ),
          const SizedBox(height: 18),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No purchase orders logged yet.', style: TextStyle(color: Color(0xFF748094)))),
            )
          else
            ...list.map(_directoryCard),
        ],
      ),
    );
  }

  Widget _directoryToggle(String label, bool active, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? navy : Colors.white,
        foregroundColor: active ? Colors.white : navy,
        side: BorderSide(color: active ? navy : border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  Widget _directoryCard(Map<String, dynamic> row) {
    final id = row['id'] as int;
    final status = '${row['status'] ?? 'PENDING'}';
    final qty = (row['total_qty'] as num?)?.toDouble() ?? 0;
    final amount = (row['grand_total'] as num?)?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, decoration: BoxDecoration(color: const Color(0xFFE67E22), borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('${row['party_name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: navy)),
                              const SizedBox(width: 8),
                              _badge(status, const Color(0xFFF4D53A), Colors.black87),
                              const SizedBox(width: 6),
                              _badge('SUPPLIER', const Color(0xFFFFE4EC), red),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'SERIAL NO: ${row['po_no']}  ·  BILL NO: ${_billNoForRow(row)}  ·  BILL DATA DATE: ${row['po_date']}',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFFE67E22)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹ ${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: navy)),
                        Text('${qty.toStringAsFixed(0)} PCS ORDERED', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF748094))),
                      ],
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: ['PENDING', 'RECEIVED', 'CANCELLED'].contains(status) ? status : 'PENDING',
                      items: const [
                        DropdownMenuItem(value: 'PENDING', child: Text('PENDING')),
                        DropdownMenuItem(value: 'RECEIVED', child: Text('RECEIVED')),
                        DropdownMenuItem(value: 'CANCELLED', child: Text('CANCELLED')),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        await repo.updatePurchaseOrderStatus(id, v);
                        directoryRows = await repo.purchaseOrdersWithParty();
                        if (mounted) setState(() {});
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => reprintPurchaseOrder(id),
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('REPRINT PO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: fg)),
    );
  }

  Widget _buildEntryView() {
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF19232C),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PURCHASE ORDER PLACEMENT ENGINE',
                          style: TextStyle(color: Color(0xFF2FE6E0), fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: .4)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 22,
                        runSpacing: 6,
                        children: [
                          _statMini('TOTAL QTY', totalQty.toStringAsFixed(0)),
                          _statMini('TAXABLE VAL', taxable.toStringAsFixed(2)),
                          _statMini('GST TOTAL', gstTotal.toStringAsFixed(2)),
                        ],
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () async {
                    directoryRows = await repo.purchaseOrdersWithParty();
                    setState(() => showDirectory = true);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  child: const Text('VIEW PO DIRECTORY HISTORY', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹ ${total.toStringAsFixed(2)}',
                        style: const TextStyle(color: Color(0xFFF4D53A), fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    const Text('ESTIMATED PROCUREMENT COST',
                        style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: .4)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < formTwoColumnMinWidth;
                    final section1 = _plainSection(
                      title: 'SECTION 1: ORDER METADATA',
                      children: [
                        _pair(
                          _outline('PO NUMERIC SERIAL NO (AUTO)', controller: TextEditingController(text: poNo), readOnly: true, filled: true),
                          _outline('ORDER PLACEMENT DATE', controller: TextEditingController(text: _display(poDate)), readOnly: true,
                              prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
                              onTap: () => _pickDate(poDate, (v) => setState(() => poDate = v))),
                        ),
                        _zoneField(),
                        _pair(
                          _outline('DELIVERY TIMELINE VALIDITY (DAYS)', controller: dueDays,
                              onChanged: (_) {
                                _syncDueDateFromDays();
                                setState(() {});
                              }),
                          _outline('EXPECTED LOGISTICS PACKAGES', controller: packages),
                        ),
                        _outline('RECOMMENDED TRANSPORT ROUTING / VEHICLE SPEED TRANSIT MODE', controller: deliveryMode),
                        _outline('SUPPLIER REFERENCE / REMARKS', controller: supplierRef),
                      ],
                    );
                    final section2 = _plainSection(
                      title: 'SECTION 2: PARTY ALLOCATION — SUPPLIER',
                      children: [
                        enterpriseInsetDropdown<int>(
                          label: 'TARGET REGISTERED SUPPLIER PROFILES *',
                          value: supplierId,
                          items: suppliers
                              .map((s) => DropdownMenuItem<int>(value: s['id'] as int, child: Text('${s['supplier_name']}')))
                              .toList(),
                          onChanged: (v) {
                            final s = suppliers.firstWhere((x) => x['id'] == v);
                            setState(() {
                              supplierId = v;
                              fillSupplier(s);
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _outline('OFFICIAL BILLING HEADQUARTERS ADDRESS', controller: supplierAddress, readOnly: true, filled: true),
                        const SizedBox(height: 12),
                        _pair(
                          _outline('CITY', controller: city, readOnly: true, filled: true),
                          _outline('PINCODE', controller: pin, readOnly: true, filled: true),
                        ),
                        _pair(
                          _outline('REGISTERED GSTIN REFERENCE', controller: gstin, readOnly: true, filled: true),
                          _outline('BANK IDENTIFIER NAME', controller: bank, readOnly: true, filled: true),
                        ),
                        _outline('BANK ACCOUNT NO', controller: account, readOnly: true, filled: true),
                      ],
                    );
                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [section1, const SizedBox(height: 16), section2],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: section1),
                        const SizedBox(width: 16),
                        Expanded(child: section2),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                const Text('SECTION 3: MATERIAL SPECIFICATION MATRIX ENTRY GRID',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: navy, letterSpacing: .3)),
                const SizedBox(height: 4),
                Container(height: 1, color: border),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  width: double.infinity,
                  child: enterpriseMatrixScroller(table: _productMatrixTable()),
                ),
                const SizedBox(height: 12),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => rows.add(_PoRow())),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+ ADD NEW MATRIX MATERIAL ROW', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: navy,
                      side: const BorderSide(color: border),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: remarks,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 11.5, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter PO delivery clauses, specifications or logistics handling notes...',
                          hintStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                          filled: true,
                          fillColor: const Color(0xFF19232C),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 120,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF19232C),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ESTIMATED FREIGHT',
                              style: TextStyle(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.w700)),
                          TextField(
                            controller: freight,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(color: Color(0xFFF4D53A), fontWeight: FontWeight.w900, fontSize: 16),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: saveAndPrint,
                    icon: const Icon(Icons.print_outlined, size: 17),
                    label: const Text('GENERATE & COMMIT PURCHASE ORDER VOUCHER',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _outline(String label,
      {TextEditingController? controller,
      bool readOnly = false,
      bool filled = false,
      Widget? prefixIcon,
      VoidCallback? onTap,
      ValueChanged<String>? onChanged}) {
    return enterpriseInsetTextField(
      label: label,
      controller: controller,
      readOnly: readOnly,
      filled: filled,
      prefixIcon: prefixIcon,
      onTap: onTap,
    );
  }

  Widget _zoneField() {
    final mandatory = zone.isEmpty;
    return enterpriseInsetDropdown<String>(
      label: 'TAX MATRIX PREFERENCE APPLICABILITY *',
      value: zone.isEmpty ? null : zone,
      borderColor: mandatory ? red : null,
      hint: const Text('Choose Option (Mandatory Entry Row)', style: TextStyle(color: red, fontSize: 12.5, fontWeight: FontWeight.w600)),
      items: const [
        DropdownMenuItem(value: 'Intra State', child: Text('Intra State')),
        DropdownMenuItem(value: 'Inter State', child: Text('Inter State')),
      ],
      onChanged: (v) => setState(() => zone = v ?? ''),
    );
  }

  Widget _statMini(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      );

  Widget _pair(Widget a, Widget b) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 14),
            Expanded(child: b),
          ],
        ),
      );

  Widget _plainSection({required String title, required List<Widget> children}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: navy, letterSpacing: .3)),
          const SizedBox(height: 4),
          Container(height: 1, color: border),
          const SizedBox(height: 12),
          ...children,
        ],
      );

  static const _matrixHeadStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 7.5, height: 1.15);
  static const _matrixCellStyle = TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: navy);
  static final _matrixInputDecoration = InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(3)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: const BorderSide(color: border)),
  );

  Widget _matrixHeadCell(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
      child: Text(label, style: _matrixHeadStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _productMatrixTable() {
    return Table(
      columnWidths: enterpriseProductMatrixColumns,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(color: navy2),
          children: [
            _matrixHeadCell('SL'),
            _matrixHeadCell('MATERIAL PROCUREMENT DESCRIPTION'),
            _matrixHeadCell('UOM'),
            _matrixHeadCell('HSN'),
            _matrixHeadCell('REQ QTY'),
            _matrixHeadCell('AGREED RATE'),
            _matrixHeadCell('CGST%'),
            _matrixHeadCell('SGST%'),
            _matrixHeadCell('IGST%'),
            _matrixHeadCell('COMPOUND ROW VALUE'),
            const SizedBox.shrink(),
          ],
        ),
        ...List.generate(rows.length, (i) {
          return TableRow(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border.withOpacity(.6)))),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                child: Text('${i + 1}', style: _matrixCellStyle),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: DropdownButton<int>(
                  isExpanded: true,
                  isDense: true,
                  hint: const Text('Enter Description', style: TextStyle(fontSize: 9, color: Color(0xFF9AA5B4))),
                  value: rows[i].productId,
                  items: products
                      .map((p) => DropdownMenuItem<int>(
                            value: p['id'] as int,
                            child: Text('${p['product_name']}', style: const TextStyle(fontSize: 9), overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) {
                    final p = products.firstWhere((x) => x['id'] == v);
                    setState(() => rows[i].setProduct(p));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: DropdownButton<int>(
                  isExpanded: true,
                  isDense: true,
                  underline: const SizedBox(),
                  value: rows[i].unitId,
                  hint: const Text('UOM', style: TextStyle(fontSize: 9)),
                  items: units
                      .map((u) => DropdownMenuItem<int>(
                            value: u['id'] as int,
                            child: Text('${u['code']}', style: const TextStyle(fontSize: 9)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    final u = units.firstWhere((x) => x['id'] == v);
                    setState(() {
                      rows[i].unitId = v;
                      rows[i].uom = '${u['code']}';
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Text(rows[i].hsn, style: _matrixCellStyle, overflow: TextOverflow.ellipsis),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: TextField(
                  key: ValueKey('q$i'),
                  keyboardType: TextInputType.number,
                  style: _matrixCellStyle,
                  decoration: _matrixInputDecoration,
                  onChanged: (v) => setState(() => rows[i].qty = double.tryParse(v) ?? 0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: TextField(
                  key: ValueKey('r$i'),
                  keyboardType: TextInputType.number,
                  style: _matrixCellStyle,
                  decoration: _matrixInputDecoration,
                  onChanged: (v) => setState(() => rows[i].rate = double.tryParse(v) ?? 0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: TextField(
                  controller: TextEditingController(text: '${rows[i].cgstPct}'),
                  keyboardType: TextInputType.number,
                  style: _matrixCellStyle,
                  decoration: _matrixInputDecoration,
                  onChanged: (v) => setState(() => rows[i].cgstPct = double.tryParse(v) ?? 0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: TextField(
                  controller: TextEditingController(text: '${rows[i].sgstPct}'),
                  keyboardType: TextInputType.number,
                  style: _matrixCellStyle,
                  decoration: _matrixInputDecoration,
                  onChanged: (v) => setState(() => rows[i].sgstPct = double.tryParse(v) ?? 0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: TextField(
                  controller: TextEditingController(text: '${rows[i].igstPct}'),
                  keyboardType: TextInputType.number,
                  style: _matrixCellStyle,
                  decoration: _matrixInputDecoration,
                  onChanged: (v) => setState(() => rows[i].igstPct = double.tryParse(v) ?? 0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                child: Text(rows[i].total.toStringAsFixed(2), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                child: IconButton(
                  onPressed: rows.length == 1 ? null : () => setState(() => rows.removeAt(i)),
                  icon: const Icon(Icons.delete_outline, color: red, size: 17),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _PoRow {
  int? productId;
  int? unitId;
  String description = 'Item Description';
  String uom = 'PCS';
  String hsn = '123456';
  double qty = 0;
  double rate = 0;
  double cgstPct = 9;
  double sgstPct = 9;
  double igstPct = 18;

  void setProduct(Map<String, dynamic> p) {
    productId = p['id'] as int?;
    description = p['product_name'] ?? '';
    unitId = p['unit_id'] as int?;
    uom = p['uom_code'] ?? 'PCS';
    hsn = p['hsn'] ?? '';
    rate = (p['rate'] ?? 0).toDouble();
  }

  double get taxable => qty * rate;
  double get cgst => taxable * cgstPct / 100;
  double get sgst => taxable * sgstPct / 100;
  double get igst => taxable * igstPct / 100;
  double get total => taxable + cgst + sgst + igst;
}

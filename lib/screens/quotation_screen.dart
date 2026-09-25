import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ultra_repository.dart';
import '../widgets/compact_date_picker.dart';
import '../widgets/enterprise_widgets.dart';
import '../widgets/quotation_document.dart';

class QuotationScreen extends StatefulWidget {
  const QuotationScreen({super.key});
  @override
  State<QuotationScreen> createState() => _QuotationScreenState();
}

class _QuotationScreenState extends State<QuotationScreen> {
  final repo = UltraRepository.instance;
  bool showHistory = false;
  bool partyIsSupplier = false;
  String partyFilter = 'ALL';
  final search = TextEditingController();

  String serial = '';
  String qtDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final validity = TextEditingController(text: '0');
  final refNo = TextEditingController();
  final refName = TextEditingController();
  String refDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final address = TextEditingController();
  final city = TextEditingController();
  final pin = TextEditingController();
  final gstin = TextEditingController();
  final salutation = TextEditingController(text: 'Dear Sir,');
  final subject = TextEditingController();
  final body = TextEditingController();
  final freight = TextEditingController(text: '0');

  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> units = [];
  List<Map<String, dynamic>> historyRows = [];
  int? partyId;
  final rows = [_QtRow()];
  final terms = <_TermRow>[];

  @override
  void initState() {
    super.initState();
    _seedTerms();
    load();
  }

  void _seedTerms() {
    terms
      ..clear()
      ..addAll([
        _TermRow('Delivery Period: Within 3 working days from PO confirmation.'),
        _TermRow('50% Advance Payment along with PO confirmation.'),
        _TermRow('50% Balance Payment upon delivery of materials.'),
        _TermRow('Quotation Validity: 15 days from date of issue.'),
        _TermRow('GST: GST will be charged extra as applicable.'),
      ]);
  }

  Future<void> load() async {
    customers = await repo.customers();
    suppliers = await repo.suppliers();
    units = await repo.units();
    serial = '${await repo.nextQuotationSerial()}';
    historyRows = await repo.quotationsWithParty();
    if (!partyIsSupplier && customers.isNotEmpty) {
      partyId = customers.first['id'] as int;
      _fillParty(customers.first);
    } else if (partyIsSupplier && suppliers.isNotEmpty) {
      partyId = suppliers.first['id'] as int;
      _fillParty(suppliers.first);
    }
    if (mounted) setState(() {});
  }

  void _fillParty(Map<String, dynamic> p) {
    address.text = p['address'] ?? '';
    city.text = p['city'] ?? '';
    pin.text = p['postal_pincode'] ?? '';
    gstin.text = p['gstin'] ?? '';
  }

  double get netTotal => rows.fold<double>(0, (s, r) => s + r.lineTotal) + (double.tryParse(freight.text) ?? 0);
  double get totalQty => rows.fold<double>(0, (s, r) => s + r.qty);

  @override
  void dispose() {
    for (final c in [validity, refNo, refName, address, city, pin, gstin, salutation, subject, body, freight, search]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(String iso, ValueChanged<String> on) async {
    final picked = await pickCompactDate(context, initialDate: DateTime.tryParse(iso) ?? DateTime.now());
    if (picked != null) on(formatIsoDate(picked));
  }

  String _display(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd-MM-yyyy').format(d);
  }

  String _refForRow(Map<String, dynamic> q) {
    final stored = '${q['ref_no'] ?? ''}'.trim();
    if (stored.isNotEmpty) return stored;
    final uuid = '${q['uuid'] ?? ''}';
    final year = DateTime.tryParse('${q['quotation_date']}')?.year ?? DateTime.now().year;
    if (uuid.length >= 6) return 'QT-$year-${uuid.replaceAll('-', '').substring(0, 6).toUpperCase()}';
    return 'QT-$year-${q['serial_no']}';
  }

  Future<void> _saveAndPrint() async {
    if (partyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a supplier or customer profile.')));
      return;
    }
    final uuid = repo.newUuid();
    final billRef = 'QT-${DateTime.now().year}-${uuid.replaceAll('-', '').substring(0, 6).toUpperCase()}';
    final items = rows
        .map(
          (r) => {
            'description': r.description,
            'uom': r.uom,
            'quantity': r.qty,
            'rate': r.rate,
            'line_total': r.lineTotal,
          },
        )
        .toList();
    final termRows = <Map<String, dynamic>>[];
    for (var i = 0; i < terms.length; i++) {
      final line = terms[i].controller.text.trim();
      if (line.isEmpty) continue;
      termRows.add({'sort_order': i + 1, 'text': line});
    }
    final id = await repo.createQuotation({
      'uuid': uuid,
      'ref_no': billRef,
      'serial_no': int.tryParse(serial),
      'quotation_date': qtDate,
      'validity_days': int.tryParse(validity.text) ?? 0,
      'reference_name': refName.text,
      'reference_date': refDate,
      'party_kind': partyIsSupplier ? 'SUPPLIER' : 'CUSTOMER',
      'party_id': partyId,
      'address': address.text,
      'city': city.text,
      'pincode': pin.text,
      'gstin': gstin.text,
      'salutation': salutation.text,
      'subject': subject.text,
      'body_text': body.text,
      'freight': double.tryParse(freight.text) ?? 0,
      'net_total': netTotal,
      'total_qty': totalQty,
      'status': 'PENDING',
      'created_at': DateTime.now().toIso8601String(),
      'items': items,
      'terms': termRows,
    });
    await reprintQuotation(id);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QUOTATION SAVED — PRINT OPENED')));
    await load();
    setState(() {
      rows..clear()..add(_QtRow());
      _seedTerms();
      refNo.clear();
      refName.clear();
      subject.clear();
      body.clear();
    });
  }

  List<Map<String, dynamic>> get _filteredHistory {
    return historyRows.where((r) {
      final kind = '${r['party_kind']}';
      if (partyFilter == 'SUPPLIERS' && kind != 'SUPPLIER') return false;
      if (partyFilter == 'CUSTOMERS' && kind != 'CUSTOMER') return false;
      final q = search.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      return '${r['party_name']} ${_refForRow(r)}'.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (showHistory) return _history();
    return _entry();
  }

  Widget _history() {
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
                    Text('QUOTATION LOGS DIRECTORY', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
                    Text('COMMERCIAL QUOTATIONS TRACK REVERSALS AUDIT TRAIL REPOSITORY',
                        style: TextStyle(fontSize: 10, color: Color(0xFF748094), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'SEARCH LOGS BY SERIAL QT NO, CLIENT OR PRODUCT PARTICULARS...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('FILTER BY PARTY: $partyFilter', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF748094))),
              const Spacer(),
              _filterBtn('ALL'),
              const SizedBox(width: 6),
              _filterBtn('SUPPLIERS'),
              const SizedBox(width: 6),
              _filterBtn('CUSTOMERS'),
            ],
          ),
          const SizedBox(height: 16),
          ...list.map(_historyCard),
        ],
      ),
    );
  }

  Widget _filterBtn(String label) {
    final active = partyFilter == label;
    return OutlinedButton(
      onPressed: () => setState(() => partyFilter = label),
      style: OutlinedButton.styleFrom(backgroundColor: active ? navy : Colors.white, foregroundColor: active ? Colors.white : navy),
      child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }

  Widget _historyCard(Map<String, dynamic> r) {
    final id = r['id'] as int;
    final amt = (r['net_total'] as num?)?.toDouble() ?? 0;
    final qty = (r['total_qty'] as num?)?.toDouble() ?? 0;
    final status = '${r['status'] ?? 'PENDING'}';
    final kind = '${r['party_kind']}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: border), borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Container(width: 5, color: const Color(0xFFE67E22)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('${r['party_name']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                            const SizedBox(width: 6),
                            _badge(status, const Color(0xFFF4D53A)),
                            const SizedBox(width: 4),
                            _badge(kind, kind == 'SUPPLIER' ? const Color(0xFFFFE4EC) : const Color(0xFFE3F2FD)),
                          ],
                        ),
                        Text('SERIAL NO: ${r['serial_no']}  ·  REF NO: ${_refForRow(r)}  ·  QUOTATION DATE: ${r['quotation_date']}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF748094))),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹ ${amt.toStringAsFixed(2)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      Text('${qty.toStringAsFixed(0)} PCS QUOTED', style: const TextStyle(fontSize: 9, color: Color(0xFF748094))),
                    ],
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: ['PENDING', 'APPROVED', 'REJECTED'].contains(status) ? status : 'PENDING',
                    items: const [
                      DropdownMenuItem(value: 'PENDING', child: Text('PENDING')),
                      DropdownMenuItem(value: 'APPROVED', child: Text('APPROVED')),
                      DropdownMenuItem(value: 'REJECTED', child: Text('REJECTED')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      await repo.updateQuotationStatus(id, v);
                      historyRows = await repo.quotationsWithParty();
                      setState(() {});
                    },
                  ),
                  OutlinedButton.icon(onPressed: () => reprintQuotation(id), icon: const Icon(Icons.print_outlined, size: 16), label: const Text('REPRINT QT')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String t, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        color: bg,
        child: Text(t, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800)),
      );

  Widget _entry() {
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
                      const Text('QUOTATION PLACEMENT ENGINE', style: TextStyle(color: teal, fontSize: 15, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 18,
                        children: [
                          _mini('TOTAL QTY', totalQty.toStringAsFixed(0)),
                          _mini('NET TOTAL', netTotal.toStringAsFixed(2)),
                        ],
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    historyRows = await repo.quotationsWithParty();
                    setState(() => showHistory = true);
                  },
                  icon: const Icon(Icons.list_alt, size: 16),
                  label: const Text('VIEW QUOTATION HISTORY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24)),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹ ${netTotal.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFF4D53A), fontSize: 20, fontWeight: FontWeight.w900)),
                    const Text('ESTIMATED OFFER VALUE', style: TextStyle(color: Colors.white54, fontSize: 8.5)),
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
                _sec('SECTION 1: QUOTATION METADATA & REFERENCES', [
                  _pair(_ro('QUOTATION SERIAL NO (AUTO)', serial), _date('QUOTATION DATE', qtDate, (v) => qtDate = v)),
                  _pair(_field('VALIDITY (DAYS)', validity), _field('REFERENCE NO', refNo)),
                  _pair(_field('REFERENCE NAME / KIND...', refName), _date('REFERENCE DATE', refDate, (v) => refDate = v)),
                ]),
                const SizedBox(height: 14),
                _sec('SECTION 2: PARTY ALLOCATION', [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _partyToggle('SUPPLIER', true),
                      const SizedBox(width: 8),
                      _partyToggle('CUSTOMER', false),
                    ],
                  ),
                  Text('PARTY TYPE: ${partyIsSupplier ? 'SUPPLIER' : 'CUSTOMER'}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF748094))),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: partyId,
                    isExpanded: true,
                    decoration: _dec(partyIsSupplier ? 'TARGET REGISTERED SUPPLIER PROFILES *' : 'TARGET REGISTERED CUSTOMER PROFILES *'),
                    items: (partyIsSupplier ? suppliers : customers)
                        .map((p) => DropdownMenuItem<int>(
                              value: p['id'] as int,
                              child: Text('${partyIsSupplier ? p['supplier_name'] : p['customer_name']}', style: const TextStyle(fontSize: 12)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      final list = partyIsSupplier ? suppliers : customers;
                      final p = list.firstWhere((x) => x['id'] == v);
                      setState(() {
                        partyId = v;
                        _fillParty(p);
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _field('OFFICIAL BILLING ADDRESS', address),
                  _pair(_field('CITY', city), _field('PINCODE', pin)),
                  _field('REGISTERED GSTIN REFERENCE', gstin),
                ]),
                const SizedBox(height: 14),
                _sec('SECTION 3: COVER LETTER / APPLICATION WRITING', [
                  _field('SALUTATION', salutation),
                  _field('QUOTATION SUBJECT', subject),
                  _field('APPLICATION BODY / INTRODUCTORY NOTE', body, maxLines: 4),
                ]),
                const SizedBox(height: 14),
                _sec('SECTION 4: SPECIFICATION MATRIX & PRICING GRID', [
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: border), color: Colors.white),
                    child: Table(
                      columnWidths: const {
                        0: FixedColumnWidth(24),
                        1: FlexColumnWidth(2.5),
                        2: FixedColumnWidth(50),
                        3: FixedColumnWidth(50),
                        4: FixedColumnWidth(55),
                        5: FixedColumnWidth(60),
                        6: FixedColumnWidth(28),
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: navy2),
                          children: ['SL', 'ITEM SPECIFICATION PARTICULARS', 'UOM', 'OFFER QTY', 'QUOTED RATE', 'NET ROW VALUE', '']
                              .map((h) => Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Text(h, style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w800)),
                                  ))
                              .toList(),
                        ),
                        ...List.generate(rows.length, (i) {
                          final r = rows[i];
                          return TableRow(
                            children: [
                              Text('${i + 1}', style: const TextStyle(fontSize: 9)),
                              Padding(
                                padding: const EdgeInsets.all(3),
                                child: TextField(
                                  decoration: const InputDecoration(isDense: true, hintText: 'Enter Particulars'),
                                  style: const TextStyle(fontSize: 9),
                                  onChanged: (v) => r.description = v,
                                ),
                              ),
                              DropdownButton<int>(
                                isExpanded: true,
                                isDense: true,
                                value: r.unitId,
                                hint: const Text('UOM', style: TextStyle(fontSize: 9)),
                                items: units.map((u) => DropdownMenuItem(value: u['id'] as int, child: Text('${u['code']}', style: const TextStyle(fontSize: 9)))).toList(),
                                onChanged: (v) {
                                  final u = units.firstWhere((x) => x['id'] == v);
                                  setState(() {
                                    r.unitId = v;
                                    r.uom = '${u['code']}';
                                  });
                                },
                              ),
                              _qtNum((v) => r.qty = v),
                              _qtNum((v) => r.rate = v),
                              Text(r.lineTotal.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                              IconButton(
                                onPressed: rows.length == 1 ? null : () => setState(() => rows.removeAt(i)),
                                icon: const Icon(Icons.delete_outline, color: red, size: 17),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => rows.add(_QtRow())),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+ ADD NEW QUOTATION ITEM ROW', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('SECTION 5: CUSTOM TERMS & CONDITIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: navy)),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => terms.add(_TermRow(''))),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('+ ADD POINT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const Divider(),
                ...List.generate(terms.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: terms[i].controller,
                            onChanged: (v) => terms[i].text = v,
                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => terms.removeAt(i)),
                          icon: const Icon(Icons.remove_circle_outline, color: red, size: 20),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        color: const Color(0xFF19232C),
                        child: Text('NET TOTAL IN WORDS: ${_words(netTotal)}', style: const TextStyle(color: teal, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 120,
                      padding: const EdgeInsets.all(10),
                      color: const Color(0xFF19232C),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('FREIGHT CHARGES', style: TextStyle(color: Colors.white54, fontSize: 8)),
                          TextField(
                            controller: freight,
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
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('GENERATE & COMMIT QUOTATION VOUCHER', style: TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A5FB4), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _partyToggle(String label, bool supplier) {
    final active = partyIsSupplier == supplier;
    return OutlinedButton(
      onPressed: () {
        setState(() {
          partyIsSupplier = supplier;
          partyId = null;
          final list = supplier ? suppliers : customers;
          if (list.isNotEmpty) {
            partyId = list.first['id'] as int;
            _fillParty(list.first);
          }
        });
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? (supplier ? const Color(0xFFE67E22) : const Color(0xFF1A5FB4)) : Colors.white,
        foregroundColor: active ? Colors.white : navy,
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  Widget _qtNum(ValueChanged<double> on) => Padding(
        padding: const EdgeInsets.all(3),
        child: TextField(
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 9),
          decoration: const InputDecoration(isDense: true),
          onChanged: (v) => setState(() => on(double.tryParse(v) ?? 0)),
        ),
      );

  Widget _mini(String l, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l, style: const TextStyle(color: Colors.white54, fontSize: 8)),
          Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ],
      );

  Widget _sec(String title, List<Widget> children) => Column(
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
          decoration: _dec(label).copyWith(filled: true, fillColor: const Color(0xFFF1F3F7)),
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

class _QtRow {
  int? unitId;
  String description = '';
  String uom = 'PCS';
  double qty = 0;
  double rate = 0;
  double get lineTotal => qty * rate;
}

class _TermRow {
  String text;
  late final TextEditingController controller;
  _TermRow(this.text) {
    controller = TextEditingController(text: text);
  }
}

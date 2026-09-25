import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ultra_repository.dart';
import '../widgets/compact_date_picker.dart';
import '../widgets/enterprise_widgets.dart';

final transactionsHostKey = GlobalKey<TransactionsHostScreenState>();

enum TxView { adjustment, cashBook, journal }

abstract class TransactionsHostScreenState extends State<TransactionsHostScreen> {
  void showAdjustment();
  void showCashBook();
  void showJournal();
}

class TransactionsHostScreen extends StatefulWidget {
  const TransactionsHostScreen({super.key});
  @override
  TransactionsHostScreenState createState() => _TransactionsHostScreenState();
}

class _TransactionsHostScreenState extends TransactionsHostScreenState {
  final repo = UltraRepository.instance;
  TxView view = TxView.adjustment;

  @override
  void showAdjustment() => setState(() => view = TxView.adjustment);
  @override
  void showCashBook() => setState(() => view = TxView.cashBook);
  @override
  void showJournal() => setState(() => view = TxView.journal);

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: switch (view) {
        TxView.adjustment => const _AdjustmentReturnPanel(),
        TxView.cashBook => const _CashBookPanel(),
        TxView.journal => const _JournalEntryPanel(),
      },
    );
  }
}

// ─── Adjustment & Return (Debit / Credit Note) ─────────────────────────────

class _AdjustmentReturnPanel extends StatefulWidget {
  const _AdjustmentReturnPanel();
  @override
  State<_AdjustmentReturnPanel> createState() => _AdjustmentReturnPanelState();
}

class _AdjustmentReturnPanelState extends State<_AdjustmentReturnPanel> {
  final repo = UltraRepository.instance;
  bool isDebit = true;
  String noteNo = '1';
  String issueDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String origInvDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final origInvRef = TextEditingController();
  final eway = TextEditingController();
  final logistics = TextEditingController();
  final narration = TextEditingController();
  final address = TextEditingController();
  final city = TextEditingController();
  final pin = TextEditingController();
  final gstin = TextEditingController();
  String reason = 'DAMAGED GOODS';
  int? partyId;
  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> units = [];
  final rows = [_AdjRow()];

  static const _reasons = ['DAMAGED GOODS', 'PRICE DIFFERENCE', 'SHORT SUPPLY', 'EXCESS SUPPLY', 'OTHER'];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    suppliers = await repo.suppliers();
    customers = await repo.customers();
    products = await repo.products();
    units = await repo.units();
    noteNo = '${await repo.nextAdjustmentNoteNo(isDebit ? 'DEBIT' : 'CREDIT')}';
    if (isDebit && suppliers.isNotEmpty) {
      partyId = suppliers.first['id'] as int;
      _fillParty(suppliers.first);
    } else if (!isDebit && customers.isNotEmpty) {
      partyId = customers.first['id'] as int;
      _fillParty(customers.first);
    }
    if (mounted) setState(() {});
  }

  void _fillParty(Map<String, dynamic> p) {
    address.text = p['address'] ?? '';
    city.text = p['city'] ?? '';
    pin.text = p['postal_pincode'] ?? '';
    gstin.text = p['gstin'] ?? '';
  }

  double get taxable => rows.fold(0, (s, r) => s + r.extended);
  double get taxTotal => rows.fold(0, (s, r) => s + r.taxAmt);
  double get grandTotal => taxable + taxTotal;

  Future<void> _toggleDebit(bool debit) async {
    isDebit = debit;
    partyId = null;
    await load();
  }

  Future<void> _save() async {
    if (partyId == null) return;
    final uuid = repo.newUuid();
    final year = DateTime.now().year;
    final prefix = isDebit ? 'DN' : 'CN';
    final noteBillNo = '$prefix-$year-${uuid.replaceAll('-', '').substring(0, 6).toUpperCase()}';
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
            'extended_value': r.total,
          },
        )
        .toList();
    await repo.createAdjustmentNote({
      'uuid': uuid,
      'note_bill_no': noteBillNo,
      'note_type': isDebit ? 'DEBIT' : 'CREDIT',
      'note_no': int.tryParse(noteNo),
      'issue_date': issueDate,
      'original_invoice_ref': origInvRef.text,
      'original_invoice_date': origInvDate,
      'reversal_reason': reason,
      'eway_bill': eway.text,
      'logistics': logistics.text,
      'party_kind': isDebit ? 'SUPPLIER' : 'CUSTOMER',
      'party_id': partyId,
      'address': address.text,
      'city': city.text,
      'pincode': pin.text,
      'gstin': gstin.text,
      'narration': narration.text,
      'taxable_total': taxable,
      'tax_total': taxTotal,
      'grand_total': grandTotal,
      'created_at': DateTime.now().toIso8601String(),
      'items': items,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isDebit ? 'DEBIT NOTE POSTED' : 'CREDIT NOTE POSTED'),
      ));
    }
    await load();
    setState(() => rows..clear()..add(_AdjRow()));
  }

  Color get _accent => isDebit ? const Color(0xFFB33A3A) : green;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: _accent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isDebit ? 'DEBIT NOTE REVERSAL ENGINE' : 'CREDIT NOTE REVERSAL ENGINE',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        children: [
                          _stat('PCS ITEM COUNT', rows.length.toString()),
                          _stat('TAXABLE AMT', taxable.toStringAsFixed(2)),
                          _stat('TOTAL TAX', taxTotal.toStringAsFixed(2)),
                        ],
                      ),
                    ],
                  ),
                ),
                _toggleBtn('DEBIT NOTE', true),
                const SizedBox(width: 6),
                _toggleBtn('CREDIT NOTE', false),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹ ${grandTotal.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFF4D53A), fontSize: 20, fontWeight: FontWeight.w900)),
                    const Text('NET ACCOUNT REVERSAL VALUE', style: TextStyle(color: Colors.white70, fontSize: 8)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final stacked = c.maxWidth < 960;
                    final s1 = _sec('SECTION 1: DISPATCH / SOURCE METADATA', [
                      _pair(_ro('NOTE NUMERIC NO *', noteNo), _dateFld('NOTE ISSUE DATE', issueDate, (v) => issueDate = v)),
                      _pair(_fld('ORIGINAL INVOICE REF NO', origInvRef), _dateFld('ORIGINAL INVOICE DATE', origInvDate, (v) => origInvDate = v)),
                      DropdownButtonFormField<String>(
                        value: reason,
                        decoration: _dec('REASON FOR TRANSACTION REVERSAL'),
                        items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (v) => setState(() => reason = v ?? reason),
                      ),
                      const SizedBox(height: 10),
                      _fld('E-WAY BILL NO', eway),
                      _fld('LOGISTICS DISPATCH VEHICLE DETAILS / MODE', logistics),
                    ]);
                    final s2 = _sec('SECTION 2: ALLOCATED PARTY DIRECTORY', [
                      DropdownButtonFormField<int>(
                        value: partyId,
                        isExpanded: true,
                        decoration: _dec(isDebit ? 'SELECT SUPPLIER ACCOUNT DIRECTORY *' : 'SELECT CUSTOMER ACCOUNT DIRECTORY *'),
                        items: (isDebit ? suppliers : customers)
                            .map((p) => DropdownMenuItem<int>(
                                  value: p['id'] as int,
                                  child: Text('${isDebit ? p['supplier_name'] : p['customer_name']}'),
                                ))
                            .toList(),
                        onChanged: (v) {
                          final list = isDebit ? suppliers : customers;
                          final p = list.firstWhere((x) => x['id'] == v);
                          setState(() {
                            partyId = v;
                            _fillParty(p);
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _fld('REGISTERED OFFICE BILLING ADDRESS', address),
                      _pair(_fld('CITY LOCATION', city), _fld('PINCODE', pin)),
                      _fld('PARTY IDENTIFICATION (GSTIN) NUMBER', gstin),
                    ]);
                    if (stacked) return Column(children: [s1, const SizedBox(height: 14), s2]);
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: s1), const SizedBox(width: 14), Expanded(child: s2)]);
                  },
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('SECTION 3: REVERSAL TRANSACTIONAL ACCOUNT MATRIX',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: navy)),
                ),
                const SizedBox(height: 8),
                _matrix(),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => setState(() => rows.add(_AdjRow())),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('+ ADD REVERSAL MATERIAL ITEM ROW', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: narration,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  decoration: InputDecoration(
                    hintText: 'NARRATION / ACCOUNT COMMENTS',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF19232C),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('WORDS: ${grandTotal == 0 ? 'ZERO RUPEES ONLY' : '₹${grandTotal.toStringAsFixed(2)} ONLY'}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 14),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.verified_user_outlined),
                    label: Text(isDebit ? 'POST & SECURE DEBIT NOTE' : 'POST & SECURE CREDIT NOTE',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool debit) {
    final active = isDebit == debit;
    return OutlinedButton(
      onPressed: () => _toggleDebit(debit),
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? Colors.white : Colors.transparent,
        foregroundColor: active ? _accent : Colors.white,
        side: const BorderSide(color: Colors.white54),
      ),
      child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }

  Widget _matrix() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: border), color: Colors.white),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(22),
          1: FlexColumnWidth(2.2),
          2: FixedColumnWidth(40),
          3: FixedColumnWidth(42),
          4: FixedColumnWidth(36),
          5: FixedColumnWidth(40),
          6: FixedColumnWidth(32),
          7: FixedColumnWidth(32),
          8: FixedColumnWidth(32),
          9: FixedColumnWidth(48),
          10: FixedColumnWidth(26),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: navy2),
            children: ['SL', 'MATERIAL MATRIX PARTICULARS', 'UOM', 'HSN', 'QTY', 'RATE/VAL', 'CGST%', 'SGST%', 'IGST%', 'EXTENDED VAL', '']
                .map((h) => Padding(
                      padding: const EdgeInsets.all(5),
                      child: Text(h, style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w800)),
                    ))
                .toList(),
          ),
          ...List.generate(rows.length, (i) {
            final r = rows[i];
            return TableRow(
              children: [
                Text('${i + 1}', style: const TextStyle(fontSize: 9)),
                DropdownButton<int>(
                  isExpanded: true,
                  isDense: true,
                  hint: const Text('Item Description', style: TextStyle(fontSize: 9)),
                  value: r.productId,
                  items: products.map((p) => DropdownMenuItem(value: p['id'] as int, child: Text('${p['product_name']}', style: const TextStyle(fontSize: 9)))).toList(),
                  onChanged: (v) {
                    final p = products.firstWhere((x) => x['id'] == v);
                    setState(() => r.setProduct(p));
                  },
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
                Text(r.hsn, style: const TextStyle(fontSize: 9)),
                _num((v) => r.qty = v),
                _num((v) => r.rate = v),
                _num((v) => r.cgstPct = v, init: r.cgstPct),
                _num((v) => r.sgstPct = v, init: r.sgstPct),
                _num((v) => r.igstPct = v, init: r.igstPct),
                Text(r.total.toStringAsFixed(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                IconButton(
                  onPressed: rows.length == 1 ? null : () => setState(() => rows.removeAt(i)),
                  icon: const Icon(Icons.delete_outline, color: red, size: 17),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _num(ValueChanged<double> on, {double init = 0}) => Padding(
        padding: const EdgeInsets.all(2),
        child: TextField(
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 9),
          controller: TextEditingController(text: init == 0 ? '' : '$init'),
          decoration: const InputDecoration(isDense: true),
          onChanged: (v) => setState(() => on(double.tryParse(v) ?? 0)),
        ),
      );

  Widget _stat(String l, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l, style: const TextStyle(color: Colors.white70, fontSize: 8)),
          Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
        ],
      );

  Widget _sec(String t, List<Widget> c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: navy)), const Divider(), ...c]);
  Widget _pair(Widget a, Widget b) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]));
  InputDecoration _dec(String l) => InputDecoration(labelText: l, floatingLabelBehavior: FloatingLabelBehavior.always, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)));
  Widget _fld(String l, TextEditingController c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: c, decoration: _dec(l), style: const TextStyle(fontSize: 11.5)));
  Widget _ro(String l, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(readOnly: true, controller: TextEditingController(text: v), decoration: _dec(l).copyWith(filled: true, fillColor: const Color(0xFFF1F3F7))),
      );
  Widget _dateFld(String l, String iso, ValueChanged<String> on) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          readOnly: true,
          controller: TextEditingController(text: DateFormat('dd-MM-yyyy').format(DateTime.tryParse(iso) ?? DateTime.now())),
          decoration: _dec(l).copyWith(prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16)),
          onTap: () async {
            final picked = await pickCompactDate(context, initialDate: DateTime.tryParse(iso) ?? DateTime.now());
            if (picked != null) setState(() => on(formatIsoDate(picked)));
          },
        ),
      );
}

class _AdjRow {
  int? productId;
  int? unitId;
  String description = '';
  String uom = 'PCS';
  String hsn = '';
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
  double get taxAmt => extended * (cgstPct + sgstPct + igstPct) / 100;
  double get total => extended + taxAmt;
}

// ─── Cash Book (Receipt / Payment) ───────────────────────────────────────────

class _CashBookPanel extends StatefulWidget {
  const _CashBookPanel();
  @override
  State<_CashBookPanel> createState() => _CashBookPanelState();
}

class _CashBookPanelState extends State<_CashBookPanel> {
  final repo = UltraRepository.instance;
  bool isReceipt = true;
  String? partyKey;
  final amount = TextEditingController();
  final remarks = TextEditingController();
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> passbook = [];
  String voucherDate = DateFormat('dd MMM yyyy').format(DateTime.now()).toUpperCase();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    customers = await repo.customers();
    suppliers = await repo.suppliers();
    passbook = await repo.cashPassbookEntries();
    if (mounted) setState(() {});
  }

  List<DropdownMenuItem<String>> get _partyItems {
    final items = <DropdownMenuItem<String>>[];
    for (final c in customers) {
      items.add(DropdownMenuItem(
        value: 'CUSTOMER:${c['id']}',
        child: Row(
          children: [
            Expanded(child: Text('${c['customer_name']}', style: const TextStyle(fontSize: 11))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: const Color(0xFFE3F2FD),
              child: const Text('CUST', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF1A5FB4))),
            ),
          ],
        ),
      ));
    }
    for (final s in suppliers) {
      items.add(DropdownMenuItem(
        value: 'SUPPLIER:${s['id']}',
        child: Row(
          children: [
            Expanded(child: Text('${s['supplier_name']}', style: const TextStyle(fontSize: 11))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: const Color(0xFFFFE4CC),
              child: const Text('SUPP', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFFE67E22))),
            ),
          ],
        ),
      ));
    }
    return items;
  }

  Future<void> _save() async {
    final amt = double.tryParse(amount.text) ?? 0;
    if (amt <= 0 || partyKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select party and enter amount.')));
      return;
    }
    final parts = partyKey!.split(':');
    final id = int.parse(parts[1]);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (isReceipt) {
      if (parts[0] != 'CUSTOMER') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipts must be allocated to a customer.')));
        return;
      }
      await repo.insertReceipt({
        'customer_id': id,
        'receipt_date': today,
        'amount': amt,
        'narration': remarks.text,
        'created_at': DateTime.now().toIso8601String(),
      });
    } else {
      if (parts[0] != 'SUPPLIER') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payments must be allocated to a supplier.')));
        return;
      }
      await repo.insertPayment({
        'supplier_id': id,
        'payment_date': today,
        'amount': amt,
        'payment_mode': 'CASH',
        'reference_no': '',
        'narration': remarks.text,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    amount.clear();
    remarks.clear();
    partyKey = null;
    await load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CASHBOOK ENTRY SAVED')));
  }

  @override
  Widget build(BuildContext context) {
    final accent = isReceipt ? green : red;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CASH RECEIPT / CASH PAYMENT REGISTER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: navy)),
          const Text('CASH PASSBOOK (CR/DR) ACCOUNT TRANSACTION DIRECTORY LOGS',
              style: TextStyle(fontSize: 10, color: Color(0xFF748094), fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            children: [
              _modeBtn('RECEIPT', true, green),
              const SizedBox(width: 8),
              _modeBtn('PAYMENT', false, red),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: border), borderRadius: BorderRadius.circular(6)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(isReceipt ? 'NEW RECEIPT RECORD' : 'NEW PAYMENT RECORD',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: navy)),
                            const Icon(Icons.close, size: 18, color: Color(0xFF748094)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.lock_outline, size: 14, color: Color(0xFF748094)),
                            const SizedBox(width: 6),
                            Text('VOUCHER REGISTRATION DATE: $voucherDate', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: partyKey,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: isReceipt ? 'Search Customer...' : 'TARGET ALLOCATED LEDGER NAME *',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          hint: const Text('Search Customer/Supplier...'),
                          items: _partyItems,
                          onChanged: (v) => setState(() => partyKey = v),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: amount,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'TRANSACTION VOUCHER AMOUNT *',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: remarks,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'VOUCHER REMARKS / NARRATION',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                            child: const Text('SAVE ENTRY UNTO CASHBOOKS', style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.history, size: 16, color: Color(0xFF748094)),
                          SizedBox(width: 6),
                          Text('CASH PASSBOOK (CR/DR) ACCOUNT TRANSACTION DIRECTORY LOGS',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF748094))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          itemCount: passbook.length,
                          itemBuilder: (_, i) => _passbookCard(passbook[i]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeBtn(String label, bool receipt, Color color) {
    final active = isReceipt == receipt;
    return Expanded(
      child: OutlinedButton(
        onPressed: () => setState(() => isReceipt = receipt),
        style: OutlinedButton.styleFrom(
          backgroundColor: active ? color : Colors.white,
          foregroundColor: active ? Colors.white : navy,
          side: BorderSide(color: active ? color : border),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
      ),
    );
  }

  Widget _passbookCard(Map<String, dynamic> e) {
    final side = '${e['side']}';
    final isCr = side == 'CR';
    final amt = (e['amount'] as num?)?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: border), borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            color: isCr ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
            child: Text(side, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: isCr ? green : red)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${e['party_name']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                Text('${e['entry_date']} | ${e['narration'] ?? ''}', style: const TextStyle(fontSize: 9.5, color: Color(0xFF748094))),
              ],
            ),
          ),
          Text('₹${amt.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isCr ? green : red)),
        ],
      ),
    );
  }
}

// ─── Journal Entry ───────────────────────────────────────────────────────────

class _JournalEntryPanel extends StatefulWidget {
  const _JournalEntryPanel();
  @override
  State<_JournalEntryPanel> createState() => _JournalEntryPanelState();
}

class _JournalEntryPanelState extends State<_JournalEntryPanel> {
  final repo = UltraRepository.instance;
  String voucherDate = DateFormat('dd-MMM-yyyy').format(DateTime.now()).toUpperCase();
  final narration = TextEditingController();
  List<Map<String, String>> accounts = [];
  final lines = [_JournalLine()];

  @override
  void initState() {
    super.initState();
    loadAccounts();
  }

  Future<void> loadAccounts() async {
    accounts = await repo.masterAccountDirectory();
    if (mounted) setState(() {});
  }

  double get total => lines.fold(0, (s, l) => s + l.amount);

  Future<void> _save() async {
    if (total <= 0) return;
    final linePayload = <Map<String, dynamic>>[];
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      final drLabel = accounts.firstWhere((a) => a['key'] == l.drKey, orElse: () => {'label': ''})['label'] ?? '';
      final crLabel = accounts.firstWhere((a) => a['key'] == l.crKey, orElse: () => {'label': ''})['label'] ?? '';
      linePayload.add({
        'line_no': i + 1,
        'dr_account_key': l.drKey,
        'dr_account_label': drLabel,
        'cr_account_key': l.crKey,
        'cr_account_label': crLabel,
        'amount': l.amount,
      });
    }
    await repo.createJournalVoucher({
      'voucher_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'narration': narration.text,
      'total_amount': total,
      'created_at': DateTime.now().toIso8601String(),
      'lines': linePayload,
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JOURNAL RECORD SAVED')));
    setState(() {
      lines..clear()..add(_JournalLine());
      narration.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NEW JOURNAL VOUCHER', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
          const Text('DOUBLE ENTRY FINANCIAL ADJUSTMENT INTERCEPTOR JOURNAL',
              style: TextStyle(fontSize: 10, color: Color(0xFF748094), fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(4)),
                child: Text('VOUCHER DATE: $voucherDate', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: narration,
                  decoration: InputDecoration(
                    hintText: 'VOUCHER NARRATION EXPLANATION DESCRIPTION',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(lines.length, (i) => _journalBlock(i)),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('TOTAL VOUCHER SUMMARY VALUE AMOUNT  ₹ ${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => setState(() => lines.add(_JournalLine())),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('+ ADD LINE ENTRY', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(backgroundColor: navy, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
                child: const Text('SAVE JOURNAL RECORD', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _journalBlock(int i) {
    final line = lines[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: border), borderRadius: BorderRadius.circular(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: navy,
            child: Text('ENTRY TRANSACTION DIRECTORY #${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _sideTag('DR', true),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: line.drKey,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Debit (To) / Receiver Account Parameters',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Filter master accounts hierarchy...'),
                  items: accounts
                      .map((a) => DropdownMenuItem(value: a['key'], child: Text(a['label']!, style: const TextStyle(fontSize: 11))))
                      .toList(),
                  onChanged: (v) => setState(() => line.drKey = v),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Icon(Icons.arrow_downward, size: 16, color: Color(0xFF748094)),
          ),
          Row(
            children: [
              _sideTag('CR', false),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: line.crKey,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Credit (By) / Giver Account Parameters',
                    filled: true,
                    fillColor: const Color(0xFFFFF9E6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  items: accounts
                      .map((a) => DropdownMenuItem(value: a['key'], child: Text(a['label']!, style: const TextStyle(fontSize: 11))))
                      .toList(),
                  onChanged: (v) => setState(() => line.crKey = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('TRANSACTION VALUE AMOUNT:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                  onChanged: (v) => setState(() => line.amount = double.tryParse(v) ?? 0),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: lines.length == 1 ? null : () => setState(() => lines.removeAt(i)),
                icon: const Icon(Icons.delete_outline, color: red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sideTag(String label, bool isDr) => Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        color: isDr ? teal : const Color(0xFFE67E22),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
      );
}

class _JournalLine {
  String? drKey;
  String? crKey;
  double amount = 0;
}

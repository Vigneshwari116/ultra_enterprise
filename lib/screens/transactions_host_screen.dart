import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ultra_repository.dart';
import '../widgets/compact_date_picker.dart';
import '../widgets/enterprise_form_fields.dart';
import '../widgets/enterprise_widgets.dart';
import '../widgets/invoice.dart';

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
                    final stacked = c.maxWidth < formTwoColumnMinWidth;
                    final s1 = _section('SECTION 1: DISPATCH / SOURCE METADATA', [
                      _pair(
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: enterpriseInsetFieldShell(
                            label: 'NOTE NUMERIC NO *',
                            filled: true,
                            child: Text(noteNo, style: enterpriseInsetValueStyle),
                          ),
                        ),
                        _dateInset('NOTE ISSUE DATE', issueDate, (v) => issueDate = v),
                      ),
                      _pair(
                        enterpriseInsetTextField(label: 'ORIGINAL INVOICE REF NO', controller: origInvRef),
                        _dateInset('ORIGINAL INVOICE DATE', origInvDate, (v) => origInvDate = v),
                      ),
                      enterpriseInsetDropdown<String>(
                        label: 'REASON FOR TRANSACTION REVERSAL',
                        value: reason,
                        items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 11)))).toList(),
                        onChanged: (v) => setState(() => reason = v ?? reason),
                      ),
                      const SizedBox(height: 4),
                      enterpriseInsetTextField(label: 'E-WAY BILL NO', controller: eway),
                      enterpriseInsetTextField(label: 'LOGISTICS DISPATCH VEHICLE DETAILS / MODE', controller: logistics),
                    ]);
                    final s2 = _section('SECTION 2: ALLOCATED PARTY DIRECTORY', [
                      enterpriseInsetDropdown<int>(
                        label: isDebit ? 'SELECT SUPPLIER ACCOUNT DIRECTORY *' : 'SELECT CUSTOMER ACCOUNT DIRECTORY *',
                        value: partyId,
                        items: (isDebit ? suppliers : customers)
                            .map((p) => DropdownMenuItem<int>(
                                  value: p['id'] as int,
                                  child: Text('${isDebit ? p['supplier_name'] : p['customer_name']}', style: const TextStyle(fontSize: 11)),
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
                      const SizedBox(height: 4),
                      enterpriseInsetTextField(label: 'REGISTERED OFFICE BILLING ADDRESS', controller: address, maxLines: 2),
                      _pair(
                        enterpriseInsetTextField(label: 'CITY LOCATION', controller: city),
                        enterpriseInsetTextField(label: 'PINCODE', controller: pin),
                      ),
                      enterpriseInsetTextField(label: 'PARTY IDENTIFICATION (GSTIN) NUMBER', controller: gstin),
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
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(4), color: Colors.white),
                  child: enterpriseMatrixScroller(minWidth: 720, table: _adjustmentMatrix()),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => setState(() => rows.add(_AdjRow())),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('+ ADD REVERSAL MATERIAL ITEM ROW', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                ),
                const SizedBox(height: 14),
                enterpriseInsetTextField(
                  label: 'NARRATION / ACCOUNT COMMENTS',
                  controller: narration,
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                enterpriseValueWordsFooter(
                  valueInWords: formatUltraAmountInWords(grandTotal),
                  wordsLabel: 'REVERSAL VALUE IN WORDS',
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

  Table _adjustmentMatrix() {
    return Table(
      columnWidths: adjustmentNoteMatrixColumns,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(color: navy2),
          children: [
            enterpriseMatrixHeadCell('SL'),
            enterpriseMatrixHeadCell('MATERIAL MATRIX PARTICULARS'),
            enterpriseMatrixHeadCell('UOM'),
            enterpriseMatrixHeadCell('HSN'),
            enterpriseMatrixHeadCell('QTY'),
            enterpriseMatrixHeadCell('RATE/VAL'),
            enterpriseMatrixHeadCell('CGST%'),
            enterpriseMatrixHeadCell('SGST%'),
            enterpriseMatrixHeadCell('IGST%'),
            enterpriseMatrixHeadCell('COMPOUND TOTAL'),
            const SizedBox.shrink(),
          ],
        ),
        ...List.generate(rows.length, (i) {
          final r = rows[i];
          return TableRow(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border.withOpacity(.6)))),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                child: Text('${i + 1}', style: enterpriseMatrixCellStyle),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: DropdownButton<int>(
                  isExpanded: true,
                  isDense: true,
                  underline: const SizedBox(),
                  hint: const Text('Item Description', style: TextStyle(fontSize: 9, color: Color(0xFF9AA5B4))),
                  value: r.productId,
                  items: products
                      .map((p) => DropdownMenuItem(value: p['id'] as int, child: Text('${p['product_name']}', style: const TextStyle(fontSize: 9))))
                      .toList(),
                  onChanged: (v) {
                    final p = products.firstWhere((x) => x['id'] == v);
                    setState(() => r.setProduct(p));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: DropdownButton<int>(
                  isExpanded: true,
                  isDense: true,
                  underline: const SizedBox(),
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
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Text(r.hsn, style: enterpriseMatrixCellStyle, overflow: TextOverflow.ellipsis),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: TextField(
                  key: ValueKey('adj-q-$i'),
                  keyboardType: TextInputType.number,
                  style: enterpriseMatrixCellStyle,
                  decoration: enterpriseMatrixInputDecoration,
                  onChanged: (v) => setState(() => r.qty = double.tryParse(v) ?? 0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: TextField(
                  key: ValueKey('adj-r-$i'),
                  keyboardType: TextInputType.number,
                  style: enterpriseMatrixCellStyle,
                  decoration: enterpriseMatrixInputDecoration,
                  onChanged: (v) => setState(() => r.rate = double.tryParse(v) ?? 0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: TextField(
                  key: ValueKey('adj-cg-$i-${r.cgstPct}'),
                  keyboardType: TextInputType.number,
                  style: enterpriseMatrixCellStyle,
                  decoration: enterpriseMatrixInputDecoration,
                  controller: TextEditingController(text: r.cgstPct == 0 ? '' : '${r.cgstPct}'),
                  onChanged: (v) => setState(() => r.cgstPct = double.tryParse(v) ?? 0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: TextField(
                  key: ValueKey('adj-sg-$i-${r.sgstPct}'),
                  keyboardType: TextInputType.number,
                  style: enterpriseMatrixCellStyle,
                  decoration: enterpriseMatrixInputDecoration,
                  controller: TextEditingController(text: r.sgstPct == 0 ? '' : '${r.sgstPct}'),
                  onChanged: (v) => setState(() => r.sgstPct = double.tryParse(v) ?? 0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: TextField(
                  key: ValueKey('adj-ig-$i-${r.igstPct}'),
                  keyboardType: TextInputType.number,
                  style: enterpriseMatrixCellStyle,
                  decoration: enterpriseMatrixInputDecoration,
                  controller: TextEditingController(text: r.igstPct == 0 ? '' : '${r.igstPct}'),
                  onChanged: (v) => setState(() => r.igstPct = double.tryParse(v) ?? 0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Text(r.total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 9.5, color: navy)),
              ),
              IconButton(
                onPressed: rows.length == 1 ? null : () => setState(() => rows.removeAt(i)),
                icon: const Icon(Icons.delete_outline, color: red, size: 15),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _dateInset(String label, String iso, ValueChanged<String> on) {
    final display = DateFormat('dd-MM-yyyy').format(DateTime.tryParse(iso) ?? DateTime.now());
    return enterpriseInsetTextField(
      label: label,
      readOnly: true,
      controller: TextEditingController(text: display),
      prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF748094)),
      onTap: () async {
        final picked = await pickCompactDate(context, initialDate: DateTime.tryParse(iso) ?? DateTime.now());
        if (picked != null) setState(() => on(formatIsoDate(picked)));
      },
    );
  }

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: navy, letterSpacing: .3)),
          const SizedBox(height: 4),
          Container(height: 1, color: border),
          const SizedBox(height: 12),
          ...children,
        ],
      );

  Widget _stat(String l, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l, style: const TextStyle(color: Colors.white70, fontSize: 8)),
          Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
        ],
      );

  Widget _pair(Widget a, Widget b) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]));
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: border), borderRadius: BorderRadius.circular(6)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(isReceipt ? 'NEW RECEIPT RECORD' : 'NEW PAYMENT RECORD',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: navy)),
                        const SizedBox(height: 14),
                        enterpriseInsetFieldShell(
                          label: 'VOUCHER REGISTRATION DATE',
                          filled: true,
                          child: Row(
                            children: [
                              const Icon(Icons.lock_outline, size: 14, color: Color(0xFF748094)),
                              const SizedBox(width: 8),
                              Text(voucherDate, style: enterpriseInsetValueStyle),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        enterpriseInsetDropdown<String>(
                          label: isReceipt ? 'SEARCH CUSTOMER DIRECTORY *' : 'TARGET ALLOCATED LEDGER NAME *',
                          value: partyKey,
                          hint: const Text('Search Customer/Supplier...', style: TextStyle(fontSize: 11, color: Color(0xFF9AA5B4))),
                          items: _partyItems,
                          onChanged: (v) => setState(() => partyKey = v),
                        ),
                        const SizedBox(height: 4),
                        enterpriseInsetTextField(
                          label: 'TRANSACTION VOUCHER AMOUNT *',
                          controller: amount,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: navy),
                        ),
                        const SizedBox(height: 4),
                        enterpriseInsetTextField(
                          label: 'VOUCHER REMARKS / NARRATION',
                          controller: remarks,
                          maxLines: 3,
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
                          Expanded(
                            child: Text('CASH PASSBOOK (CR/DR) ACCOUNT TRANSACTION DIRECTORY LOGS',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF748094))),
                          ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: enterpriseInsetFieldShell(
                  label: 'VOUCHER DATE',
                  filled: true,
                  child: Text(voucherDate, style: enterpriseInsetValueStyle),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: enterpriseInsetTextField(
                  label: 'VOUCHER NARRATION EXPLANATION DESCRIPTION',
                  controller: narration,
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
                child: enterpriseInsetDropdown<String>(
                  label: 'DEBIT (TO) / RECEIVER ACCOUNT PARAMETERS',
                  value: line.drKey,
                  hint: const Text('Filter master accounts hierarchy...', style: TextStyle(fontSize: 11, color: Color(0xFF9AA5B4))),
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
                child: enterpriseInsetDropdown<String>(
                  label: 'CREDIT (BY) / GIVER ACCOUNT PARAMETERS',
                  value: line.crKey,
                  borderColor: const Color(0xFFE6C200),
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
              Expanded(
                flex: 3,
                child: enterpriseInsetFieldShell(
                  label: 'TRANSACTION VALUE AMOUNT',
                  borderColor: const Color(0xFFE6C200),
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: enterpriseInsetValueStyle,
                    decoration: enterpriseInsetInputDecoration(),
                    onChanged: (v) => setState(() => line.amount = double.tryParse(v) ?? 0),
                  ),
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

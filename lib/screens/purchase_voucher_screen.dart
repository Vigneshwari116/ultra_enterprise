import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ultra_repository.dart';
import '../widgets/compact_date_picker.dart';
import '../widgets/enterprise_form_fields.dart';
import '../widgets/enterprise_widgets.dart';
import '../widgets/transaction_line_math.dart';
import 'product_catalog_refresh.dart';

class PurchaseVoucherScreen extends StatefulWidget {
  const PurchaseVoucherScreen({super.key});
  @override
  State<PurchaseVoucherScreen> createState() => _PurchaseVoucherScreenState();
}

class _PurchaseVoucherScreenState extends State<PurchaseVoucherScreen> {
  final repo = UltraRepository.instance;
  final supplierInvoiceNo = TextEditingController(),
      remarks = TextEditingController();
  final supplierAddress = TextEditingController(),
      city = TextEditingController(),
      pin = TextEditingController(),
      gstin = TextEditingController(),
      bank = TextEditingController(),
      account = TextEditingController();
  final voucherNoController = TextEditingController();

  String voucherDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String supplierInvoiceDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String voucherNo = '';

  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> units = [];
  List<Map<String, dynamic>> openOrders = [];
  int? supplierId;
  int? againstPoId;
  final rows = [_PvRow()];

  late final Future<void> Function() _productCatalogRefreshHandler;

  @override
  void initState() {
    super.initState();
    _productCatalogRefreshHandler = refreshProductCatalog;
    registerProductCatalogRefresh(_productCatalogRefreshHandler);
    load();
  }

  Future<void> refreshProductCatalog() async {
    products = await repo.products();
    units = await repo.units();
    if (mounted) setState(() {});
  }

  Future<void> load() async {
    suppliers = await repo.suppliers();
    products = await repo.products();
    units = await repo.units();
    openOrders = await repo.openPurchaseOrders();
    voucherNo = '${await repo.nextPurchaseVoucherNo()}';
    voucherNoController.text = voucherNo;
    if (mounted) setState(() {});
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value');
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  void fillSupplier(Map<String, dynamic> s) {
    supplierAddress.text = s['address'] ?? '';
    city.text = s['city'] ?? '';
    pin.text = s['postal_pincode'] ?? '';
    gstin.text = s['gstin'] ?? '';
    bank.text = s['bank_name'] ?? '';
    account.text = s['bank_account_no'] ?? '';
  }

  TransactionLineTotals _lineTotals(_PvRow r) => TransactionLineTotals.compute(
        qty: r.qty,
        rate: r.rate,
        cgstPct: r.cgstPct,
        sgstPct: r.sgstPct,
        igstPct: r.igstPct,
      );

  double get taxable => rows.fold(0, (s, r) => s + _lineTotals(r).taxable);
  double get cgst => rows.fold(0, (s, r) => s + _lineTotals(r).cgst);
  double get sgst => rows.fold(0, (s, r) => s + _lineTotals(r).sgst);
  double get igst => rows.fold(0, (s, r) => s + _lineTotals(r).igst);
  double get total => taxable + cgst + sgst + igst;

  Future<void> loadAgainstPo(int? poId) async {
    if (poId == null) {
      setState(() => againstPoId = null);
      return;
    }
    againstPoId = poId;
    final po = openOrders.firstWhere((x) => x['id'] == poId);
    supplierId = _toInt(po['supplier_id']);
    final s = suppliers.where((x) => x['id'] == supplierId);
    if (s.isNotEmpty) fillSupplier(s.first);
    final items = await repo.purchaseOrderItems(poId);
    _disposeAllRows();
    rows.clear();
    if (items.isNotEmpty) {
      rows.addAll(items.map(_PvRow.fromPurchaseOrderItem));
    } else {
      rows.add(_PvRow());
    }
    if (mounted) setState(() {});
  }

  void _disposeAllRows() {
    for (final r in rows) {
      r.dispose();
    }
  }

  String _poPickerLabel(Map<String, dynamic> o) {
    final poNo = o['po_no'] ?? o['id'];
    final party = '${o['party_name'] ?? '-'}';
    final rawDate = '${o['po_date'] ?? ''}';
    final parsed = DateTime.tryParse(rawDate);
    final dateLabel =
        parsed == null ? rawDate : DateFormat('dd-MM-yyyy').format(parsed);
    final total = _toDouble(o['grand_total']);
    return 'PO-$poNo • $party • $dateLabel • ₹${total.toStringAsFixed(2)}';
  }

  @override
  void dispose() {
    unregisterProductCatalogRefresh(_productCatalogRefreshHandler);
    _disposeAllRows();
    for (final c in [
      supplierInvoiceNo,
      remarks,
      supplierAddress,
      city,
      pin,
      gstin,
      bank,
      account,
      voucherNoController
    ]) c.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
      String currentIso, ValueChanged<String> onPicked) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(currentIso) ?? now;
    final picked = await pickCompactDate(
      context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) onPicked(formatIsoDate(picked));
  }

  Future<void> save() async {
    if (supplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a supplier before saving.')));
      return;
    }
    final uuid = repo.newUuid();
    final items = rows.map(
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
          'taxable': t.taxable,
          'cgst': t.cgst,
          'sgst': t.sgst,
          'igst': t.igst,
          'total': t.total,
        };
      },
    ).toList();
    try {
      await repo.createPurchaseVoucher({
        'uuid': uuid,
        'voucher_no': int.tryParse(voucherNo),
        'voucher_date': voucherDate,
        'supplier_invoice_no': supplierInvoiceNo.text,
        'supplier_invoice_date': supplierInvoiceDate,
        'purchase_order_id': againstPoId,
        'supplier_id': supplierId,
        'taxable_total': taxable,
        'cgst_total': cgst,
        'sgst_total': sgst,
        'igst_total': igst,
        'grand_total': total,
        'status': 'POSTED',
        'items': items,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server save failed: $e')),
        );
      }
      return;
    }
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PURCHASE VOUCHER POSTED — STOCK UPDATED')));
    await load();
    setState(() {
      _disposeAllRows();
      rows
        ..clear()
        ..add(_PvRow());
      supplierInvoiceNo.clear();
      remarks.clear();
      againstPoId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: enterpriseScrollColumn(children: [
        Container(
          width: double.infinity,
          color: const Color(0xFF19232C),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('COMMERCIAL PURCHASE TERMINAL',
                      style: TextStyle(
                          color: Color(0xFF2FE6E0),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .4)),
                  const SizedBox(height: 10),
                  Row(children: [
                    _statMini(
                        'TOTAL PCS',
                        rows
                            .fold<double>(0, (s, r) => s + r.qty)
                            .toStringAsFixed(0)),
                    const SizedBox(width: 22),
                    _statMini('TAXABLE NET', taxable.toStringAsFixed(2)),
                    const SizedBox(width: 22),
                    _statMini('COMPOUND GST',
                        (cgst + sgst + igst).toStringAsFixed(2)),
                  ]),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Color(0xFFF4D53A),
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  const Text('NET PAYABLE VALUE',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .4)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _plainSection(
                    title: 'SECTION 1: TRANSACTION METADATA',
                    children: [
                      _pair(
                        _outline('VOUCHER NO',
                            controller: voucherNoController,
                            readOnly: true,
                            filled: true),
                        enterpriseInsetDateField(
                          label: 'VOUCHER DATE',
                          isoDate: voucherDate,
                          onTap: () => _pickDate(voucherDate,
                              (v) => setState(() => voucherDate = v)),
                        ),
                      ),
                      _pair(
                        _outline('SUPPLIER INVOICE NO',
                            controller: supplierInvoiceNo, autofocus: true),
                        enterpriseInsetDateField(
                          label: 'SUPPLIER INVOICE DATE',
                          isoDate: supplierInvoiceDate,
                          onTap: () => _pickDate(supplierInvoiceDate,
                              (v) => setState(() => supplierInvoiceDate = v)),
                        ),
                      ),
                      enterpriseInsetDropdown<int?>(
                        label: 'AGAINST PURCHASE ORDER (OPTIONAL)',
                        value: againstPoId,
                        hint: const Text('— No linked PO —',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF9AA5B4))),
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null, child: Text('— No linked PO —')),
                          ...openOrders.map((o) {
                            final poId = _toInt(o['id']);
                            if (poId == null) {
                              return null;
                            }
                            return DropdownMenuItem<int?>(
                              value: poId,
                              child: Text(
                                _poPickerLabel(o),
                                style: const TextStyle(fontSize: 10.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).whereType<DropdownMenuItem<int?>>(),
                        ],
                        onChanged: (v) => loadAgainstPo(v),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: enterpriseInsetTextField(
                            label: 'REMARKS', controller: remarks, maxLines: 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _plainSection(
                    title: 'SECTION 2: ACCOUNT / PARTY CONFIGURATION',
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: enterpriseInsetDropdown<int>(
                          label: 'SELECT SUPPLIER',
                          value: supplierId,
                          items: suppliers
                              .map((s) => DropdownMenuItem<int>(
                                  value: s['id'] as int,
                                  child: Text('${s['supplier_name']}')))
                              .toList(),
                          onChanged: (v) {
                            final s = suppliers.firstWhere((x) => x['id'] == v);
                            setState(() {
                              supplierId = v;
                              fillSupplier(s);
                            });
                          },
                        ),
                      ),
                      _pair(
                          _outline('ADDRESS',
                              controller: supplierAddress, filled: true),
                          _outline('CITY', controller: city, filled: true)),
                      _pair(_outline('PINCODE', controller: pin, filled: true),
                          _outline('GSTIN', controller: gstin, filled: true)),
                      _pair(
                          _outline('BANK NAME', controller: bank, filled: true),
                          _outline('ACCOUNT NO',
                              controller: account, filled: true)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text('SECTION 3: QUANTITY MATRIX PRODUCT ENTRY',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: navy,
                    letterSpacing: .3)),
            const SizedBox(height: 4),
            Container(height: 1, color: border),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(4),
              ),
              child:
                  enterpriseMatrixScroller(table: _productMatrixTable(context)),
            ),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => rows.add(_PvRow())),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('ADD NEW MATERIAL ROW',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: navy,
                  side: const BorderSide(color: border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            enterpriseValueWordsFooter(
                valueInWords: payableAmountInWords(total)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFF4D53A))),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 15, color: Color(0xFF8A6D00)),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Posting this voucher will increase on-hand stock for every material line, and mark the linked Purchase Order (if any) as RECEIVED.',
                        style: TextStyle(
                            color: Color(0xFF8A6D00),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700))),
              ]),
            ),
            const SizedBox(height: 18),
            Center(
              child: ElevatedButton.icon(
                onPressed: save,
                icon: const Icon(Icons.inventory_2_outlined, size: 17),
                label: const Text('POST PURCHASE VOUCHER',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E8B30),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ]),
        ),
      ]),
    );
  }

  Widget _outline(String label,
      {TextEditingController? controller,
      bool readOnly = false,
      bool filled = false,
      Widget? prefixIcon,
      VoidCallback? onTap,
      bool autofocus = false}) {
    return enterpriseInsetTextField(
      label: label,
      controller: controller,
      readOnly: readOnly,
      filled: filled,
      prefixIcon: prefixIcon,
      onTap: onTap,
      autofocus: autofocus,
    );
  }

  Widget _statMini(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
        ],
      );
  Widget _pair(Widget a, Widget b) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: a),
          const SizedBox(width: 14),
          Expanded(child: b),
        ]),
      );
  Widget _plainSection(
          {required String title, required List<Widget> children}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: navy,
                  letterSpacing: .3)),
          const SizedBox(height: 4),
          Container(height: 1, color: border),
          const SizedBox(height: 8),
          ...children,
        ],
      );
  Table _productMatrixTable(BuildContext context) {
    return Table(
      columnWidths: enterpriseProductMatrixColumns,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(color: navy2),
          children: [
            enterpriseMatrixHeadCell('SL'),
            enterpriseMatrixHeadCell('MATERIAL PRODUCT DESCRIPTION'),
            enterpriseMatrixHeadCell('UOM'),
            enterpriseMatrixHeadCell('HSN'),
            enterpriseMatrixHeadCell('QTY'),
            enterpriseMatrixHeadCell('RATE'),
            enterpriseMatrixHeadCell('CGST%'),
            enterpriseMatrixHeadCell('SGST%'),
            enterpriseMatrixHeadCell('IGST%'),
            enterpriseMatrixHeadCell('COMPOUND TOTAL'),
            const SizedBox.shrink(),
          ],
        ),
        ...List.generate(rows.length, (i) {
          return TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: border.withOpacity(.6))),
            ),
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
                  hint: const Text('Item Description',
                      style: TextStyle(fontSize: 9, color: Color(0xFF9AA5B4))),
                  value: catalogIdInList(rows[i].productId, products),
                  items: products
                      .map((p) {
                        final id = coerceCatalogId(p['id']);
                        if (id == null) return null;
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text('${p['product_name']}',
                              style: const TextStyle(fontSize: 9),
                              overflow: TextOverflow.ellipsis),
                        );
                      })
                      .whereType<DropdownMenuItem<int>>()
                      .toList(),
                  onChanged: (v) {
                    final p = products
                        .firstWhere((x) => coerceCatalogId(x['id']) == v);
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
                  value: catalogIdInList(rows[i].unitId, units),
                  hint: const Text('UOM', style: TextStyle(fontSize: 9)),
                  items: units
                      .map((u) {
                        final id = coerceCatalogId(u['id']);
                        if (id == null) return null;
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text('${u['code']}',
                              style: const TextStyle(fontSize: 9)),
                        );
                      })
                      .whereType<DropdownMenuItem<int>>()
                      .toList(),
                  onChanged: (v) {
                    final u =
                        units.firstWhere((x) => coerceCatalogId(x['id']) == v);
                    setState(() {
                      rows[i].unitId = v;
                      rows[i].uom = '${u['code']}';
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Text(rows[i].hsn.isEmpty ? '—' : rows[i].hsn,
                    style: enterpriseMatrixCellStyle,
                    overflow: TextOverflow.ellipsis),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                child: enterpriseMatrixTextField(
                  context: context,
                  controller: rows[i].qtyController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) =>
                      setState(() => rows[i].qty = double.tryParse(v) ?? 0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                child: enterpriseMatrixTextField(
                  context: context,
                  controller: rows[i].rateController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) =>
                      setState(() => rows[i].rate = double.tryParse(v) ?? 0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                child: enterpriseMatrixTextField(
                  context: context,
                  controller: rows[i].cgstController,
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      setState(() => rows[i].cgstPct = double.tryParse(v) ?? 0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                child: enterpriseMatrixTextField(
                  context: context,
                  controller: rows[i].sgstController,
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      setState(() => rows[i].sgstPct = double.tryParse(v) ?? 0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                child: enterpriseMatrixTextField(
                  context: context,
                  controller: rows[i].igstController,
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      setState(() => rows[i].igstPct = double.tryParse(v) ?? 0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Text(
                  '₹${_lineTotals(rows[i]).total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 9.5, color: navy),
                ),
              ),
              IconButton(
                onPressed: rows.length == 1
                    ? null
                    : () => setState(() {
                          rows[i].dispose();
                          rows.removeAt(i);
                        }),
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
}

String _pvMatrixNum(double v, {bool blankZero = false}) {
  if (blankZero && v == 0) return '';
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toString();
}

class _PvRow {
  int? productId;
  int? unitId;
  String description = '';
  String uom = 'PCS';
  String hsn = '';
  double qty = 0;
  double rate = 0;
  double cgstPct = 9;
  double sgstPct = 9;
  double igstPct = 0;

  /// When true, [setProduct] keeps [rate] unless the user picks a different product (PO agreed rate).
  bool preserveAgreedRate = false;

  late final TextEditingController qtyController;
  late final TextEditingController rateController;
  late final TextEditingController cgstController;
  late final TextEditingController sgstController;
  late final TextEditingController igstController;

  _PvRow() {
    qtyController = TextEditingController();
    rateController = TextEditingController();
    cgstController = TextEditingController(text: _pvMatrixNum(cgstPct));
    sgstController = TextEditingController(text: _pvMatrixNum(sgstPct));
    igstController = TextEditingController(text: _pvMatrixNum(igstPct));
  }

  factory _PvRow.fromPurchaseOrderItem(Map<String, dynamic> it) {
    final row = _PvRow()
      ..productId = coerceCatalogId(it['product_id'])
      ..unitId = coerceCatalogId(it['unit_id'])
      ..description = '${it['description'] ?? ''}'
      ..uom = '${it['uom'] ?? 'PCS'}'
      ..hsn = '${it['hsn'] ?? ''}'
      ..qty = (it['quantity'] as num?)?.toDouble() ?? 0
      ..rate = (it['rate'] as num?)?.toDouble() ?? 0
      ..cgstPct = (it['cgst_percent'] as num?)?.toDouble() ?? 9
      ..sgstPct = (it['sgst_percent'] as num?)?.toDouble() ?? 9
      ..igstPct = (it['igst_percent'] as num?)?.toDouble() ?? 0
      ..preserveAgreedRate = true;
    row._syncControllersFromModel();
    return row;
  }

  void _syncControllersFromModel() {
    qtyController.text = _pvMatrixNum(qty);
    rateController.text = _pvMatrixNum(rate);
    cgstController.text = _pvMatrixNum(cgstPct);
    sgstController.text = _pvMatrixNum(sgstPct);
    igstController.text = _pvMatrixNum(igstPct);
  }

  void dispose() {
    qtyController.dispose();
    rateController.dispose();
    cgstController.dispose();
    sgstController.dispose();
    igstController.dispose();
  }

  void setProduct(Map<String, dynamic> p) {
    final previousProductId = productId;
    productId = coerceCatalogId(p['id']);
    description = '${p['product_name'] ?? ''}';
    unitId = catalogUnitId(p);
    uom = catalogUomCode(p);
    hsn = catalogProductHsn(p);
    final productChanged = productId != previousProductId;
    if (!preserveAgreedRate || productChanged) {
      rate = catalogPurchaseRate(p);
      rateController.text = _pvMatrixNum(rate);
      preserveAgreedRate = false;
    }
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
      cgstController.text = _pvMatrixNum(cgstPct);
      sgstController.text = _pvMatrixNum(sgstPct);
      igstController.text = _pvMatrixNum(igstPct);
    }
  }
}

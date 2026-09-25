import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../widgets/compact_date_picker.dart';
import '../widgets/enterprise_widgets.dart';
import '../widgets/invoice.dart';
import '../widgets/sales_report.dart';

/// Used by [AppShell] to refresh UOM/product lists after Unit Master saves.
final salesInvoiceCatalogKey = GlobalKey<SalesInvoiceCatalogHostState>();

abstract class SalesInvoiceCatalogHostState extends State<SalesInvoiceScreen> {
  Future<void> refreshCatalog();
}

class SalesInvoiceScreen extends StatefulWidget {
  const SalesInvoiceScreen({super.key});
  @override
  SalesInvoiceCatalogHostState createState() => _SalesInvoiceScreenState();
}

class _SalesInvoiceScreenState extends SalesInvoiceCatalogHostState {
  final db=AppDatabase.instance;
  final po=TextEditingController(), challan=TextEditingController(), packages=TextEditingController(text:'0'), vehicle=TextEditingController(), due=TextEditingController(text:'0'), eway=TextEditingController();
  final customerAddress=TextEditingController(), city=TextEditingController(), pin=TextEditingController(), gstin=TextEditingController(), bank=TextEditingController(), account=TextEditingController(), shipping=TextEditingController();
  final fwdCharge = TextEditingController(text: '0');

  // Internal dates are kept as ISO (yyyy-MM-dd); displayed as dd-MM-yyyy like the reference.
  String date=DateFormat('yyyy-MM-dd').format(DateTime.now());
  String poDate=DateFormat('yyyy-MM-dd').format(DateTime.now());
  String challanDate=DateFormat('yyyy-MM-dd').format(DateTime.now());
  // Empty until the user picks one — mirrors the reference's mandatory red "Choose Option" state.
  String zone='';
  String voucherNo='';

  List<Map<String,dynamic>> customers=[]; List<Map<String,dynamic>> products=[]; List<Map<String,dynamic>> units=[]; int? customerId;
  final rows=[_InvoiceRow()];

  @override void initState(){super.initState();load();}

  Future<void> load() async {
    customers = await db.customers();
    products = await db.products();
    units = await db.units();
    final count = await db.nextSalesVoucherNo();
    voucherNo = '$count';
    if (customers.isNotEmpty && customerId == null) {
      customerId = customers.first['id'];
      fillCustomer(customers.first);
    }
    if (mounted) setState(() {});
  }

  /// Refreshes product/UOM lists when returning from Unit Master.
  @override
  Future<void> refreshCatalog() async {
    products = await db.products();
    units = await db.units();
    if (mounted) setState(() {});
  }

  void fillCustomer(Map<String,dynamic> c){customerAddress.text=c['address']??'';city.text=c['city']??'';pin.text=c['postal_pincode']??'';gstin.text=c['gstin']??'';bank.text=c['bank_name']??'';account.text=c['bank_account_no']??'';shipping.text=c['shipping_address']??'';}

  double get taxable=>rows.fold(0,(s,r)=>s+r.taxable);
  double get cgst=>rows.fold(0,(s,r)=>s+r.cgst);
  double get sgst=>rows.fold(0,(s,r)=>s+r.sgst);
  double get igst=>rows.fold(0,(s,r)=>s+r.igst);
  double get total=>taxable+cgst+sgst+igst;

  @override void dispose(){for(final c in [po,challan,packages,vehicle,due,eway,customerAddress,city,pin,gstin,bank,account,shipping,fwdCharge])c.dispose();super.dispose();}

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
    }
  }

  String _display(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd-MM-yyyy').format(d);
  }

  double get fwd => double.tryParse(fwdCharge.text) ?? 0;

  double get netPayable => total + fwd;

  Future<int?> _persistInvoice() async {
    if (zone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the State Zone Applicability before saving.')),
      );
      return null;
    }
    if (customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer before saving.')),
      );
      return null;
    }
    final uuid = db.newUuid();
    final invoiceId = await db.db.insert('sales_invoices', {
      'uuid': uuid,
      'invoice_no': int.tryParse(voucherNo),
      'transaction_date': date,
      'po_no': po.text,
      'po_date': poDate,
      'state_zone': zone,
      'challan_no': challan.text,
      'challan_date': challanDate,
      'total_packages': int.tryParse(packages.text) ?? 0,
      'vehicle_dispatch_mode': vehicle.text,
      'due_days': int.tryParse(due.text) ?? 0,
      'eway_bill_no': eway.text,
      'customer_id': customerId,
      'taxable_total': taxable,
      'cgst_total': cgst,
      'sgst_total': sgst,
      'igst_total': igst,
      'grand_total': netPayable,
      'status': 'POSTED',
    });
    for (final r in rows) {
      await db.db.insert('sales_invoice_items', {
        'invoice_id': invoiceId,
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
      });
    }
    await db.insertQueue({
      'entity_type': 'SALES_INVOICE',
      'entity_id': invoiceId,
      'payload': jsonEncode({'uuid': uuid, 'customer_id': customerId, 'transaction_date': date}),
      'status': 'PENDING',
      'created_at': DateTime.now().toIso8601String(),
    });
    return invoiceId;
  }

  void _resetForm() {
    setState(() {
      rows..clear()..add(_InvoiceRow());
      po.clear();
      challan.clear();
      packages.text = '0';
      vehicle.clear();
      due.text = '0';
      eway.clear();
      fwdCharge.text = '0';
      zone = '';
    });
  }

  Future<void> save() async {
    final invoiceId = await _persistInvoice();
    if (invoiceId == null) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SALES INVOICE SAVED LOCALLY — PENDING SYNC')),
      );
    }
    await load();
    _resetForm();
  }

  Future<void> saveAndPrint() async {
    final invoiceId = await _persistInvoice();
    if (invoiceId == null) return;
    final data = await invoiceDataFromId(invoiceId);
    if (data != null) {
      await printUltraInvoice(data);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SALES VOUCHER SAVED — PRINT DIALOG OPENED')),
      );
    }
    await load();
    _resetForm();
  }

  @override Widget build(BuildContext context){
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Container(
          width: double.infinity,
          color: const Color(0xFF19232C),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('COMMERCIAL SALES TERMINAL',
                      style: TextStyle(color: Color(0xFF2FE6E0), fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: .4)),
                  const SizedBox(height: 10),
                  Row(children: [
                    _statMini('TOTAL PCS', rows.fold<double>(0,(s,r)=>s+r.qty).toStringAsFixed(0)),
                    const SizedBox(width: 22),
                    _statMini('TAXABLE NET', taxable.toStringAsFixed(2)),
                    const SizedBox(width: 22),
                    _statMini('COMPOUND GST', (cgst+sgst+igst).toStringAsFixed(2)),
                  ]),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${netPayable.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFFF4D53A), fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  const Text('NET PAYABLE VALUE',
                      style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: .4)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 980;
                final section1 = _plainSection(
                    title: 'SECTION 1: TRANSACTION METADATA',
                    children: [
                      _pair(
                        _outline('SALES VOUCHER NO (AUTO)', controller: TextEditingController(text: voucherNo), readOnly: true, filled: true),
                        _outline('TRANSACTION DATE', controller: TextEditingController(text: _display(date)), readOnly: true,
                            prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
                            onTap: () => _pickDate(date, (v) => setState(() => date = v))),
                      ),
                      _pair(
                        _outline('PO NO', controller: po),
                        _outline('PO DATE', controller: TextEditingController(text: _display(poDate)), readOnly: true,
                            prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
                            onTap: () => _pickDate(poDate, (v) => setState(() => poDate = v))),
                      ),
                      _zoneField(),
                      const SizedBox(height: 14),
                      _pair(
                        _outline('CHALLAN / DC NO', controller: challan),
                        _outline('CHALLAN / DC DATE', controller: TextEditingController(text: _display(challanDate)), readOnly: true,
                            prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
                            onTap: () => _pickDate(challanDate, (v) => setState(() => challanDate = v))),
                      ),
                      _pair(
                        _outline('TOTAL NO OF PACKAGES', controller: packages),
                        _outline('VEHICLE NO / DISPATCH MODE', controller: vehicle),
                      ),
                      _pair(
                        _outline('DUE DAYS', controller: due),
                        _outline('E-WAY BILL NO (EWB NO)', controller: eway),
                      ),
                    ],
                  );
                final section2 = _plainSection(
                    title: 'SECTION 2: ACCOUNT / PARTY CONFIGURATION',
                    children: [
                      DropdownButtonFormField<int>(
                        value: customerId,
                        isExpanded: true,
                        decoration: _decoration('SELECT CUSTOMER (COMMERCIAL INVOICING) *'),
                        items: customers.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text(c['customer_name']))).toList(),
                        onChanged: (v) { final c = customers.firstWhere((x) => x['id'] == v); setState(() => customerId = v); fillCustomer(c); },
                      ),
                      const SizedBox(height: 14),
                      _outline('ADDRESS', controller: customerAddress, readOnly: true, filled: true),
                      const SizedBox(height: 14),
                      _pair(
                        _outline('CITY', controller: city, readOnly: true, filled: true),
                        _outline('POSTAL PINCODE', controller: pin, readOnly: true, filled: true),
                      ),
                      _pair(
                        _outline('PARTY GSTIN NO', controller: gstin, readOnly: true, filled: true),
                        _outline('BANK IDENTIFIER NAME', controller: bank, readOnly: true, filled: true),
                      ),
                      _pair(
                        _outline('BANK ACCOUNT NO', controller: account, readOnly: true, filled: true),
                        _outline('SHIPPING ADDRESS', controller: shipping, readOnly: true, filled: true),
                      ),
                    ],
                  );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      section1,
                      const SizedBox(height: 16),
                      section2,
                    ],
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
            const Text('SECTION 3: QUANTITY MATRIX PRODUCT ENTRY',
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
              child: _productMatrixTable(),
            ),
            const SizedBox(height:12),
            Center(
              child: OutlinedButton.icon(
                onPressed:()=>setState(()=>rows.add(_InvoiceRow())),
                icon:const Icon(Icons.add,size:16),
                label:const Text('ADD NEW MATERIAL ROW', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: navy,
                  side: const BorderSide(color: border),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ),
            const SizedBox(height:18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(color: const Color(0xFF19232C), borderRadius: BorderRadius.circular(4)),
              child: Row(
                children: [
                  Expanded(
                    child: Text('VALUE IN WORDS: ${_amountInWords(netPayable)}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .3)),
                  ),
                  SizedBox(
                    width: 110,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('FWD CHARGE', style: TextStyle(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: fwdCharge,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white.withOpacity(.08),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: BorderSide.none),
                            hintText: '0',
                            hintStyle: const TextStyle(color: Colors.white54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height:18),
            Center(
              child: ElevatedButton.icon(
                onPressed: saveAndPrint,
                icon: const Icon(Icons.print_outlined, size: 17),
                label: const Text('SAVE & PRINT SALES VOUCHER', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E8B30),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ),
            const SizedBox(height:30),
          ]),
        ),
      ]),
    );
  }

  InputDecoration _decoration(String label, {bool filled = false}) => InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    isDense: true,
    filled: filled,
    fillColor: filled ? const Color(0xFFF1F3F7) : Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: teal, width: 1.4)),
    labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF748094), letterSpacing: .2),
  );

  Widget _outline(String label, {TextEditingController? controller, bool readOnly = false, bool filled = false, Widget? prefixIcon, VoidCallback? onTap}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: navy),
      decoration: _decoration(label, filled: filled).copyWith(prefixIcon: prefixIcon),
    );
  }

  Widget _zoneField() {
    final mandatory = zone.isEmpty;
    return DropdownButtonFormField<String>(
      value: zone.isEmpty ? null : zone,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'SELECT STATE ZONE APPLICABILITY *',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: mandatory ? red : border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: mandatory ? red : border)),
        labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: mandatory ? red : const Color(0xFF748094), letterSpacing: .2),
      ),
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
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: a), const SizedBox(width: 14), Expanded(child: b),
    ]),
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
  String _amountInWords(double v) => v == 0 ? 'ZERO RUPEES ONLY' : '₹${v.toStringAsFixed(2)} ONLY';

  static const _matrixHeadStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 9);
  static const _matrixCellStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: navy);
  static const _matrixInputDecoration = InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
  );

  Widget _productMatrixTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        const spacing = 4.0;
        const slW = 24.0;
        const uomW = 52.0;
        const hsnW = 58.0;
        const qtyW = 46.0;
        const rateW = 50.0;
        const taxW = 42.0;
        const totalWcol = 68.0;
        const actW = 28.0;
        const colCount = 11;
        final fixed = slW + uomW + hsnW + qtyW + rateW + (taxW * 3) + totalWcol + actW + (spacing * colCount);
        final matW = (totalW - fixed - 12).clamp(96.0, 168.0);
        final needScroll = totalW < 720;

        final table = DataTable(
          columnSpacing: spacing,
          horizontalMargin: 6,
          headingRowHeight: 32,
          dataRowMinHeight: 36,
          headingRowColor: const WidgetStatePropertyAll(navy2),
          columns: const [
            DataColumn(label: Text('SL', style: _matrixHeadStyle)),
            DataColumn(label: Text('MATERIAL PRODUCT DESCRIPTION', style: _matrixHeadStyle)),
            DataColumn(label: Text('UOM', style: _matrixHeadStyle)),
            DataColumn(label: Text('HSN', style: _matrixHeadStyle)),
            DataColumn(label: Text('QTY', style: _matrixHeadStyle)),
            DataColumn(label: Text('RATE', style: _matrixHeadStyle)),
            DataColumn(label: Text('CGST%', style: _matrixHeadStyle)),
            DataColumn(label: Text('SGST%', style: _matrixHeadStyle)),
            DataColumn(label: Text('IGST%', style: _matrixHeadStyle)),
            DataColumn(label: Text('COMPOUND TOTAL', style: _matrixHeadStyle)),
            DataColumn(label: Text('', style: _matrixHeadStyle)),
          ],
          rows: List.generate(rows.length, (i) {
            return DataRow(
              cells: [
                DataCell(Text('${i + 1}', style: _matrixCellStyle)),
                DataCell(
                  SizedBox(
                    width: matW,
                    child: DropdownButton<int>(
                      isExpanded: true,
                      isDense: true,
                      hint: const Text('Item Description', style: TextStyle(fontSize: 10, color: Color(0xFF9AA5B4))),
                      value: rows[i].productId,
                      items: products
                          .map((p) => DropdownMenuItem<int>(
                                value: p['id'] as int,
                                child: Text('${p['product_name']}', style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) {
                        final p = products.firstWhere((x) => x['id'] == v);
                        setState(() => rows[i].setProduct(p));
                      },
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: uomW,
                    child: DropdownButton<int>(
                      isExpanded: true,
                      isDense: true,
                      underline: const SizedBox(),
                      value: rows[i].unitId,
                      hint: const Text('UOM', style: TextStyle(fontSize: 10)),
                      items: units
                          .map((u) => DropdownMenuItem<int>(
                                value: u['id'] as int,
                                child: Text('${u['code']}', style: const TextStyle(fontSize: 10)),
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
                ),
                DataCell(
                  SizedBox(
                    width: hsnW,
                    child: Text(rows[i].hsn, style: _matrixCellStyle, overflow: TextOverflow.ellipsis),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: qtyW,
                    child: TextField(
                      key: ValueKey('q$i'),
                      keyboardType: TextInputType.number,
                      style: _matrixCellStyle,
                      decoration: _matrixInputDecoration,
                      onChanged: (v) => setState(() => rows[i].qty = double.tryParse(v) ?? 0),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: rateW,
                    child: TextField(
                      key: ValueKey('r$i'),
                      keyboardType: TextInputType.number,
                      style: _matrixCellStyle,
                      decoration: _matrixInputDecoration,
                      onChanged: (v) => setState(() => rows[i].rate = double.tryParse(v) ?? 0),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: taxW,
                    child: TextField(
                      controller: TextEditingController(text: '${rows[i].cgstPct}'),
                      keyboardType: TextInputType.number,
                      style: _matrixCellStyle,
                      decoration: _matrixInputDecoration,
                      onChanged: (v) => setState(() => rows[i].cgstPct = double.tryParse(v) ?? 0),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: taxW,
                    child: TextField(
                      controller: TextEditingController(text: '${rows[i].sgstPct}'),
                      keyboardType: TextInputType.number,
                      style: _matrixCellStyle,
                      decoration: _matrixInputDecoration,
                      onChanged: (v) => setState(() => rows[i].sgstPct = double.tryParse(v) ?? 0),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: taxW,
                    child: TextField(
                      controller: TextEditingController(text: '${rows[i].igstPct}'),
                      keyboardType: TextInputType.number,
                      style: _matrixCellStyle,
                      decoration: _matrixInputDecoration,
                      onChanged: (v) => setState(() => rows[i].igstPct = double.tryParse(v) ?? 0),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: totalWcol,
                    child: Text(
                      rows[i].total.toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: navy),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: actW,
                    child: IconButton(
                      onPressed: rows.length == 1 ? null : () => setState(() => rows.removeAt(i)),
                      icon: const Icon(Icons.delete_outline, color: red, size: 16),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ),
                ),
              ],
            );
          }),
        );

        if (needScroll) {
          return SingleChildScrollView(scrollDirection: Axis.horizontal, child: table);
        }
        return table;
      },
    );
  }
}

class _InvoiceRow{
  int? productId; int? unitId; String description='Item Description',uom='PCS',hsn='123456'; double qty=0,rate=0,cgstPct=9,sgstPct=9,igstPct=18;
  void setProduct(Map<String,dynamic> p){productId=p['id'];description=p['product_name']??'';unitId=p['unit_id'] as int?;uom=p['uom_code']??'PCS';hsn=p['hsn']??'';rate=(p['rate']??0).toDouble();}
  double get taxable=>qty*rate;
  double get cgst=>taxable*cgstPct/100;
  double get sgst=>taxable*sgstPct/100;
  double get igst=>taxable*igstPct/100;
  double get total=>taxable+cgst+sgst+igst;
}

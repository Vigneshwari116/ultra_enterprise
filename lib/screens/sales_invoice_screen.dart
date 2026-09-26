import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/ultra_config.dart';
import '../services/ultra_repository.dart';
import '../widgets/compact_date_picker.dart';
import '../widgets/enterprise_form_fields.dart';
import '../widgets/enterprise_widgets.dart';
import '../widgets/invoice.dart';
import '../widgets/sales_report.dart';
import '../widgets/transaction_line_math.dart';

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
  final repo = UltraRepository.instance;
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
    customers = await repo.customers();
    products = await repo.products();
    units = await repo.units();
    final count = await repo.nextSalesVoucherNo();
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
    products = await repo.products();
    units = await repo.units();
    if (mounted) setState(() {});
  }

  void fillCustomer(Map<String,dynamic> c){customerAddress.text=c['address']??'';city.text=c['city']??'';pin.text=c['postal_pincode']??'';gstin.text=c['gstin']??'';bank.text=c['bank_name']??'';account.text=c['bank_account_no']??'';shipping.text=c['shipping_address']??'';}

  TransactionLineTotals _lineTotals(_InvoiceRow r) => TransactionLineTotals.compute(
        qty: r.qty,
        rate: r.rate,
        cgstPct: r.cgstPct,
        sgstPct: r.sgstPct,
        igstPct: r.igstPct,
        stateZone: zone,
      );

  void _applyZoneToRows() {
    final inter = isInterStateZone(zone);
    for (final r in rows) {
      applyZoneGstFromPercents(
        interState: inter,
        cgstPct: r.cgstPct,
        sgstPct: r.sgstPct,
        igstPct: r.igstPct,
        apply: (c, s, i) {
          r.cgstPct = c;
          r.sgstPct = s;
          r.igstPct = i;
        },
      );
    }
  }

  double get taxable => rows.fold(0, (s, r) => s + _lineTotals(r).taxable);
  double get cgst => rows.fold(0, (s, r) => s + _lineTotals(r).cgst);
  double get sgst => rows.fold(0, (s, r) => s + _lineTotals(r).sgst);
  double get igst => rows.fold(0, (s, r) => s + _lineTotals(r).igst);
  double get total => taxable + cgst + sgst + igst;

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
    final uuid = repo.newUuid();
    final items = rows
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
            'taxable': t.taxable,
            'cgst': t.cgst,
            'sgst': t.sgst,
            'igst': t.igst,
            'total': t.total,
          };
          },
        )
        .toList();
    try {
    final invoiceId = await repo.createSalesInvoice({
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
      'items': items,
    });
    return invoiceId;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server save failed: $e')),
        );
      }
      return null;
    }
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
        SnackBar(
          content: Text(
            UltraConfig.persistLocally
                ? 'SALES INVOICE SAVED LOCALLY — PENDING SYNC'
                : 'SALES INVOICE SAVED TO SERVER',
          ),
        ),
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
                final stacked = constraints.maxWidth < formTwoColumnMinWidth;
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
                      enterpriseInsetDropdown<int>(
                        label: 'SELECT CUSTOMER (COMMERCIAL INVOICING) *',
                        value: customerId,
                        items: customers
                            .map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text('${c['customer_name']}')))
                            .toList(),
                        onChanged: (v) {
                          final c = customers.firstWhere((x) => x['id'] == v);
                          setState(() {
                            customerId = v;
                            fillCustomer(c);
                          });
                        },
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
              child: enterpriseMatrixScroller(table: _productMatrixTable()),
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
            enterpriseValueWordsFooter(
              valueInWords: payableAmountInWords(netPayable),
              chargeController: fwdCharge,
              onChargeChanged: (_) => setState(() {}),
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

  Widget _outline(String label, {TextEditingController? controller, bool readOnly = false, bool filled = false, Widget? prefixIcon, VoidCallback? onTap}) {
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
      label: 'SELECT STATE ZONE APPLICABILITY *',
      value: zone.isEmpty ? null : zone,
      borderColor: mandatory ? red : null,
      hint: const Text('Choose Option (Mandatory Entry Row)', style: TextStyle(color: red, fontSize: 12.5, fontWeight: FontWeight.w600)),
      items: const [
        DropdownMenuItem(value: 'Intra State', child: Text('Intra State')),
        DropdownMenuItem(value: 'Inter State', child: Text('Inter State')),
      ],
      onChanged: (v) => setState(() {
        zone = v ?? '';
        _applyZoneToRows();
      }),
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
  String _amountInWords(double v) => payableAmountInWords(v);

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

  Table _productMatrixTable() {
    return Table(
      columnWidths: enterpriseProductMatrixColumns,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(color: navy2),
          children: [
            _matrixHeadCell('SL'),
            _matrixHeadCell('MATERIAL PRODUCT DESCRIPTION'),
            _matrixHeadCell('UOM'),
            _matrixHeadCell('HSN'),
            _matrixHeadCell('QTY'),
            _matrixHeadCell('RATE'),
            _matrixHeadCell('CGST%'),
            _matrixHeadCell('SGST%'),
            _matrixHeadCell('IGST%'),
            _matrixHeadCell('COMPOUND TOTAL'),
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
                child: Text('${i + 1}', style: _matrixCellStyle),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: DropdownButton<int>(
                  isExpanded: true,
                  isDense: true,
                  hint: const Text('Item Description', style: TextStyle(fontSize: 9, color: Color(0xFF9AA5B4))),
                  value: catalogIdInList(rows[i].productId, products),
                  items: products
                      .map((p) {
                        final id = coerceCatalogId(p['id']);
                        if (id == null) return null;
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text('${p['product_name']}', style: const TextStyle(fontSize: 9), overflow: TextOverflow.ellipsis),
                        );
                      })
                      .whereType<DropdownMenuItem<int>>()
                      .toList(),
                  onChanged: (v) {
                    final p = products.firstWhere((x) => coerceCatalogId(x['id']) == v);
                    setState(() => rows[i].setProduct(p, stateZone: zone));
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
                          child: Text('${u['code']}', style: const TextStyle(fontSize: 9)),
                        );
                      })
                      .whereType<DropdownMenuItem<int>>()
                      .toList(),
                  onChanged: (v) {
                    final u = units.firstWhere((x) => coerceCatalogId(x['id']) == v);
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
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Text(
                  _lineTotals(rows[i]).total.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 9.5, color: navy),
                ),
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
}

class _InvoiceRow {
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

  void setProduct(Map<String, dynamic> p, {required String stateZone}) {
    productId = coerceCatalogId(p['id']);
    description = '${p['product_name'] ?? ''}';
    unitId = catalogUnitId(p);
    uom = catalogUomCode(p);
    hsn = catalogProductHsn(p);
    rate = catalogSalesRate(p);
    final productGst = catalogTotalGstPercent(p);
    if (productGst != null && productGst > 0) {
      applyZoneGstSplit(
        interState: isInterStateZone(stateZone),
        totalGstPercent: productGst,
        apply: (c, s, i) {
          cgstPct = c;
          sgstPct = s;
          igstPct = i;
        },
      );
    } else if (stateZone.trim().isNotEmpty) {
      applyZoneGstFromPercents(
        interState: isInterStateZone(stateZone),
        cgstPct: cgstPct,
        sgstPct: sgstPct,
        igstPct: igstPct,
        apply: (c, s, i) {
          cgstPct = c;
          sgstPct = s;
          igstPct = i;
        },
      );
    }
  }
}

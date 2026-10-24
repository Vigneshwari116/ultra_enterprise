import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/ultra_config.dart';
import '../services/ultra_repository.dart';
import '../widgets/compact_date_picker.dart';
import '../widgets/enterprise_form_fields.dart';
import '../widgets/enterprise_widgets.dart';
import '../widgets/invoice.dart';
import '../widgets/sales_report.dart';
import '../widgets/ultra_print_helpers.dart';
import '../utils/api_errors.dart';
import '../utils/party_directory.dart';
import '../widgets/transaction_line_math.dart';

/// Used by [AppShell] to refresh UOM/product lists after Unit Master saves.
final salesInvoiceCatalogKey = GlobalKey<SalesInvoiceCatalogHostState>();

enum SalesBillTypeChoice { normal, labour }

abstract class SalesInvoiceCatalogHostState extends State<SalesInvoiceScreen> {
  Future<void> refreshCatalog();
  Future<void> openExistingInvoice(int invoiceId);
}

class SalesInvoiceScreen extends StatefulWidget {
  const SalesInvoiceScreen({super.key});
  @override
  SalesInvoiceCatalogHostState createState() => _SalesInvoiceScreenState();
}

class _SalesInvoiceScreenState extends SalesInvoiceCatalogHostState {
  final repo = UltraRepository.instance;
  final po = TextEditingController(),
      challan = TextEditingController(),
      packages = TextEditingController(text: '0'),
      vehicle = TextEditingController(),
      due = TextEditingController(text: '0'),
      eway = TextEditingController();
  final customerAddress = TextEditingController(),
      city = TextEditingController(),
      pin = TextEditingController(),
      gstin = TextEditingController(),
      bank = TextEditingController(),
      account = TextEditingController(),
      shipping = TextEditingController();
  final fwdCharge = TextEditingController(text: '0');
  final selDcNo = TextEditingController();
  SalesBillTypeChoice billType = SalesBillTypeChoice.normal;
  bool _billTypeChosen = false;
  int? _editingInvoiceId;

  // Internal dates are kept as ISO (yyyy-MM-dd); displayed as dd-MM-yyyy like the reference.
  String date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String poDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String challanDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String selDcDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  // Empty until the user picks one — mirrors the reference's mandatory red "Choose Option" state.
  String zone = '';
  String voucherNo = '';
  int? nextVoucherNo;

  List<Map<String, dynamic>> customers = [];
  bool customersLoading = false;
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> units = [];
  int? customerId;
  final rows = [_InvoiceRow()];

  @override
  void initState() {
    super.initState();
    load().then((_) {
      if (mounted && _editingInvoiceId == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _promptBillType());
      }
    });
  }

  @override
  Future<void> openExistingInvoice(int invoiceId) async {
    _editingInvoiceId = invoiceId;
    _billTypeChosen = true;
    try {
      final bundle = await repo.salesInvoicePrintBundle(invoiceId);
      if (bundle == null) return;
      final inv = bundle['invoice'] as Map<String, dynamic>;
      final rawItems = bundle['items'] as List<Map<String, dynamic>>;
      final type = '${inv['bill_type'] ?? 'NORMAL'}'.toUpperCase();
      billType = type == 'LABOUR'
          ? SalesBillTypeChoice.labour
          : SalesBillTypeChoice.normal;
      date = '${inv['transaction_date'] ?? date}';
      po.text = '${inv['po_no'] ?? ''}';
      poDate = '${inv['po_date'] ?? poDate}';
      challan.text = '${inv['challan_no'] ?? inv['challan_dc_no'] ?? ''}';
      challanDate =
          '${inv['challan_date'] ?? inv['challan_dc_date'] ?? challanDate}';
      selDcNo.text = '${inv['sel_dc_no'] ?? ''}';
      selDcDate = '${inv['sel_dc_date'] ?? selDcDate}';
      packages.text = '${inv['total_packages'] ?? 0}';
      vehicle.text = '${inv['vehicle_dispatch_mode'] ?? ''}';
      due.text = '${inv['due_days'] ?? 0}';
      eway.text = '${inv['eway_bill_no'] ?? ''}';
      fwdCharge.text = '${inv['fwd_charge'] ?? 0}';
      zone = '${inv['state_zone'] ?? zone}';
      customerId = coerceCatalogId(inv['customer_id']);
      customerAddress.text = '${inv['customer_address'] ?? ''}';
      city.text = '${inv['customer_city'] ?? ''}';
      pin.text = '${inv['customer_pincode'] ?? ''}';
      gstin.text = '${inv['customer_gstin'] ?? ''}';
      shipping.text = '${inv['shipping_address'] ?? ''}';
      for (final r in rows) {
        r.dispose();
      }
      rows.clear();
      for (final it in rawItems) {
        final row = _InvoiceRow();
        row.description = '${it['description'] ?? ''}';
        row.hsn = '${it['hsn'] ?? it['hsn_code'] ?? ''}';
        row.qty = (it['quantity'] as num?)?.toDouble() ?? 0;
        row.rate = (it['rate'] as num?)?.toDouble() ?? 0;
        row.qtyController.text = row.qty == 0 ? '' : row.qty.toStringAsFixed(2);
        row.rateController.text =
            row.rate == 0 ? '' : row.rate.toStringAsFixed(2);
        row.cgstPct = (it['cgst_percent'] as num?)?.toDouble() ?? 9;
        row.sgstPct = (it['sgst_percent'] as num?)?.toDouble() ?? 9;
        row.igstPct = (it['igst_percent'] as num?)?.toDouble() ?? 0;
        rows.add(row);
      }
      if (rows.isEmpty) rows.add(_InvoiceRow());
      voucherNo = '${inv['invoice_no'] ?? voucherNo}';
    } catch (e) {
      if (mounted) showReadableErrorSnackBar(context, e);
    }
    if (mounted) setState(() {});
  }

  Future<void> _promptBillType() async {
    if (_billTypeChosen || !mounted) return;
    final choice = await showDialog<SalesBillTypeChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Select bill type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Normal Bill'),
              onTap: () => Navigator.pop(ctx, SalesBillTypeChoice.normal),
            ),
            ListTile(
              title: const Text('Labour Bill'),
              onTap: () => Navigator.pop(ctx, SalesBillTypeChoice.labour),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == null) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      billType = choice;
      _billTypeChosen = true;
      if (billType == SalesBillTypeChoice.labour) {
        for (final r in rows) {
          if (r.hsn.isEmpty) r.hsn = '9988';
        }
      }
    });
  }

  Future<void> load() async {
    try {
      customersLoading = true;
      if (mounted) setState(() {});
      customers = await loadCustomersDirectory(repo, snackbarContext: context);
      customersLoading = false;
      products = await repo.products();
      units = await repo.units();
      if (UltraConfig.persistLocally) {
        final count = await repo.nextSalesVoucherNo();
        voucherNo = '$count';
        nextVoucherNo = null;
      } else {
        nextVoucherNo = await repo.peekNextVoucherNumber('SAL', voucherDate: date);
      }
      _reconcileCustomerSelection();
      if (customers.isNotEmpty && customerId == null) {
        customerId = coerceCatalogId(customers.first['id']);
        fillCustomer(customers.first);
      }
    } catch (e) {
      if (mounted) showReadableErrorSnackBar(context, e);
    }
    if (mounted) setState(() {});
  }

  String _salesVoucherNoLabel() {
    if (UltraConfig.persistLocally) return voucherNo;
    if (nextVoucherNo != null) return 'Next: $nextVoucherNo';
    return 'Auto on save';
  }

  void _reconcileCustomerSelection() {
    if (customerId == null) return;
    if (!customers.any((c) => coerceCatalogId(c['id']) == customerId)) {
      customerId = null;
    }
  }

  /// Refreshes remote master lists when this screen becomes active again.
  @override
  Future<void> refreshCatalog() async {
    try {
      customersLoading = true;
      if (mounted) setState(() {});
      customers = await loadCustomersDirectory(repo, snackbarContext: context);
      customersLoading = false;
      products = await repo.products();
      units = await repo.units();
      _reconcileCustomerSelection();
    } catch (e) {
      if (mounted) showReadableErrorSnackBar(context, e);
    }
    if (mounted) setState(() {});
  }

  void fillCustomer(Map<String, dynamic> c) {
    customerAddress.text = c['address'] ?? '';
    city.text = c['city'] ?? '';
    pin.text = c['postal_pincode'] ?? '';
    gstin.text = c['gstin'] ?? '';
    bank.text = c['bank_name'] ?? '';
    account.text = c['bank_account_no'] ?? '';
    shipping.text = c['shipping_address'] ?? '';
  }

  TransactionLineTotals _lineTotals(_InvoiceRow r) =>
      TransactionLineTotals.compute(
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
          r.cgstController.text = _siMatrixNum(c);
          r.sgstController.text = _siMatrixNum(s);
          r.igstController.text = _siMatrixNum(i);
        },
      );
    }
  }

  double get taxable => rows.fold(0, (s, r) => s + _lineTotals(r).taxable);
  double get cgst => rows.fold(0, (s, r) => s + _lineTotals(r).cgst);
  double get sgst => rows.fold(0, (s, r) => s + _lineTotals(r).sgst);
  double get igst => rows.fold(0, (s, r) => s + _lineTotals(r).igst);
  double get total => taxable + cgst + sgst + igst;

  @override
  void dispose() {
    for (final c in [
      po,
      challan,
      packages,
      vehicle,
      due,
      eway,
      customerAddress,
      city,
      pin,
      gstin,
      bank,
      account,
      shipping,
      fwdCharge,
      selDcNo,
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
    if (picked != null) {
      onPicked(formatIsoDate(picked));
    }
  }

  double get fwd => double.tryParse(fwdCharge.text.trim()) ?? 0;

  double get netPayable => total + fwd;

  Future<int?> _persistInvoice() async {
    if (zone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please select the State Zone Applicability before saving.')),
      );
      return null;
    }
    if (customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a customer before saving.')),
      );
      return null;
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
      final invoiceId = await repo.createSalesInvoice({
        'uuid': uuid,
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
        'fwd_charge': fwd,
        'bill_type': billType == SalesBillTypeChoice.labour ? 'LABOUR' : 'NORMAL',
        'sel_dc_no': billType == SalesBillTypeChoice.labour ? selDcNo.text : null,
        'sel_dc_date': billType == SalesBillTypeChoice.labour ? selDcDate : null,
        'status': 'POSTED',
        'items': items,
      });
      return invoiceId;
    } catch (e) {
      if (mounted) {
        await showReadableErrorDialog(
          context,
          title: 'Could not save sales invoice',
          error: e,
        );
      }
      return null;
    }
  }

  void _resetForm() {
    for (final r in rows) {
      r.dispose();
    }
    setState(() {
      rows
        ..clear()
        ..add(_InvoiceRow());
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
    try {
      final data = await invoiceDataFromId(invoiceId);
      if (data == null) {
        throw Exception('Saved invoice could not be loaded for printing');
      }
      final billNo = ultraPlainDocumentNumber(data.invoiceNo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              UltraConfig.persistLocally
                  ? 'Sales invoice $billNo saved locally — pending sync'
                  : 'Sales invoice $billNo saved successfully',
            ),
          ),
        );
      }
      await printInvoiceDataDocument(context, data);
    } catch (e) {
      if (mounted) showReadableErrorSnackBar(context, e);
    }
    await load();
    _resetForm();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: enterpriseScrollColumn(children: [
        Container(
          width: double.infinity,
          color: const Color(0xFF19232C),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: enterpriseTerminalHeader(
            title: 'COMMERCIAL SALES TERMINAL',
            stats: [
              enterpriseStatMini(
                  'TOTAL PCS',
                  rows.fold<double>(0, (s, r) => s + r.qty).toStringAsFixed(0)),
              enterpriseStatMini('TAXABLE NET', taxable.toStringAsFixed(2)),
              enterpriseStatMini('COMPOUND GST', (cgst + sgst + igst).toStringAsFixed(2)),
            ],
            totalAmount: '₹${netPayable.toStringAsFixed(2)}',
            totalLabel: 'NET PAYABLE VALUE',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < formTwoColumnMinWidth;
                final section1 = enterprisePlainSection(
                  title: 'SECTION 1: TRANSACTION METADATA',
                  children: [
                    enterpriseFormPair(
                      enterpriseInsetFieldShell(
                        label: 'SALES VOUCHER NO (AUTO)',
                        filled: true,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _salesVoucherNoLabel(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: enterpriseInsetValueStyle.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                      enterpriseInsetDateField(
                        label: 'TRANSACTION DATE',
                        isoDate: date,
                        onTap: () =>
                            _pickDate(date, (v) => setState(() => date = v)),
                      ),
                    ),
                    enterpriseFormPair(
                      _outline('PO NO', controller: po, autofocus: true),
                      enterpriseInsetDateField(
                        label: 'PO DATE',
                        isoDate: poDate,
                        onTap: () => _pickDate(
                            poDate, (v) => setState(() => poDate = v)),
                      ),
                    ),
                    _zoneField(),
                    const SizedBox(height: 8),
                    enterpriseFormPair(
                      _outline('CHALLAN / DC NO', controller: challan),
                      enterpriseInsetDateField(
                        label: 'CHALLAN / DC DATE',
                        isoDate: challanDate,
                        onTap: () => _pickDate(challanDate,
                            (v) => setState(() => challanDate = v)),
                      ),
                    ),
                    enterpriseFormPair(
                      _outline('TOTAL NO OF PACKAGES', controller: packages),
                      _outline('VEHICLE NO / DISPATCH MODE',
                          controller: vehicle),
                    ),
                    enterpriseFormPair(
                      _outline('DUE DAYS', controller: due),
                      _outline('E-WAY BILL NO (EWB NO)', controller: eway),
                    ),
                    if (billType == SalesBillTypeChoice.labour) ...[
                      enterpriseFormPair(
                        _outline('SEL DC NO', controller: selDcNo),
                        enterpriseInsetDateField(
                          label: 'SEL DC DATE',
                          isoDate: selDcDate,
                          onTap: () => _pickDate(
                              selDcDate, (v) => setState(() => selDcDate = v)),
                        ),
                      ),
                    ],
                  ],
                );
                final section2 = enterprisePlainSection(
                  title: 'SECTION 2: ACCOUNT / PARTY CONFIGURATION',
                  children: [
                    enterpriseInsetDropdown<int>(
                      label: 'SELECT CUSTOMER (COMMERCIAL INVOICING) *',
                      value: customerId,
                      items: customers
                          .map((c) {
                            final id = coerceCatalogId(c['id']);
                            if (id == null) return null;
                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text(
                                  '${c['customer_name'] ?? c['name'] ?? ''}'),
                            );
                          })
                          .whereType<DropdownMenuItem<int>>()
                          .toList(),
                      onChanged: customersLoading
                          ? null
                          : (v) {
                        final c = customers
                            .firstWhere((x) => coerceCatalogId(x['id']) == v);
                        setState(() {
                          customerId = v;
                          fillCustomer(c);
                        });
                      },
                    ),
                    partyDirectoryStatus(
                      loading: customersLoading,
                      isCustomer: true,
                      itemCount: customers.length,
                    ),
                    const SizedBox(height: 14),
                    _outline('ADDRESS',
                        controller: customerAddress,
                        readOnly: true,
                        filled: true),
                    const SizedBox(height: 14),
                    enterpriseFormPair(
                      _outline('CITY',
                          controller: city, readOnly: true, filled: true),
                      _outline('POSTAL PINCODE',
                          controller: pin, readOnly: true, filled: true),
                    ),
                    enterpriseFormPair(
                      _outline('PARTY GSTIN NO',
                          controller: gstin, readOnly: true, filled: true),
                      _outline('BANK IDENTIFIER NAME',
                          controller: bank, readOnly: true, filled: true),
                    ),
                    enterpriseFormPair(
                      _outline('BANK ACCOUNT NO',
                          controller: account, readOnly: true, filled: true),
                      _outline('SHIPPING ADDRESS',
                          controller: shipping, readOnly: true, filled: true),
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
            const SizedBox(height: 14),
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
                onPressed: () => setState(() => rows.add(_InvoiceRow())),
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
              valueInWords: payableAmountInWords(netPayable),
              chargeController: fwdCharge,
              onChargeChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            Center(
              child: ElevatedButton.icon(
                onPressed: saveAndPrint,
                icon: const Icon(Icons.print_outlined, size: 17),
                label: const Text('SAVE & PRINT SALES VOUCHER',
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

  Widget _zoneField() {
    final mandatory = zone.isEmpty;
    return enterpriseInsetDropdown<String>(
      label: 'SELECT STATE ZONE APPLICABILITY *',
      value: zone.isEmpty ? null : zone,
      borderColor: mandatory ? red : null,
      hint: const Text('Choose Option (Mandatory Entry Row)',
          style: TextStyle(
              color: red, fontSize: 12.5, fontWeight: FontWeight.w600)),
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

  Table _productMatrixTable() {
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
            enterpriseMatrixHeadCell(
                billType == SalesBillTypeChoice.labour ? 'SAC' : 'HSN'),
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
                      style: enterpriseMatrixHintStyle),
                  value: catalogIdInList(rows[i].productId, products),
                  items: products
                      .map((p) {
                        final id = coerceCatalogId(p['id']);
                        if (id == null) return null;
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text('${p['product_name']}',
                              style: enterpriseMatrixCellStyle,
                              overflow: TextOverflow.ellipsis),
                        );
                      })
                      .whereType<DropdownMenuItem<int>>()
                      .toList(),
                  onChanged: (v) {
                    final p = products
                        .firstWhere((x) => coerceCatalogId(x['id']) == v);
                    setState(() => rows[i].setProduct(
                          p,
                          stateZone: zone,
                          labourBill: billType == SalesBillTypeChoice.labour,
                        ));
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
                  hint: const Text('UOM', style: enterpriseMatrixHintStyle),
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
                child: Text(rows[i].hsn,
                    style: enterpriseMatrixCellStyle, overflow: TextOverflow.ellipsis),
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
                  _lineTotals(rows[i]).total.toStringAsFixed(2),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13.5, color: navy),
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

String _siMatrixNum(double v, {bool blankZero = false}) {
  if (blankZero && v == 0) return '';
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
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

  late final TextEditingController qtyController;
  late final TextEditingController rateController;
  late final TextEditingController cgstController;
  late final TextEditingController sgstController;
  late final TextEditingController igstController;

  _InvoiceRow() {
    qtyController = TextEditingController();
    rateController = TextEditingController();
    cgstController = TextEditingController(text: _siMatrixNum(cgstPct));
    sgstController = TextEditingController(text: _siMatrixNum(sgstPct));
    igstController = TextEditingController(text: _siMatrixNum(igstPct));
  }

  void dispose() {
    qtyController.dispose();
    rateController.dispose();
    cgstController.dispose();
    sgstController.dispose();
    igstController.dispose();
  }

  void setProduct(
    Map<String, dynamic> p, {
    required String stateZone,
    bool labourBill = false,
  }) {
    productId = coerceCatalogId(p['id']);
    description = '${p['product_name'] ?? ''}';
    unitId = catalogUnitId(p);
    uom = catalogUomCode(p);
    final productHsn = catalogProductHsn(p);
    hsn = labourBill ? (productHsn.isEmpty ? '9988' : productHsn) : productHsn;
    rate = catalogSalesRate(p);
    rateController.text = rate == 0 ? '' : rate.toStringAsFixed(2);
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
    cgstController.text = _siMatrixNum(cgstPct);
    sgstController.text = _siMatrixNum(sgstPct);
    igstController.text = _siMatrixNum(igstPct);
  }
}

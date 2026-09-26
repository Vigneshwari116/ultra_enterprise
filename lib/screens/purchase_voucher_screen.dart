import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ultra_repository.dart';
import '../widgets/compact_date_picker.dart';
import '../widgets/enterprise_form_fields.dart';
import '../widgets/enterprise_widgets.dart';

class PurchaseVoucherScreen extends StatefulWidget {
  const PurchaseVoucherScreen({super.key});
  @override State<PurchaseVoucherScreen> createState()=>_PurchaseVoucherScreenState();
}
class _PurchaseVoucherScreenState extends State<PurchaseVoucherScreen>{
  final repo = UltraRepository.instance;
  final supplierInvoiceNo=TextEditingController(), remarks=TextEditingController();
  final supplierAddress=TextEditingController(), city=TextEditingController(), pin=TextEditingController(), gstin=TextEditingController(), bank=TextEditingController(), account=TextEditingController();

  String voucherDate=DateFormat('yyyy-MM-dd').format(DateTime.now());
  String supplierInvoiceDate=DateFormat('yyyy-MM-dd').format(DateTime.now());
  String voucherNo='';

  List<Map<String,dynamic>> suppliers=[]; List<Map<String,dynamic>> products=[]; List<Map<String,dynamic>> units=[]; List<Map<String,dynamic>> openOrders=[];
  int? supplierId; int? againstPoId;
  final rows=[_PvRow()];

  @override void initState(){super.initState();load();}

  Future<void> load()async{
    suppliers=await repo.suppliers();
    products=await repo.products();
    units=await repo.units();
    openOrders=await repo.openPurchaseOrders();
    voucherNo='${await repo.nextPurchaseVoucherNo()}';
    if(mounted)setState((){});
  }

  void fillSupplier(Map<String,dynamic> s){supplierAddress.text=s['address']??'';city.text=s['city']??'';pin.text=s['postal_pincode']??'';gstin.text=s['gstin']??'';bank.text=s['bank_name']??'';account.text=s['bank_account_no']??'';}

  Future<void> loadAgainstPo(int? poId)async{
    againstPoId=poId;
    if(poId==null)return;
    final po=openOrders.firstWhere((x)=>x['id']==poId);
    supplierId=po['supplier_id'] as int?;
    final s=suppliers.where((x)=>x['id']==supplierId);
    if(s.isNotEmpty)fillSupplier(s.first);
    final items=await repo.purchaseOrderItems(poId);
    if(items.isNotEmpty){
      rows..clear()..addAll(items.map((it)=>_PvRow()
        ..productId=it['product_id'] as int?
        ..description=it['description']??''
        ..uom=it['uom']??'PCS'
        ..hsn=it['hsn']??''
        ..qty=(it['quantity']??0).toDouble()
        ..rate=(it['rate']??0).toDouble()
        ..cgstPct=(it['cgst_percent']??9).toDouble()
        ..sgstPct=(it['sgst_percent']??9).toDouble()
        ..igstPct=(it['igst_percent']??0).toDouble()));
    }
    if(mounted)setState((){});
  }

  double get taxable=>rows.fold(0,(s,r)=>s+r.taxable);
  double get cgst=>rows.fold(0,(s,r)=>s+r.cgst);
  double get sgst=>rows.fold(0,(s,r)=>s+r.sgst);
  double get igst=>rows.fold(0,(s,r)=>s+r.igst);
  double get total=>taxable+cgst+sgst+igst;

  @override void dispose(){for(final c in [supplierInvoiceNo,remarks,supplierAddress,city,pin,gstin,bank,account])c.dispose();super.dispose();}

  Future<void> _pickDate(String currentIso, ValueChanged<String> onPicked) async {
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

  String _display(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd-MM-yyyy').format(d);
  }

  Future<void> save()async{
    if (supplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a supplier before saving.')));
      return;
    }
    final uuid=repo.newUuid();
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
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('PURCHASE VOUCHER POSTED — STOCK UPDATED')));
    await load();
    setState(() {
      rows..clear()..add(_PvRow());
      supplierInvoiceNo.clear(); remarks.clear(); againstPoId=null;
    });
  }

  @override Widget build(BuildContext context){
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Container(
          width: double.infinity,
          color: const Color(0xFF19232C),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('COMMERCIAL PURCHASE TERMINAL',
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
                  Text('₹${total.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFFF4D53A), fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  const Text('NET PAYABLE VALUE',
                      style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: .4)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _plainSection(
                    title: 'SECTION 1: TRANSACTION METADATA',
                    children: [
                      _pair(
                        _outline('VOUCHER NO', controller: TextEditingController(text: voucherNo), readOnly: true, filled: true),
                        _outline('VOUCHER DATE', controller: TextEditingController(text: _display(voucherDate)), readOnly: true,
                            prefixIcon: const Icon(Icons.calendar_today_outlined, size: 15),
                            onTap: () => _pickDate(voucherDate, (v) => setState(() => voucherDate = v))),
                      ),
                      _pair(
                        _outline('SUPPLIER INVOICE NO', controller: supplierInvoiceNo),
                        _outline('SUPPLIER INVOICE DATE', controller: TextEditingController(text: _display(supplierInvoiceDate)), readOnly: true,
                            prefixIcon: const Icon(Icons.calendar_today_outlined, size: 15),
                            onTap: () => _pickDate(supplierInvoiceDate, (v) => setState(() => supplierInvoiceDate = v))),
                      ),
                      enterpriseInsetDropdown<int?>(
                        label: 'AGAINST PURCHASE ORDER (OPTIONAL)',
                        value: againstPoId,
                        hint: const Text('— No linked PO —', style: TextStyle(fontSize: 12, color: Color(0xFF9AA5B4))),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('— No linked PO —')),
                          ...openOrders.map((o) => DropdownMenuItem<int?>(value: o['id'] as int, child: Text('PO-${o['po_no']}  •  ${o['party_name']}'))),
                        ],
                        onChanged: (v) => loadAgainstPo(v),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: enterpriseInsetTextField(label: 'REMARKS', controller: remarks, maxLines: 2),
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
                      ),
                      _pair(_outline('ADDRESS', controller: supplierAddress, filled: true), _outline('CITY', controller: city, filled: true)),
                      _pair(_outline('PINCODE', controller: pin, filled: true), _outline('GSTIN', controller: gstin, filled: true)),
                      _pair(_outline('BANK NAME', controller: bank, filled: true), _outline('ACCOUNT NO', controller: account, filled: true)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text('SECTION 3: QUANTITY MATRIX PRODUCT ENTRY', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: navy, letterSpacing: .3)),
            const SizedBox(height: 4),
            Container(height: 1, color: border),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                  headingRowColor: const WidgetStatePropertyAll(navy2),
                  columns: const [
                    DataColumn(label:Text('SL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5))),
                    DataColumn(label:Text('MATERIAL PRODUCT DESCRIPTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5))),
                    DataColumn(label:Text('UOM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5))),
                    DataColumn(label:Text('HSN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5))),
                    DataColumn(label:Text('QTY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5))),
                    DataColumn(label:Text('RATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5))),
                    DataColumn(label:Text('CGST%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5))),
                    DataColumn(label:Text('SGST%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5))),
                    DataColumn(label:Text('IGST%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5))),
                    DataColumn(label:Text('COMPOUND TOTAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5))),
                    DataColumn(label:Text('', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5))),
                  ],
                  rows:List.generate(rows.length,(i)=>DataRow(cells:[
                    DataCell(Text('${i+1}')),
                    DataCell(SizedBox(width:128,child:DropdownButton<int>(isExpanded:true,hint: const Text('Item Description', style: TextStyle(fontSize: 12, color: Color(0xFF9AA5B4))),value:rows[i].productId,items:products.map((p)=>DropdownMenuItem<int>(value:p['id'],child:Text('${p['product_name']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)))).toList(),onChanged:(v){final p=products.firstWhere((x)=>x['id']==v);setState(()=>rows[i].setProduct(p));}))),
                    DataCell(SizedBox(width:90,child:DropdownButton<int>(isExpanded:true,underline: const SizedBox(),value:rows[i].unitId,hint: const Text('UOM', style: TextStyle(fontSize: 11.5)),items:units.map((u)=>DropdownMenuItem<int>(value:u['id'] as int,child:Text('${u['code']}'))).toList(),onChanged:(v){final u=units.firstWhere((x)=>x['id']==v);setState((){rows[i].unitId=v;rows[i].uom='${u['code']}';});}))),
                    DataCell(Text(rows[i].hsn)),
                    DataCell(SizedBox(width:65,child:TextField(key:ValueKey('q$i'),controller:TextEditingController(text: rows[i].qty==0?'':'${rows[i].qty}'),keyboardType:TextInputType.number,decoration:const InputDecoration(isDense:true),onChanged:(v)=>setState(()=>rows[i].qty=double.tryParse(v)??0)))),
                    DataCell(SizedBox(width:75,child:TextField(key:ValueKey('r$i'),controller:TextEditingController(text: rows[i].rate==0?'':'${rows[i].rate}'),keyboardType:TextInputType.number,decoration:const InputDecoration(isDense:true),onChanged:(v)=>setState(()=>rows[i].rate=double.tryParse(v)??0)))),
                    DataCell(SizedBox(width:65,child:TextField(controller:TextEditingController(text:'${rows[i].cgstPct}'),keyboardType:TextInputType.number,decoration:const InputDecoration(isDense:true),onChanged:(v)=>setState(()=>rows[i].cgstPct=double.tryParse(v)??0)))),
                    DataCell(SizedBox(width:65,child:TextField(controller:TextEditingController(text:'${rows[i].sgstPct}'),keyboardType:TextInputType.number,decoration:const InputDecoration(isDense:true),onChanged:(v)=>setState(()=>rows[i].sgstPct=double.tryParse(v)??0)))),
                    DataCell(SizedBox(width:65,child:TextField(controller:TextEditingController(text:'${rows[i].igstPct}'),keyboardType:TextInputType.number,decoration:const InputDecoration(isDense:true),onChanged:(v)=>setState(()=>rows[i].igstPct=double.tryParse(v)??0)))),
                    DataCell(Text('₹${rows[i].total.toStringAsFixed(2)}',style:const TextStyle(fontWeight:FontWeight.w800))),
                    DataCell(IconButton(onPressed:rows.length==1?null:()=>setState(()=>rows.removeAt(i)),icon:const Icon(Icons.delete_outline,color:red,size:18))),
                  ]))
              ),
            ),
            const SizedBox(height:12),
            Center(
              child: OutlinedButton.icon(
                onPressed:()=>setState(()=>rows.add(_PvRow())),
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
            enterpriseValueWordsFooter(valueInWords: _amountInWords(total)),
            const SizedBox(height:8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFF4D53A))),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 15, color: Color(0xFF8A6D00)),
                SizedBox(width: 8),
                Expanded(child: Text('Posting this voucher will increase on-hand stock for every material line, and mark the linked Purchase Order (if any) as RECEIVED.',
                    style: TextStyle(color: Color(0xFF8A6D00), fontSize: 10.5, fontWeight: FontWeight.w700))),
              ]),
            ),
            const SizedBox(height:18),
            Center(
              child: ElevatedButton.icon(
                onPressed: save,
                icon: const Icon(Icons.inventory_2_outlined, size: 17),
                label: const Text('POST PURCHASE VOUCHER', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
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

  Widget _statMini(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
    ],
  );
  Widget _pair(Widget a, Widget b) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
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
      const SizedBox(height: 16),
      ...children,
    ],
  );
  String _amountInWords(double v) => v == 0 ? 'ZERO RUPEES ONLY' : '₹${v.toStringAsFixed(2)} ONLY';
}

class _PvRow{
  int? productId; int? unitId; String description='Item Description',uom='PCS',hsn='123456'; double qty=0,rate=0,cgstPct=9,sgstPct=9,igstPct=0;
  void setProduct(Map<String,dynamic> p){productId=p['id'];description=p['product_name']??'';unitId=p['unit_id'] as int?;uom=p['uom_code']??'PCS';hsn=p['hsn']??'';rate=(p['rate']??0).toDouble();}
  double get taxable=>qty*rate;
  double get cgst=>taxable*cgstPct/100;
  double get sgst=>taxable*sgstPct/100;
  double get igst=>taxable*igstPct/100;
  double get total=>taxable+cgst+sgst+igst;
}

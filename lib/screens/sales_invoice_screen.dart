import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../widgets/enterprise_widgets.dart';

class SalesInvoiceScreen extends StatefulWidget {
  const SalesInvoiceScreen({super.key});
  @override State<SalesInvoiceScreen> createState()=>_SalesInvoiceScreenState();
}
class _SalesInvoiceScreenState extends State<SalesInvoiceScreen>{
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

  Future<void> load()async{
    customers=await db.customers();
    products=await db.products();
    units=await db.units();
    final count = await db.nextSalesVoucherNo();
    voucherNo = '$count';
    if(customers.isNotEmpty){customerId=customers.first['id'];fillCustomer(customers.first);}
    if(mounted)setState((){});
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
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: navy)),
        child: child!,
      ),
    );
    if (picked != null) {
      onPicked(DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  String _display(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd-MM-yyyy').format(d);
  }

  Future<void> save()async{
    if (zone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select the State Zone Applicability before saving.')));
      return;
    }
    final uuid=db.newUuid();
    final invoiceId=await db.db.insert('sales_invoices',{
      'uuid':uuid,'invoice_no':int.tryParse(voucherNo),'transaction_date':date,'po_no':po.text,'po_date':poDate,
      'state_zone':zone,'challan_no':challan.text,'challan_date':challanDate,
      'total_packages':int.tryParse(packages.text)??0,'vehicle_dispatch_mode':vehicle.text,'due_days':int.tryParse(due.text)??0,'eway_bill_no':eway.text,
      'customer_id':customerId,'taxable_total':taxable,'cgst_total':cgst,'sgst_total':sgst,'igst_total':igst,'grand_total':total,'status':'PENDING_SYNC'
    });
    for(final r in rows){
      await db.db.insert('sales_invoice_items',{'invoice_id':invoiceId,'product_id':r.productId,'description':r.description,'uom':r.uom,'hsn':r.hsn,'quantity':r.qty,'rate':r.rate,'cgst_percent':r.cgstPct,'sgst_percent':r.sgstPct,'igst_percent':r.igstPct,'taxable':r.taxable,'cgst':r.cgst,'sgst':r.sgst,'igst':r.igst,'total':r.total});
    }
    await db.insertQueue({'entity_type':'SALES_INVOICE','entity_id':invoiceId,'payload':jsonEncode({'uuid':uuid,'customer_id':customerId,'transaction_date':date}),'status':'PENDING','created_at':DateTime.now().toIso8601String()});
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('SALES INVOICE SAVED LOCALLY — PENDING SYNC')));
    await load();
    setState(() {
      rows..clear()..add(_InvoiceRow());
      po.clear(); challan.clear(); packages.text='0'; vehicle.clear(); due.text='0'; eway.clear();
      zone='';
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
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _plainSection(
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text('SECTION 3: QUANTITY MATRIX PRODUCT ENTRY',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: navy, letterSpacing: .3)),
            const SizedBox(height: 4),
            Container(height: 1, color: border),
            const SizedBox(height: 14),
            Container(
                decoration:BoxDecoration(color:Colors.white,border:Border.all(color:border),borderRadius:BorderRadius.circular(4)),
                child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
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
                      DataCell(SizedBox(width:190,child:DropdownButton<int>(isExpanded:true,hint: const Text('Item Description', style: TextStyle(fontSize: 12, color: Color(0xFF9AA5B4))),value:rows[i].productId,items:products.map((p)=>DropdownMenuItem<int>(value:p['id'],child:Text('${p['product_name']}'))).toList(),onChanged:(v){final p=products.firstWhere((x)=>x['id']==v);setState(()=>rows[i].setProduct(p));}))),
                      DataCell(SizedBox(width:90,child:DropdownButton<int>(isExpanded:true,underline: const SizedBox(),value:rows[i].unitId,hint: const Text('UOM', style: TextStyle(fontSize: 11.5)),items:units.map((u)=>DropdownMenuItem<int>(value:u['id'] as int,child:Text('${u['code']}'))).toList(),onChanged:(v){final u=units.firstWhere((x)=>x['id']==v);setState((){rows[i].unitId=v;rows[i].uom='${u['code']}';});}))),
                      DataCell(Text(rows[i].hsn)),
                      DataCell(SizedBox(width:65,child:TextField(key:ValueKey('q$i'),keyboardType:TextInputType.number,decoration:const InputDecoration(isDense:true),onChanged:(v)=>setState(()=>rows[i].qty=double.tryParse(v)??0)))),
                      DataCell(SizedBox(width:75,child:TextField(key:ValueKey('r$i'),keyboardType:TextInputType.number,decoration:const InputDecoration(isDense:true),onChanged:(v)=>setState(()=>rows[i].rate=double.tryParse(v)??0)))),
                      DataCell(SizedBox(width:65,child:TextField(controller:TextEditingController(text:'${rows[i].cgstPct}'),keyboardType:TextInputType.number,decoration:const InputDecoration(isDense:true),onChanged:(v)=>setState(()=>rows[i].cgstPct=double.tryParse(v)??0)))),
                      DataCell(SizedBox(width:65,child:TextField(controller:TextEditingController(text:'${rows[i].sgstPct}'),keyboardType:TextInputType.number,decoration:const InputDecoration(isDense:true),onChanged:(v)=>setState(()=>rows[i].sgstPct=double.tryParse(v)??0)))),
                      DataCell(SizedBox(width:65,child:TextField(controller:TextEditingController(text:'${rows[i].igstPct}'),keyboardType:TextInputType.number,decoration:const InputDecoration(isDense:true),onChanged:(v)=>setState(()=>rows[i].igstPct=double.tryParse(v)??0)))),
                      DataCell(Text('₹${rows[i].total.toStringAsFixed(2)}',style:const TextStyle(fontWeight:FontWeight.w800))),
                      DataCell(IconButton(onPressed:rows.length==1?null:()=>setState(()=>rows.removeAt(i)),icon:const Icon(Icons.delete_outline,color:red,size:18))),
                    ]))
                ))
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
                    child: Text('VALUE IN WORDS: ${_amountInWords(total)}',
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
                onPressed: save,
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: navy),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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

class _InvoiceRow{
  int? productId; int? unitId; String description='Item Description',uom='PCS',hsn='123456'; double qty=0,rate=0,cgstPct=9,sgstPct=9,igstPct=18;
  void setProduct(Map<String,dynamic> p){productId=p['id'];description=p['product_name']??'';unitId=p['unit_id'] as int?;uom=p['uom_code']??'PCS';hsn=p['hsn']??'';rate=(p['rate']??0).toDouble();}
  double get taxable=>qty*rate;
  double get cgst=>taxable*cgstPct/100;
  double get sgst=>taxable*sgstPct/100;
  double get igst=>taxable*igstPct/100;
  double get total=>taxable+cgst+sgst+igst;
}

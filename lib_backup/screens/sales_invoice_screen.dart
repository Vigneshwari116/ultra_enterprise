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
  String date=DateFormat('yyyy-MM-dd').format(DateTime.now());
  String poDate='', challanDate='', zone='Intra State';
  List<Map<String,dynamic>> customers=[]; List<Map<String,dynamic>> products=[]; int? customerId;
  final rows=[_InvoiceRow()];
  @override void initState(){super.initState();load();}
  Future<void> load()async{customers=await db.customers();products=await db.products();if(customers.isNotEmpty){customerId=customers.first['id'];fillCustomer(customers.first);}if(mounted)setState((){});}
  void fillCustomer(Map<String,dynamic> c){customerAddress.text=c['address']??'';city.text=c['city']??'';pin.text=c['postal_pincode']??'';gstin.text=c['gstin']??'';bank.text=c['bank_name']??'';account.text=c['bank_account_no']??'';shipping.text=c['shipping_address']??'';}
  double get taxable=>rows.fold(0,(s,r)=>s+r.taxable);
  double get cgst=>rows.fold(0,(s,r)=>s+r.cgst);
  double get sgst=>rows.fold(0,(s,r)=>s+r.sgst);
  double get igst=>rows.fold(0,(s,r)=>s+r.igst);
  double get total=>taxable+cgst+sgst+igst;
  @override void dispose(){for(final c in [po,challan,packages,vehicle,due,eway,customerAddress,city,pin,gstin,bank,account,shipping])c.dispose();super.dispose();}
  Future<void> save()async{
    final uuid=db.newUuid();
    final invoiceId=await db.db.insert('sales_invoices',{
      'uuid':uuid,'invoice_no':null,'transaction_date':date,'po_no':po.text,'po_date':poDate,
      'state_zone':zone,'challan_no':challan.text,'challan_date':challanDate,
      'total_packages':int.tryParse(packages.text)??0,'vehicle_dispatch_mode':vehicle.text,'due_days':int.tryParse(due.text)??0,'eway_bill_no':eway.text,
      'customer_id':customerId,'taxable_total':taxable,'cgst_total':cgst,'sgst_total':sgst,'igst_total':igst,'grand_total':total,'status':'PENDING_SYNC'
    });
    for(final r in rows){
      await db.db.insert('sales_invoice_items',{'invoice_id':invoiceId,'product_id':r.productId,'description':r.description,'uom':r.uom,'hsn':r.hsn,'quantity':r.qty,'rate':r.rate,'cgst_percent':r.cgstPct,'sgst_percent':r.sgstPct,'igst_percent':r.igstPct,'taxable':r.taxable,'cgst':r.cgst,'sgst':r.sgst,'igst':r.igst,'total':r.total});
    }
    await db.insertQueue({'entity_type':'SALES_INVOICE','entity_id':invoiceId,'payload':jsonEncode({'uuid':uuid,'customer_id':customerId,'transaction_date':date}),'status':'PENDING','created_at':DateTime.now().toIso8601String()});
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('SALES INVOICE SAVED LOCALLY — PENDING SYNC')));
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
                        Field(label:'Sales Voucher No (Auto)',child:TextField(readOnly:true,decoration:InputDecoration(hintText:'AUTO'))),
                        Field(label:'Transaction Date',child:TextField(controller:TextEditingController(text:date),readOnly:true)),
                      ),
                      _pair(
                        Field(label:'PO NO',child:TextField(controller:po)),
                        Field(label:'PO Date',child:TextField(controller:TextEditingController(text:poDate),readOnly:true)),
                      ),
                      Field(label:'Select State Zone Applicability',requiredField:true,child:DropdownButtonFormField<String>(value:zone,items:const[DropdownMenuItem(value:'Intra State',child:Text('Intra State')),DropdownMenuItem(value:'Inter State',child:Text('Inter State'))],onChanged:(v)=>setState(()=>zone=v!))),
                      const SizedBox(height: 14),
                      _pair(
                        Field(label:'Challan / DC No',child:TextField(controller:challan)),
                        Field(label:'Challan / DC Date',child:TextField(controller:TextEditingController(text:challanDate),readOnly:true)),
                      ),
                      _pair(
                        Field(label:'Total No of Packages',child:TextField(controller:packages)),
                        Field(label:'Vehicle No / Dispatch Mode',child:TextField(controller:vehicle)),
                      ),
                      _pair(
                        Field(label:'Due Days',child:TextField(controller:due)),
                        Field(label:'E-Way Bill No',child:TextField(controller:eway)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _plainSection(
                    title: 'SECTION 2: ACCOUNT / PARTY CONFIGURATION',
                    children: [
                      Field(label:'SELECT CUSTOMER (COMMERCIAL INVOICING)',requiredField:true,child:DropdownButtonFormField<int>(value:customerId,items:customers.map((c)=>DropdownMenuItem<int>(value:c['id'],child:Text(c['customer_name']))).toList(),onChanged:(v){final c=customers.firstWhere((x)=>x['id']==v);setState(()=>customerId=v);fillCustomer(c);})),
                      const SizedBox(height: 14),
                      Field(label:'ADDRESS',child:TextField(controller:customerAddress)),
                      const SizedBox(height: 14),
                      _pair(
                        Field(label:'CITY',child:TextField(controller:city)),
                        Field(label:'POSTAL PINCODE',child:TextField(controller:pin)),
                      ),
                      _pair(
                        Field(label:'PARTY GSTIN NO',child:TextField(controller:gstin)),
                        Field(label:'BANK IDENTIFIER NAME',child:TextField(controller:bank)),
                      ),
                      _pair(
                        Field(label:'BANK ACCOUNT NO',child:TextField(controller:account)),
                        Field(label:'SHIPPING ADDRESS',child:TextField(controller:shipping)),
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
                  DataCell(SizedBox(width:190,child:DropdownButton<int>(isExpanded:true,value:rows[i].productId,items:products.map((p)=>DropdownMenuItem<int>(value:p['id'],child:Text('${p['product_name']}'))).toList(),onChanged:(v){final p=products.firstWhere((x)=>x['id']==v);setState(()=>rows[i].setProduct(p));}))),
                  DataCell(Text(rows[i].uom)),
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
  int? productId; String description='Item Description',uom='PCS',hsn='123456'; double qty=0,rate=0,cgstPct=9,sgstPct=9,igstPct=0;
  void setProduct(Map<String,dynamic> p){productId=p['id'];description=p['product_name']??'';uom=p['uom_code']??'PCS';hsn=p['hsn']??'';rate=(p['rate']??0).toDouble();}
  double get taxable=>qty*rate;
  double get cgst=>taxable*cgstPct/100;
  double get sgst=>taxable*sgstPct/100;
  double get igst=>taxable*igstPct/100;
  double get total=>taxable+cgst+sgst+igst;
}

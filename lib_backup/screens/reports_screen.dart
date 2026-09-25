import 'package:flutter/material.dart';
import '../widgets/enterprise_widgets.dart';

class ReportPage extends StatelessWidget {
  final String title;
  final String section;
  final List<String> columns;
  final List<List<String>> rows;
  const ReportPage({super.key,required this.title,required this.section,required this.columns,required this.rows});
  @override Widget build(BuildContext context)=>SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:navy)),
    const SizedBox(height:4),const Text('ENTERPRISE REPORTING MATRIX',style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:Color(0xFF748094))),
    const SizedBox(height:18),SectionHeader(number:section,title:'REPORT FILTERS'),const SizedBox(height:12),
    Row(children:[const Expanded(child:TextField(decoration:InputDecoration(labelText:'FROM DATE',hintText:'YYYY-MM-DD'))),const SizedBox(width:12),const Expanded(child:TextField(decoration:InputDecoration(labelText:'TO DATE',hintText:'YYYY-MM-DD'))),const SizedBox(width:12),PrimaryButton(label:'RUN REPORT',onPressed:()=>{})]),
    const SizedBox(height:18),SectionHeader(number:'02',title:'REPORT DATA'),const SizedBox(height:12),
    EnterpriseTable(columns:columns,rows:rows)
  ]));
}
class SalesReportsScreen extends StatelessWidget{const SalesReportsScreen({super.key});@override Widget build(BuildContext c)=>const ReportPage(title:'SALES REPORTS',section:'09',columns:['INVOICE NO','DATE','CUSTOMER','TAXABLE','GST','TOTAL','STATUS'],rows:[['1','23/09/2026','Test Customer','₹500.00','₹90.00','₹590.00','POSTED']]);}
class PurchaseReportsScreen extends StatelessWidget{const PurchaseReportsScreen({super.key});@override Widget build(BuildContext c)=>const ReportPage(title:'PURCHASE REPORTS',section:'12',columns:['VOUCHER','DATE','SUPPLIER','TAXABLE','GST','TOTAL','STATUS'],rows:[['-','-','-','₹0.00','₹0.00','₹0.00','-']]);}

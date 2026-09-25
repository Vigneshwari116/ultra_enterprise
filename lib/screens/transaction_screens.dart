import 'package:flutter/material.dart';
import '../widgets/enterprise_widgets.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});
  @override Widget build(BuildContext context)=>SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('TRANSACTIONS',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:navy)),
    const SizedBox(height:4),const Text('COMMERCIAL TRANSACTION REGISTER',style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:Color(0xFF748094))),
    const SizedBox(height:18),const SectionHeader(number:'13',title:'TRANSACTION MATRIX'),const SizedBox(height:12),
    const EnterpriseTable(columns:['DATE','TYPE','REFERENCE','PARTY','DEBIT','CREDIT','STATUS'],rows:[
      ['23/09/2026','SALES','INV-0001','Test Customer','₹590.00','₹0.00','POSTED'],
    ])
  ]));
}

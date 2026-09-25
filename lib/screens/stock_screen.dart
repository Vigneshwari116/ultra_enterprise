import 'package:flutter/material.dart';
import '../services/ultra_repository.dart';
import '../widgets/enterprise_widgets.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override State<StockScreen> createState()=>_StockScreenState();
}
class _StockScreenState extends State<StockScreen>{
  List<Map<String,dynamic>> rows=[];
  @override void initState(){super.initState();load();}
  Future<void> load()async{rows=await UltraRepository.instance.products();if(mounted)setState((){});}
  @override Widget build(BuildContext context)=>SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('STOCK CONTROL',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:navy)),
    const SizedBox(height:4),const Text('INVENTORY / STOCK POSITION',style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:Color(0xFF748094))),
    const SizedBox(height:18),const SectionHeader(number:'14',title:'STOCK MATRIX'),const SizedBox(height:12),
    EnterpriseTable(columns:const['CODE','MATERIAL','UOM','OPENING STOCK','CURRENT STOCK','REORDER LEVEL','STATUS'],rows:rows.map((r)=>['${r['product_code']}','${r['product_name']}','${r['uom_code']}','${r['opening_stock']}','${r['current_stock']}','${r['reorder_level']}','${r['status']}']).toList())
  ]));
}

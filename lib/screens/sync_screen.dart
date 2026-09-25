import 'package:flutter/material.dart';
import '../config/ultra_config.dart';
import '../database/app_database.dart';
import '../widgets/enterprise_widgets.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});
  @override State<SyncScreen> createState()=>_SyncScreenState();
}
class _SyncScreenState extends State<SyncScreen>{
  List<Map<String,dynamic>> rows=[];
  @override void initState(){super.initState();load();}
  Future<void> load() async {
    if (!UltraConfig.persistLocally) {
      rows = [];
    } else {
      rows = await AppDatabase.instance.queue();
    }
    if (mounted) setState(() {});
  }
  @override Widget build(BuildContext context)=>SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('SYNC QUEUE',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:navy)),
    const SizedBox(height:4),
    Text(
      UltraConfig.persistLocally ? 'OFFLINE-FIRST SYNCHRONIZATION CONTROL' : 'SERVER-PRIMARY MODE — DOCUMENTS POST DIRECTLY TO THE API',
      style: const TextStyle(fontSize:10, fontWeight: FontWeight.w700, color: Color(0xFF748094)),
    ),
    const SizedBox(height:18),const SectionHeader(number:'15',title:'PENDING SYNCHRONIZATION MATRIX'),const SizedBox(height:12),
    EnterpriseTable(columns:const['ID','ENTITY','ENTITY ID','STATUS','CREATED AT'],rows:rows.map((r)=>['${r['id']}','${r['entity_type']}','${r['entity_id']}','${r['status']}','${r['created_at']}']).toList()),
    const SizedBox(height:12),PrimaryButton(label:'REFRESH QUEUE',onPressed:load,icon:Icons.sync)
  ]));
}

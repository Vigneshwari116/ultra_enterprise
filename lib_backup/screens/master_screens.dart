import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../widgets/enterprise_widgets.dart';

class MasterPage extends StatefulWidget {
  final String title;
  final String section;
  final String tableTitle;
  final List<String> columns;
  final List<List<String>> rows;
  final VoidCallback? onAdd;
  const MasterPage({super.key, required this.title, required this.section, required this.tableTitle, required this.columns, required this.rows, this.onAdd});
  @override
  State<MasterPage> createState() => _MasterPageState();
}
class _MasterPageState extends State<MasterPage> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navy)),
        const SizedBox(height: 4),
        const Text('COMMERCIAL MASTER CONFIGURATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF748094))),
        const SizedBox(height: 18),
        SectionHeader(number: widget.section, title: widget.tableTitle),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 18), hintText: 'Search records...'))),
          const SizedBox(width: 10),
          PrimaryButton(label: 'ADD NEW', onPressed: widget.onAdd ?? () {}),
        ]),
        const SizedBox(height: 12),
        EnterpriseTable(columns: widget.columns, rows: widget.rows),
      ]),
    );
  }
}

class UnitMasterScreen extends StatefulWidget {
  const UnitMasterScreen({super.key});
  @override State<UnitMasterScreen> createState() => _UnitMasterScreenState();
}
class _UnitMasterScreenState extends State<UnitMasterScreen> {
  List<Map<String,dynamic>> data = [];
  @override void initState(){super.initState(); load();}
  Future<void> load() async { data = await AppDatabase.instance.units(); if(mounted)setState((){}); }
  Future<void> add() async {
    final c=TextEditingController(), n=TextEditingController();
    await showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('ADD UNIT'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:c,decoration:const InputDecoration(labelText:'CODE')),TextField(controller:n,decoration:const InputDecoration(labelText:'NAME'))]),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('CANCEL')),ElevatedButton(onPressed:()async{await AppDatabase.instance.insertUnit({'code':c.text,'name':n.text});if(context.mounted)Navigator.pop(context);await load();},child:const Text('SAVE'))]));
  }
  @override Widget build(BuildContext context)=>MasterPage(title:'UNIT MASTER',section:'01',tableTitle:'UNIT CONFIGURATION',columns:const['ID','CODE','NAME','STATUS'],rows:data.map((x)=>['${x['id']}','${x['code']}','${x['name']}','${x['status']}']).toList(),onAdd:add);
}

class LedgerMasterScreen extends StatefulWidget {
  const LedgerMasterScreen({super.key});
  @override
  State<LedgerMasterScreen> createState() => _LedgerMasterScreenState();
}

class _LedgerMasterScreenState extends State<LedgerMasterScreen> {
  final nameCtrl = TextEditingController();
  final crCtrl = TextEditingController();
  final drCtrl = TextEditingController();
  String? group;
  String? head;
  String? groupWise;
  final searchCtrl = TextEditingController();

  final List<Map<String, dynamic>> _ledgers = [
    {'name': 'food', 'group': 'SUNDRY DEBTOR', 'cr': 0.0, 'dr': 0.0, 'time': '17:39'},
    {'name': 'PROCESS VALVES & FITTINGS', 'group': 'PURCHASE', 'cr': 10000.0, 'dr': 0.0, 'time': '17:19'},
    {'name': 'SANDHAR HAN SHIN AUTO TECHNOLOGIE...', 'group': 'SALES', 'cr': 0.0, 'dr': 0.0, 'time': '17:04'},
    {'name': 'SUPRAJIT ENGINEERING LIMITED  UNIT-14', 'group': 'SALES', 'cr': 0.0, 'dr': 0.0, 'time': '16:31'},
    {'name': 'APS INDUSTRIES', 'group': 'PURCHASE', 'cr': 3715.0, 'dr': 0.0, 'time': '15:34'},
    {'name': 'UDDISHTAA ELECTRICALS AND HARDWARE...', 'group': 'PURCHASE', 'cr': 0.0, 'dr': 10000.0, 'time': '15:32'},
    {'name': 'SRI RAM ENTERPRISES', 'group': 'PURCHASE', 'cr': 0.0, 'dr': 0.0, 'time': '15:31'},
    {'name': 'MANAL INSULATION', 'group': 'PURCHASE', 'cr': 0.0, 'dr': 0.0, 'time': '15:30'},
    {'name': 'SHAKTHI ENGINEERING', 'group': 'PURCHASE', 'cr': 36920.0, 'dr': 0.0, 'time': '15:27'},
    {'name': 'SUPRAJIT ENGINEERING LIMITED  UNIT-9', 'group': 'SALES', 'cr': 0.0, 'dr': 0.0, 'time': '15:03'},
    {'name': 'SUPRAJIT ENGINEERING LIMITED  UNIT-2', 'group': 'SALES', 'cr': 0.0, 'dr': 0.0, 'time': '15:02'},
    {'name': 'SUPRAJIT ENGINEERING LIMITED  UNIT 8', 'group': 'SALES', 'cr': 0.0, 'dr': 0.0, 'time': '14:59'},
  ];

  void _reset() {
    nameCtrl.clear();
    crCtrl.clear();
    drCtrl.clear();
    setState(() {
      group = null;
      head = null;
      groupWise = null;
    });
  }

  void _save() {
    if (nameCtrl.text.trim().isEmpty) return;
    setState(() {
      _ledgers.insert(0, {
        'name': nameCtrl.text.trim(),
        'group': group ?? '-',
        'cr': double.tryParse(crCtrl.text) ?? 0.0,
        'dr': double.tryParse(drCtrl.text) ?? 0.0,
        'time': TimeOfDay.now().format(context),
      });
    });
    _reset();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = searchCtrl.text.trim().isEmpty
        ? _ledgers
        : _ledgers.where((l) => l['name'].toString().toLowerCase().contains(searchCtrl.text.trim().toLowerCase())).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LEDGER MASTER', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: navy)),
          const SizedBox(height: 3),
          const Text('FINANCIAL REPOSITORIES PARAMETERS REGISTRY',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF748094))),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 268,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('NEW ENTRY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: navy)),
                      const SizedBox(height: 8),
                      Container(height: 2, width: 40, color: teal),
                      const SizedBox(height: 14),
                      TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'NAME')),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: TextField(controller: crCtrl, decoration: const InputDecoration(hintText: 'CR AMT'))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: drCtrl, decoration: const InputDecoration(hintText: 'DR AMT'))),
                      ]),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: group,
                        decoration: const InputDecoration(hintText: 'GROUP'),
                        items: const ['SALES', 'PURCHASE', 'SUNDRY DEBTOR']
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) => setState(() => group = v),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: head,
                        decoration: const InputDecoration(hintText: 'HEAD'),
                        items: const ['CURRENT ASSET', 'CURRENT LIABILITY', 'INCOME', 'EXPENSE']
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) => setState(() => head = v),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: groupWise,
                        decoration: const InputDecoration(hintText: 'GROUP WISE'),
                        items: const ['YES', 'NO']
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) => setState(() => groupWise = v),
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _reset,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: const BorderSide(color: border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                            ),
                            child: const Text('RESET', style: TextStyle(color: navy, fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: navy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                            ),
                            child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: searchCtrl,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search, size: 18),
                              hintText: 'Search Ledger Accounts Registry...',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.calendar_today_outlined, size: 15),
                          label: const Text('PRINT RANGE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Expanded(child: _LedgerTable(rows: filtered)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _LedgerTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: border, width: 1.4))),
          child: const Row(children: [
            Expanded(flex: 4, child: Text('NAME', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: navy))),
            Expanded(flex: 2, child: Text('GROUP', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: navy))),
            Expanded(flex: 2, child: Text('CR (₹)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: navy))),
            Expanded(flex: 2, child: Text('DR (₹)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: navy))),
            Expanded(flex: 1, child: Text('TIME', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: navy))),
            SizedBox(width: 40, child: Text('ACT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: navy))),
          ]),
        ),
        for (final r in rows)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEDF0F5)))),
            child: Row(children: [
              Expanded(
                  flex: 4,
                  child: Text(r['name'], overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: navy))),
              Expanded(flex: 2, child: Text(r['group'], style: const TextStyle(fontSize: 11, color: Color(0xFF39485A)))),
              Expanded(
                  flex: 2,
                  child: Text((r['cr'] as double).toStringAsFixed(2),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: green))),
              Expanded(
                  flex: 2,
                  child: Text((r['dr'] as double).toStringAsFixed(2),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: red))),
              Expanded(flex: 1, child: Text(r['time'], style: const TextStyle(fontSize: 10.5, color: Color(0xFF748094)))),
              const SizedBox(width: 40, child: Icon(Icons.edit_outlined, size: 15, color: amber)),
            ]),
          ),
      ],
    );
  }
}

class CustomerMasterScreen extends StatefulWidget {
  const CustomerMasterScreen({super.key});
  @override State<CustomerMasterScreen> createState()=>_CustomerMasterScreenState();
}
class _CustomerMasterScreenState extends State<CustomerMasterScreen>{
  List<Map<String,dynamic>> data=[];
  int? selectedId;
  final searchCtrl = TextEditingController();

  final nameCtrl = TextEditingController();
  final mobileCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final pincodeCtrl = TextEditingController();
  final gstinCtrl = TextEditingController();
  final openCrCtrl = TextEditingController(text: '0');
  final openDrCtrl = TextEditingController(text: '0');
  final bankNameCtrl = TextEditingController();
  final bankAccCtrl = TextEditingController();
  final ifscCtrl = TextEditingController();
  final branchCtrl = TextEditingController();
  final shipMobileCtrl = TextEditingController();
  final shipAddressCtrl = TextEditingController();
  final shipCityCtrl = TextEditingController();
  final shipPincodeCtrl = TextEditingController();
  final shipGstinCtrl = TextEditingController();

  @override void initState(){super.initState();load();}
  Future<void> load() async { data = await AppDatabase.instance.customers(); if(mounted) setState((){}); }

  void _clearForm() {
    for (final c in [nameCtrl, mobileCtrl, emailCtrl, addressCtrl, cityCtrl, pincodeCtrl, gstinCtrl,
        bankNameCtrl, bankAccCtrl, ifscCtrl, branchCtrl, shipMobileCtrl, shipAddressCtrl,
        shipCityCtrl, shipPincodeCtrl, shipGstinCtrl]) {
      c.clear();
    }
    openCrCtrl.text = '0';
    openDrCtrl.text = '0';
    setState(() => selectedId = null);
  }

  Future<void> save() async {
    if (nameCtrl.text.trim().isEmpty) return;
    await AppDatabase.instance.insertCustomer({
      'customer_code': 'CUST-${DateTime.now().millisecondsSinceEpoch % 100000}',
      'customer_name': nameCtrl.text.trim(),
      'primary_mobile': mobileCtrl.text,
      'email': emailCtrl.text,
      'address': addressCtrl.text,
      'city': cityCtrl.text,
      'postal_pincode': pincodeCtrl.text,
      'gstin': gstinCtrl.text,
      'opening_balance_cr': double.tryParse(openCrCtrl.text) ?? 0,
      'opening_balance_dr': double.tryParse(openDrCtrl.text) ?? 0,
      'bank_name': bankNameCtrl.text,
      'bank_account_no': bankAccCtrl.text,
      'ifsc_code': ifscCtrl.text,
      'branch_address': branchCtrl.text,
      'shipping_contact_mobile': shipMobileCtrl.text,
      'shipping_address': shipAddressCtrl.text,
      'shipping_city': shipCityCtrl.text,
      'shipping_pincode': shipPincodeCtrl.text,
      'shipping_gstin': shipGstinCtrl.text,
    });
    _clearForm();
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = searchCtrl.text.trim().isEmpty
        ? data
        : data.where((c) => '${c['customer_name']}'.toLowerCase().contains(searchCtrl.text.trim().toLowerCase())).toList();
    final batch = 'CUST-${DateTime.now().toString().substring(0, 10).replaceAll('-', '').substring(2)}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: dark customer directory panel
        Container(
          width: 300,
          color: sidebarBg,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: const [
                Icon(Icons.grid_view_rounded, color: teal, size: 15),
                SizedBox(width: 8),
                Text('CUSTOMER DIRECTORY',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: .5)),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: searchCtrl,
                onChanged: (_) => setState((){}),
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: Icon(Icons.search, size: 17),
                  hintText: 'Search customer records...',
                  hintStyle: TextStyle(fontSize: 11.5),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    final selected = selectedId == c['id'];
                    return InkWell(
                      onTap: () => setState(() => selectedId = c['id']),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? sidebarActiveBg : Colors.white.withOpacity(.04),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${i + 1}. ${c['customer_name']}',
                                    style: TextStyle(
                                        color: selected ? navy : Colors.white,
                                        fontSize: 11.5, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 3),
                                Text('Mob: ${(c['primary_mobile'] ?? '').toString().isEmpty ? 'N/A' : c['primary_mobile']} | GST: ${(c['gstin'] ?? '').toString().isEmpty ? 'N/A' : c['gstin']}',
                                    style: TextStyle(
                                        color: selected ? navy.withOpacity(.7) : Colors.white60,
                                        fontSize: 9.5, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 16, color: selected ? navy : Colors.white38),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Right: form
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(width: 4, height: 20, color: navy),
                  const SizedBox(width: 10),
                  const Text('CUSTOMER MASTER SETUP',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: navy)),
                  const Spacer(),
                  Text('BATCH: $batch',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: teal)),
                  const SizedBox(width: 14),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.file_download_outlined, size: 15),
                    label: const Text('IMPORT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: teal,
                      side: const BorderSide(color: teal),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: save,
                    icon: const Icon(Icons.save_outlined, size: 15),
                    label: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                _FormSectionBar(title: '1. CLIENT REGISTRATION SCHEMA DETAILS'),
                const SizedBox(height: 12),
                _row3(
                  Field(label: 'CUSTOMER / COMPANY NAME', requiredField: true, child: TextField(controller: nameCtrl)),
                  Field(label: 'PRIMARY MOBILE NO', child: TextField(controller: mobileCtrl)),
                  Field(label: 'EMAIL ADDRESS', child: TextField(controller: emailCtrl)),
                ),
                const SizedBox(height: 12),
                _row3(
                  Field(label: 'REGISTERED BILLING ADDRESS', child: TextField(controller: addressCtrl)),
                  Field(label: 'CITY', child: TextField(controller: cityCtrl)),
                  Field(label: 'PIN CODE', child: TextField(controller: pincodeCtrl)),
                ),
                const SizedBox(height: 12),
                _row3(
                  Field(label: 'GSTIN COMPLIANCE NUMBER', child: TextField(controller: gstinCtrl)),
                  Field(label: 'OPENING BALANCE (CR)',
                      child: TextField(controller: openCrCtrl, style: const TextStyle(color: green, fontWeight: FontWeight.w800))),
                  Field(label: 'OPENING BALANCE (DR)',
                      child: TextField(controller: openDrCtrl, style: const TextStyle(color: red, fontWeight: FontWeight.w800))),
                ),
                const SizedBox(height: 20),
                _FormSectionBar(title: '2. CLIENT BANKING ACCOUNT CREDENTIALS'),
                const SizedBox(height: 12),
                _row3(
                  Field(label: 'BANK NAME', child: TextField(controller: bankNameCtrl)),
                  Field(label: 'BANK ACCOUNT NUMBER', child: TextField(controller: bankAccCtrl)),
                  Field(label: 'IFSC CODE', child: TextField(controller: ifscCtrl)),
                ),
                const SizedBox(height: 12),
                Field(label: 'BRANCH LOCATION & ADDRESS DETAILS', child: TextField(controller: branchCtrl)),
                const SizedBox(height: 20),
                _FormSectionBar(title: '3. CORE LOGISTICS & SHIPPING DESTINATIONS'),
                const SizedBox(height: 12),
                _row2(
                  Field(label: 'SHIPPING CONSIGNEE NAME', child: TextField()),
                  Field(label: 'SHIPPING CONTACT MOBILE', child: TextField(controller: shipMobileCtrl)),
                ),
                const SizedBox(height: 12),
                Field(label: 'CONSIGNMENT DELIVERY SHIPPING ADDRESS', child: TextField(controller: shipAddressCtrl)),
                const SizedBox(height: 12),
                _row3(
                  Field(label: 'SHIPPING DESTINATION CITY', child: TextField(controller: shipCityCtrl)),
                  Field(label: 'SHIPPING TERMINAL PINCODE', child: TextField(controller: shipPincodeCtrl)),
                  Field(label: 'SHIPPING LOCATION GSTIN', child: TextField(controller: shipGstinCtrl)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row3(Widget a, Widget b, Widget c) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: a), const SizedBox(width: 14), Expanded(child: b), const SizedBox(width: 14), Expanded(child: c),
      ]);
  Widget _row2(Widget a, Widget b) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: a), const SizedBox(width: 14), Expanded(child: b),
      ]);
}

class _FormSectionBar extends StatelessWidget {
  final String title;
  const _FormSectionBar({required this.title});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      color: pageBg,
      child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: navy, letterSpacing: .3)),
    );
  }
}

class ProductMasterScreen extends StatefulWidget {
  const ProductMasterScreen({super.key});
  @override State<ProductMasterScreen> createState()=>_ProductMasterScreenState();
}
class _ProductMasterScreenState extends State<ProductMasterScreen>{
  List<Map<String,dynamic>> data=[];
  @override void initState(){super.initState();load();}
  Future<void> load()async{data=await AppDatabase.instance.products();if(mounted)setState((){});}
  Future<void> add()async{
    final n=TextEditingController(), code=TextEditingController(), hsn=TextEditingController(), rate=TextEditingController(text:'0');
    await showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('ADD MATERIAL'),content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:code,decoration:const InputDecoration(labelText:'PRODUCT CODE')),TextField(controller:n,decoration:const InputDecoration(labelText:'PRODUCT NAME')),TextField(controller:hsn,decoration:const InputDecoration(labelText:'HSN')),TextField(controller:rate,decoration:const InputDecoration(labelText:'RATE'))])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('CANCEL')),ElevatedButton(onPressed:()async{await AppDatabase.instance.insertProduct({'product_code':code.text,'product_name':n.text,'unit_id':1,'hsn':hsn.text,'rate':double.tryParse(rate.text)??0,'opening_stock':0,'current_stock':0});if(context.mounted)Navigator.pop(context);await load();},child:const Text('SAVE'))]));
  }
  @override Widget build(BuildContext context)=>MasterPage(title:'PRODUCT / MATERIAL MASTER',section:'04',tableTitle:'MATERIAL PRODUCT CONFIGURATION',columns:const['CODE','PRODUCT','UOM','HSN','RATE','STOCK','STATUS'],rows:data.map((x)=>['${x['product_code']}','${x['product_name']}','${x['uom_code']}','${x['hsn']??''}','${x['rate']}','${x['current_stock']}','${x['status']}']).toList(),onAdd:add);
}

class DeliveryChallanScreen extends StatelessWidget {
  const DeliveryChallanScreen({super.key});
  @override Widget build(BuildContext context)=>const MasterPage(title:'DELIVERY CHALLAN',section:'05',tableTitle:'DELIVERY CHALLAN REGISTER',columns:['DC NO','DATE','CUSTOMER','PACKAGES','VEHICLE','STATUS'],rows:[['DC-0001','23/09/2026','Test Customer','0','-','DRAFT']]);
}
class QuotationScreen extends StatelessWidget {
  const QuotationScreen({super.key});
  @override Widget build(BuildContext context)=>const MasterPage(title:'QUOTATION',section:'06',tableTitle:'QUOTATION REGISTER',columns:['QUOTE NO','DATE','CUSTOMER','VALUE','STATUS'],rows:[['Q-0001','23/09/2026','Test Customer','₹0.00','DRAFT']]);
}
class PurchaseOrderScreen extends StatelessWidget {
  const PurchaseOrderScreen({super.key});
  @override Widget build(BuildContext context)=>const MasterPage(title:'PURCHASE ORDER',section:'10',tableTitle:'PURCHASE ORDER REGISTER',columns:['PO NO','DATE','SUPPLIER','VALUE','STATUS'],rows:[['PO-0001','23/09/2026','-','₹0.00','DRAFT']]);
}
class PurchaseVoucherScreen extends StatelessWidget {
  const PurchaseVoucherScreen({super.key});
  @override Widget build(BuildContext context)=>const MasterPage(title:'PURCHASE VOUCHER',section:'11',tableTitle:'PURCHASE VOUCHER REGISTER',columns:['VOUCHER NO','DATE','SUPPLIER','VALUE','STATUS'],rows:[['PV-0001','23/09/2026','-','₹0.00','DRAFT']]);
}

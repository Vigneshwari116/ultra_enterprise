import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../widgets/compact_date_picker.dart';
import '../widgets/csv_import.dart';
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
  @override
  State<UnitMasterScreen> createState() => _UnitMasterScreenState();
}

class _UnitMasterScreenState extends State<UnitMasterScreen> {
  List<Map<String, dynamic>> data = [];
  final filterCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String? error;
  int? selectedId;

  @override
  void initState() {
    super.initState();
    load();
    filterCtrl.addListener(() => setState(() {}));
  }

  Future<void> load() async {
    data = await AppDatabase.instance.units();
    if (mounted) setState(() {});
  }

  void _startNew() {
    setState(() {
      selectedId = null;
      codeCtrl.clear();
      descCtrl.clear();
      error = null;
    });
  }

  Future<void> _save() async {
    if (codeCtrl.text.trim().isEmpty) {
      setState(() => error = 'UOM parameter code cannot be blank.');
      return;
    }
    await AppDatabase.instance.insertUnit({
      'code': codeCtrl.text.trim().toUpperCase(),
      'name': descCtrl.text.trim().isEmpty ? codeCtrl.text.trim() : descCtrl.text.trim(),
      'description': descCtrl.text.trim(),
    });
    codeCtrl.clear();
    descCtrl.clear();
    setState(() => error = null);
    await load();
  }

  Future<void> _delete(int id) async {
    await AppDatabase.instance.deleteUnit(id);
    if (selectedId == id) _startNew();
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final q = filterCtrl.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? data
        : data.where((u) =>
    '${u['code']}'.toLowerCase().contains(q) ||
        '${u['name']}'.toLowerCase().contains(q)).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT: UOM REGISTRY TOKENS list
        Container(
          width: 300,
          color: sidebarBg,
          height: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                child: Row(
                  children: const [
                    Icon(Icons.view_agenda_outlined, color: teal, size: 16),
                    SizedBox(width: 8),
                    Text('UOM REGISTRY TOKENS',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .5)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: filterCtrl,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Filter units (e.g. KGS)...',
                    hintStyle: const TextStyle(fontSize: 11),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(3),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final u = filtered[i];
                    final selected = selectedId == u['id'];
                    return InkWell(
                      onTap: () => setState(() {
                        selectedId = u['id'] as int;
                        codeCtrl.text = '${u['code']}';
                        descCtrl.text = '${u['description'] ?? u['name'] ?? ''}';
                        error = null;
                      }),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? sidebarActiveBg : Colors.white.withOpacity(.04),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${u['code']}',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: selected ? navy : Colors.white)),
                                  const SizedBox(height: 2),
                                  Text('${u['name']}'.toUpperCase(),
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: selected ? navy2 : Colors.white60)),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => _delete(u['id'] as int),
                              child: const Icon(Icons.delete_outline, size: 17, color: red),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // RIGHT: NEW UNIT PARAMETER form
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: border)),
                ),
                child: Row(
                  children: [
                    Container(width: 3, height: 18, color: navy),
                    const SizedBox(width: 10),
                    Text(
                      selectedId == null ? 'NEW UNIT PARAMETER' : 'EDIT UNIT PARAMETER',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: navy),
                    ),
                    const Spacer(),
                    if (selectedId != null) ...[
                      TextButton(onPressed: _startNew, child: const Text('CANCEL')),
                      const SizedBox(width: 8),
                    ],
                    PrimaryButton(
                      label: selectedId == null ? 'SAVE UOM' : 'UPDATE UOM',
                      icon: Icons.save_outlined,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FormSectionBar(title: '1. METRIC CODE MAPPING'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'UOM TOKEN CODE (E.G. PCS, KGS) *',
                        errorText: error,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _FormSectionBar(title: '2. DATA DEFINITION SPECIFICATION'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'UNIT DESCRIPTION REGISTERED',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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

  DateTimeRange? printRange;

  Future<void> _pickPrintRange() async {
    final picked = await pickCompactDateRange(context, initial: printRange);
    if (picked != null) {
      setState(() => printRange = picked);
    }
  }

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
                        items: const ['SALES', 'PURCHASE', 'SUNDRY DEBTOR']
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
                          onPressed: _pickPrintRange,
                          icon: const Icon(Icons.calendar_today_outlined, size: 15),
                          label: Text(
                            printRange == null
                                ? 'PRINT RANGE'
                                : '${_fmtDate(printRange!.start)} - ${_fmtDate(printRange!.end)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                          ),
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

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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
  bool importing = false;

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
  final shipNameCtrl = TextEditingController();
  final shipMobileCtrl = TextEditingController();
  final shipAddressCtrl = TextEditingController();
  final shipCityCtrl = TextEditingController();
  final shipPincodeCtrl = TextEditingController();
  final shipGstinCtrl = TextEditingController();

  @override void initState(){super.initState();load();}
  Future<void> load() async { data = await AppDatabase.instance.customers(); if(mounted) setState((){}); }

  void _clearForm() {
    for (final c in [nameCtrl, mobileCtrl, emailCtrl, addressCtrl, cityCtrl, pincodeCtrl, gstinCtrl,
      bankNameCtrl, bankAccCtrl, ifscCtrl, branchCtrl, shipNameCtrl, shipMobileCtrl, shipAddressCtrl,
      shipCityCtrl, shipPincodeCtrl, shipGstinCtrl]) {
      c.clear();
    }
    openCrCtrl.text = '0';
    openDrCtrl.text = '0';
    setState(() => selectedId = null);
  }

  // Populates every field on the right with the tapped customer's saved data,
  // and switches the header into "editing" mode (MODIFY / UPDATE / CANCEL).
  void _loadIntoForm(Map<String, dynamic> c) {
    nameCtrl.text = '${c['customer_name'] ?? ''}';
    mobileCtrl.text = '${c['primary_mobile'] ?? ''}';
    emailCtrl.text = '${c['email'] ?? ''}';
    addressCtrl.text = '${c['address'] ?? ''}';
    cityCtrl.text = '${c['city'] ?? ''}';
    pincodeCtrl.text = '${c['postal_pincode'] ?? ''}';
    gstinCtrl.text = '${c['gstin'] ?? ''}';
    openCrCtrl.text = '${c['opening_balance_cr'] ?? 0}';
    openDrCtrl.text = '${c['opening_balance_dr'] ?? 0}';
    bankNameCtrl.text = '${c['bank_name'] ?? ''}';
    bankAccCtrl.text = '${c['bank_account_no'] ?? ''}';
    ifscCtrl.text = '${c['ifsc_code'] ?? ''}';
    branchCtrl.text = '${c['branch_address'] ?? ''}';
    shipNameCtrl.text = '${c['shipping_consignee_name'] ?? ''}';
    shipMobileCtrl.text = '${c['shipping_contact_mobile'] ?? ''}';
    shipAddressCtrl.text = '${c['shipping_address'] ?? ''}';
    shipCityCtrl.text = '${c['shipping_city'] ?? ''}';
    shipPincodeCtrl.text = '${c['shipping_pincode'] ?? ''}';
    shipGstinCtrl.text = '${c['shipping_gstin'] ?? ''}';
    setState(() => selectedId = c['id'] as int);
  }

  Map<String, dynamic> _formToRow() => {
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
    'shipping_consignee_name': shipNameCtrl.text,
    'shipping_contact_mobile': shipMobileCtrl.text,
    'shipping_address': shipAddressCtrl.text,
    'shipping_city': shipCityCtrl.text,
    'shipping_pincode': shipPincodeCtrl.text,
    'shipping_gstin': shipGstinCtrl.text,
  };

  Future<void> save() async {
    if (nameCtrl.text.trim().isEmpty) return;
    if (selectedId == null) {
      await AppDatabase.instance.insertCustomer({
        'customer_code': 'CUST-${DateTime.now().millisecondsSinceEpoch % 100000}',
        ..._formToRow(),
      });
    } else {
      await AppDatabase.instance.updateCustomer(selectedId!, _formToRow());
    }
    _clearForm();
    await load();
  }

  // IMPORT: lets the user pick a .csv file (columns: name,mobile,email,address,
  // city,pincode,gstin — first row is treated as a header and skipped) and bulk
  // inserts every row as a new customer.
  Future<void> _import() async {
    setState(() => importing = true);
    try {
      final content = await pickCsvFileContent();
      if (content == null) {
        setState(() => importing = false);
        return;
      }
      final lines = content
          .split(RegExp(r'\r?\n'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) {
        _notify('The selected file has no data rows.');
        setState(() => importing = false);
        return;
      }
      int imported = 0;
      for (var i = 1; i < lines.length; i++) {
        final cols = lines[i].split(',').map((c) => c.trim()).toList();
        if (cols.isEmpty || cols.first.isEmpty) continue;
        await AppDatabase.instance.insertCustomer({
          'customer_code': 'CUST-${DateTime.now().millisecondsSinceEpoch % 100000}-$i',
          'customer_name': cols.isNotEmpty ? cols[0] : '',
          'primary_mobile': cols.length > 1 ? cols[1] : '',
          'email': cols.length > 2 ? cols[2] : '',
          'address': cols.length > 3 ? cols[3] : '',
          'city': cols.length > 4 ? cols[4] : '',
          'postal_pincode': cols.length > 5 ? cols[5] : '',
          'gstin': cols.length > 6 ? cols[6] : '',
        });
        imported++;
      }
      await load();
      _notify('$imported customer record(s) imported.');
    } catch (e) {
      _notify('Import failed: $e');
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  void _notify(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = searchCtrl.text.trim().isEmpty
        ? data
        : data.where((c) => '${c['customer_name']}'.toLowerCase().contains(searchCtrl.text.trim().toLowerCase())).toList();
    final batch = 'CUST-${DateTime.now().toString().substring(0, 10).replaceAll('-', '').substring(2)}';
    final editing = selectedId != null;

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
                      onTap: () => _loadIntoForm(c),
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
                  Text(editing ? 'MODIFY CUSTOMER RECORD' : 'CUSTOMER MASTER SETUP',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: navy)),
                  if (editing) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: amber.withOpacity(.15), borderRadius: BorderRadius.circular(3)),
                      child: const Text('EDITING', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: amber)),
                    ),
                  ],
                  const Spacer(),
                  if (!editing) ...[
                    Text('BATCH: $batch',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: teal)),
                    const SizedBox(width: 14),
                    OutlinedButton.icon(
                      onPressed: importing ? null : _import,
                      icon: importing
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: teal))
                          : const Icon(Icons.file_download_outlined, size: 15),
                      label: Text(importing ? 'IMPORTING...' : 'IMPORT', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: teal,
                        side: const BorderSide(color: teal),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ] else ...[
                    TextButton(onPressed: _clearForm, child: const Text('CANCEL')),
                    const SizedBox(width: 10),
                  ],
                  ElevatedButton.icon(
                    onPressed: save,
                    icon: const Icon(Icons.save_outlined, size: 15),
                    label: Text(editing ? 'UPDATE' : 'SAVE', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
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
                  Field(label: 'SHIPPING CONSIGNEE NAME', child: TextField(controller: shipNameCtrl)),
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
class SupplierMasterScreen extends StatefulWidget {
  const SupplierMasterScreen({super.key});
  @override State<SupplierMasterScreen> createState()=>_SupplierMasterScreenState();
}
class _SupplierMasterScreenState extends State<SupplierMasterScreen>{
  List<Map<String,dynamic>> data=[];
  int? selectedId;
  final searchCtrl = TextEditingController();
  bool importing = false;

  final nameCtrl = TextEditingController();
  final contactCtrl = TextEditingController();
  final mobileCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final pincodeCtrl = TextEditingController();
  final gstinCtrl = TextEditingController();
  final panCtrl = TextEditingController();
  final openCrCtrl = TextEditingController(text: '0');
  final openDrCtrl = TextEditingController(text: '0');
  final bankNameCtrl = TextEditingController();
  final bankAccCtrl = TextEditingController();
  final ifscCtrl = TextEditingController();
  final branchCtrl = TextEditingController();
  final shipNameCtrl = TextEditingController();
  final shipAddressCtrl = TextEditingController();
  final shipCityCtrl = TextEditingController();
  final shipPincodeCtrl = TextEditingController();
  final shipAltCodeCtrl = TextEditingController();

  @override void initState(){super.initState();load();}
  Future<void> load() async { data = await AppDatabase.instance.suppliers(); if(mounted) setState((){}); }

  void _clearForm() {
    for (final c in [nameCtrl, contactCtrl, mobileCtrl, emailCtrl, addressCtrl, cityCtrl, pincodeCtrl, gstinCtrl,
      panCtrl, bankNameCtrl, bankAccCtrl, ifscCtrl, branchCtrl, shipNameCtrl, shipAddressCtrl,
      shipCityCtrl, shipPincodeCtrl, shipAltCodeCtrl]) {
      c.clear();
    }
    openCrCtrl.text = '0';
    openDrCtrl.text = '0';
    setState(() => selectedId = null);
  }

  void _loadIntoForm(Map<String, dynamic> s) {
    nameCtrl.text = '${s['supplier_name'] ?? ''}';
    contactCtrl.text = '${s['contact_name'] ?? ''}';
    mobileCtrl.text = '${s['primary_mobile'] ?? ''}';
    emailCtrl.text = '${s['email'] ?? ''}';
    addressCtrl.text = '${s['address'] ?? ''}';
    cityCtrl.text = '${s['city'] ?? ''}';
    pincodeCtrl.text = '${s['postal_pincode'] ?? ''}';
    gstinCtrl.text = '${s['gstin'] ?? ''}';
    panCtrl.text = '${s['pan_no'] ?? ''}';
    openCrCtrl.text = '${s['opening_balance_cr'] ?? 0}';
    openDrCtrl.text = '${s['opening_balance_dr'] ?? 0}';
    bankNameCtrl.text = '${s['bank_name'] ?? ''}';
    bankAccCtrl.text = '${s['bank_account_no'] ?? ''}';
    ifscCtrl.text = '${s['ifsc_code'] ?? ''}';
    branchCtrl.text = '${s['branch_address'] ?? ''}';
    shipNameCtrl.text = '${s['shipping_consignee_name'] ?? ''}';
    shipAddressCtrl.text = '${s['shipping_address'] ?? ''}';
    shipCityCtrl.text = '${s['shipping_city'] ?? ''}';
    shipPincodeCtrl.text = '${s['shipping_pincode'] ?? ''}';
    shipAltCodeCtrl.text = '${s['shipping_alt_code'] ?? ''}';
    setState(() => selectedId = s['id'] as int);
  }

  Map<String, dynamic> _formToRow() => {
    'supplier_name': nameCtrl.text.trim(),
    'contact_name': contactCtrl.text,
    'primary_mobile': mobileCtrl.text,
    'email': emailCtrl.text,
    'address': addressCtrl.text,
    'city': cityCtrl.text,
    'postal_pincode': pincodeCtrl.text,
    'gstin': gstinCtrl.text,
    'pan_no': panCtrl.text,
    'opening_balance_cr': double.tryParse(openCrCtrl.text) ?? 0,
    'opening_balance_dr': double.tryParse(openDrCtrl.text) ?? 0,
    'bank_name': bankNameCtrl.text,
    'bank_account_no': bankAccCtrl.text,
    'ifsc_code': ifscCtrl.text,
    'branch_address': branchCtrl.text,
    'shipping_consignee_name': shipNameCtrl.text,
    'shipping_address': shipAddressCtrl.text,
    'shipping_city': shipCityCtrl.text,
    'shipping_pincode': shipPincodeCtrl.text,
    'shipping_alt_code': shipAltCodeCtrl.text,
  };

  Future<void> save() async {
    if (nameCtrl.text.trim().isEmpty) return;
    if (selectedId == null) {
      await AppDatabase.instance.insertSupplier({
        'supplier_code': 'SUPP-${DateTime.now().millisecondsSinceEpoch % 100000}',
        ..._formToRow(),
      });
    } else {
      await AppDatabase.instance.updateSupplier(selectedId!, _formToRow());
    }
    _clearForm();
    await load();
  }

  // IMPORT: .csv columns — name,contact,mobile,email,address,city,pincode,gstin,pan
  Future<void> _import() async {
    setState(() => importing = true);
    try {
      final content = await pickCsvFileContent();
      if (content == null) {
        setState(() => importing = false);
        return;
      }
      final lines = content
          .split(RegExp(r'\r?\n'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) {
        _notify('The selected file has no data rows.');
        setState(() => importing = false);
        return;
      }
      int imported = 0;
      for (var i = 1; i < lines.length; i++) {
        final cols = lines[i].split(',').map((c) => c.trim()).toList();
        if (cols.isEmpty || cols.first.isEmpty) continue;
        await AppDatabase.instance.insertSupplier({
          'supplier_code': 'SUPP-${DateTime.now().millisecondsSinceEpoch % 100000}-$i',
          'supplier_name': cols.isNotEmpty ? cols[0] : '',
          'contact_name': cols.length > 1 ? cols[1] : '',
          'primary_mobile': cols.length > 2 ? cols[2] : '',
          'email': cols.length > 3 ? cols[3] : '',
          'address': cols.length > 4 ? cols[4] : '',
          'city': cols.length > 5 ? cols[5] : '',
          'postal_pincode': cols.length > 6 ? cols[6] : '',
          'gstin': cols.length > 7 ? cols[7] : '',
          'pan_no': cols.length > 8 ? cols[8] : '',
        });
        imported++;
      }
      await load();
      _notify('$imported supplier record(s) imported.');
    } catch (e) {
      _notify('Import failed: $e');
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  void _notify(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = searchCtrl.text.trim().isEmpty
        ? data
        : data.where((s) => '${s['supplier_name']}'.toLowerCase().contains(searchCtrl.text.trim().toLowerCase())).toList();
    final batch = 'SUPP-${DateTime.now().toString().substring(0, 10).replaceAll('-', '')}';
    final editing = selectedId != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: dark supplier directory panel
        Container(
          width: 300,
          color: sidebarBg,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: const [
                Icon(Icons.local_shipping_outlined, color: teal, size: 15),
                SizedBox(width: 8),
                Text('SUPPLIER DIRECTORY',
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
                  hintText: 'Search supplier records...',
                  hintStyle: TextStyle(fontSize: 11.5),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final s = filtered[i];
                    final selected = selectedId == s['id'];
                    return InkWell(
                      onTap: () => _loadIntoForm(s),
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
                                Text('${i + 1}. ${s['supplier_name']}',
                                    style: TextStyle(
                                        color: selected ? navy : Colors.white,
                                        fontSize: 11.5, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 3),
                                Text('Mob: ${(s['primary_mobile'] ?? '').toString().isEmpty ? 'N/A' : s['primary_mobile']} | GST: ${(s['gstin'] ?? '').toString().isEmpty ? 'N/A' : s['gstin']}',
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
                  Text(editing ? 'MODIFY SUPPLIER RECORD' : 'SUPPLIER SETUP MATRIX',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: navy)),
                  if (editing) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: amber.withOpacity(.15), borderRadius: BorderRadius.circular(3)),
                      child: const Text('EDITING', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: amber)),
                    ),
                  ],
                  const Spacer(),
                  if (!editing) ...[
                    Text('BATCH: $batch',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: teal)),
                    const SizedBox(width: 14),
                    OutlinedButton.icon(
                      onPressed: importing ? null : _import,
                      icon: importing
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: teal))
                          : const Icon(Icons.file_download_outlined, size: 15),
                      label: Text(importing ? 'IMPORTING...' : 'IMPORT', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: teal,
                        side: const BorderSide(color: teal),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ] else ...[
                    TextButton(onPressed: _clearForm, child: const Text('CANCEL')),
                    const SizedBox(width: 10),
                  ],
                  ElevatedButton.icon(
                    onPressed: save,
                    icon: const Icon(Icons.save_outlined, size: 15),
                    label: Text(editing ? 'UPDATE' : 'SAVE', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                _FormSectionBar(title: '1. VENDOR REGISTRATION PRIMARY SCHEMA'),
                const SizedBox(height: 12),
                _row3(
                  Field(label: 'VENDOR / CORPORATE NAME', requiredField: true, child: TextField(controller: nameCtrl)),
                  Field(label: 'CONTACT NAME', child: TextField(controller: contactCtrl)),
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
                  Field(label: 'CORPORATE PAN CODE', child: TextField(controller: panCtrl)),
                  Field(label: 'PRIMARY MOBILE NO', child: TextField(controller: mobileCtrl)),
                ),
                const SizedBox(height: 20),
                _FormSectionBar(title: '2. FINANCIAL SETTLEMENT & BANKING CREDENTIALS'),
                const SizedBox(height: 12),
                _row3(
                  Field(label: 'BANK NAME', child: TextField(controller: bankNameCtrl)),
                  Field(label: 'BANK ACCOUNT NUMBER', child: TextField(controller: bankAccCtrl)),
                  Field(label: 'IFSC CODE', child: TextField(controller: ifscCtrl)),
                ),
                const SizedBox(height: 12),
                Field(label: 'BRANCH LOCATION & ADDRESS DETAILS', child: TextField(controller: branchCtrl)),
                const SizedBox(height: 20),
                _FormSectionBar(title: '3. LEDGER BALANCES & RISK CONTROL PROFILE'),
                const SizedBox(height: 12),
                _row2(
                  Field(label: 'OPENING BALANCE (CR)',
                      child: TextField(controller: openCrCtrl, style: const TextStyle(color: green, fontWeight: FontWeight.w800))),
                  Field(label: 'OPENING BALANCE (DR)',
                      child: TextField(controller: openDrCtrl, style: const TextStyle(color: red, fontWeight: FontWeight.w800))),
                ),
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('4. LOGISTICS & SHIPPING WAREHOUSE ALTERNATES (OPTIONAL)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: navy, letterSpacing: .3)),
                  children: [
                    const SizedBox(height: 8),
                    _row2(
                      Field(label: 'CONSIGNED CONSIGNMENT DELIVERY NAME', child: TextField(controller: shipNameCtrl)),
                      Field(label: 'SHIPPING DELIVERY ADDRESS', child: TextField(controller: shipAddressCtrl)),
                    ),
                    const SizedBox(height: 12),
                    _row3(
                      Field(label: 'SHIPPING CITY', child: TextField(controller: shipCityCtrl)),
                      Field(label: 'SHIPPING PINCODE', child: TextField(controller: shipPincodeCtrl)),
                      Field(label: 'SHIPPING ALTERNATE CODE', child: TextField(controller: shipAltCodeCtrl)),
                    ),
                    const SizedBox(height: 12),
                  ],
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

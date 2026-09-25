import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../widgets/compact_date_picker.dart';
import '../widgets/csv_import.dart';
import '../widgets/enterprise_widgets.dart';
import '../widgets/master_form_helpers.dart';
import 'sales_invoice_screen.dart';

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
  final codeFocus = FocusNode();
  final descFocus = FocusNode();
  String? error;
  int? selectedId;

  @override
  void initState() {
    super.initState();
    load();
    filterCtrl.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => codeFocus.requestFocus());
  }

  @override
  void dispose() {
    filterCtrl.dispose();
    codeCtrl.dispose();
    descCtrl.dispose();
    codeFocus.dispose();
    descFocus.dispose();
    super.dispose();
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
    codeFocus.requestFocus();
  }

  Future<void> _save() async {
    if (codeCtrl.text.trim().isEmpty) {
      setState(() => error = 'UOM parameter code cannot be blank.');
      return;
    }
    final row = {
      'code': codeCtrl.text.trim().toUpperCase(),
      'name': descCtrl.text.trim().isEmpty ? codeCtrl.text.trim() : descCtrl.text.trim(),
      'description': descCtrl.text.trim(),
    };
    if (selectedId == null) {
      await AppDatabase.instance.insertUnit(row);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unit saved.')));
      }
      codeCtrl.clear();
      descCtrl.clear();
      setState(() => error = null);
    } else {
      await AppDatabase.instance.updateUnit(selectedId!, row);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unit updated.')));
      }
      setState(() => error = null);
    }
    await load();
    if (selectedId != null && mounted) {
      final unit = data.where((u) => u['id'] == selectedId).toList();
      if (unit.isNotEmpty) {
        codeCtrl.text = '${unit.first['code']}';
        descCtrl.text = '${unit.first['description'] ?? unit.first['name'] ?? ''}';
      }
    } else {
      codeFocus.requestFocus();
    }
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
          width: masterDirectoryWidth(context),
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
                  decoration: masterSearchDecoration('Filter units (e.g. KGS)...'),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                padding: masterFormPadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FormSectionBar(title: '1. METRIC CODE MAPPING'),
                    const SizedBox(height: 8),
                    MasterTextField(
                      controller: codeCtrl,
                      focusNode: codeFocus,
                      nextFocus: descFocus,
                      textCapitalization: TextCapitalization.characters,
                      hintText: 'UOM TOKEN CODE (E.G. PCS, KGS) *',
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 4),
                      Text(error!, style: const TextStyle(color: red, fontSize: 10)),
                    ],
                    const SizedBox(height: 16),
                    _FormSectionBar(title: '2. DATA DEFINITION SPECIFICATION'),
                    const SizedBox(height: 8),
                    MasterTextField(
                      controller: descCtrl,
                      focusNode: descFocus,
                      hintText: 'UNIT DESCRIPTION REGISTERED',
                      maxLines: 3,
                      onDone: _save,
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
  final nameFocus = FocusNode();
  final crFocus = FocusNode();
  final drFocus = FocusNode();
  String? group;
  String? head;
  String? groupWise;
  final searchCtrl = TextEditingController();
  int? _editingId;
  List<Map<String, dynamic>> _ledgers = [];

  DateTimeRange? printRange;

  @override
  void initState() {
    super.initState();
    searchCtrl.addListener(() => setState(() {}));
    _loadLedgers();
    WidgetsBinding.instance.addPostFrameCallback((_) => nameFocus.requestFocus());
  }

  Future<void> _loadLedgers() async {
    _ledgers = await AppDatabase.instance.ledgerAccounts();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    crCtrl.dispose();
    drCtrl.dispose();
    nameFocus.dispose();
    crFocus.dispose();
    drFocus.dispose();
    searchCtrl.dispose();
    super.dispose();
  }

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
      _editingId = null;
    });
    nameFocus.requestFocus();
  }

  void _loadForEdit(Map<String, dynamic> row) {
    nameCtrl.text = '${row['name']}';
    crCtrl.text = ((row['cr_amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
    drCtrl.text = ((row['dr_amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
    setState(() {
      final g = '${row['group_name'] ?? ''}';
      group = g.isEmpty ? null : g;
      final h = '${row['head'] ?? ''}';
      head = h.isEmpty ? null : h;
      final gw = '${row['group_wise'] ?? ''}';
      groupWise = gw.isEmpty ? null : gw;
      _editingId = row['id'] as int;
    });
    nameFocus.requestFocus();
  }

  Future<void> _save() async {
    if (nameCtrl.text.trim().isEmpty) {
      nameFocus.requestFocus();
      return;
    }
    final time = TimeOfDay.now().format(context);
    final row = {
      'name': nameCtrl.text.trim(),
      'group_name': group ?? '',
      'head': head ?? '',
      'group_wise': groupWise ?? '',
      'cr_amount': double.tryParse(crCtrl.text) ?? 0.0,
      'dr_amount': double.tryParse(drCtrl.text) ?? 0.0,
      'updated_time': time,
    };
    final editing = _editingId;
    if (editing == null) {
      await AppDatabase.instance.insertLedger(row);
    } else {
      await AppDatabase.instance.updateLedger(editing, row);
    }
    await _loadLedgers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(editing == null ? 'Ledger entry saved.' : 'Ledger entry updated.')),
    );
    _reset();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _ledgers
        .where((l) => matchesMasterSearch(searchCtrl.text, l, ['name', 'group_name', 'head', 'group_wise']))
        .toList();

    return Padding(
      padding: masterFormPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LEDGER MASTER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: navy)),
          const SizedBox(height: 3),
          const Text('FINANCIAL REPOSITORIES PARAMETERS REGISTRY',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF748094))),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: masterDirectoryWidth(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _editingId == null ? 'NEW ENTRY' : 'EDIT ENTRY',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: navy),
                      ),
                      const SizedBox(height: 8),
                      Container(height: 2, width: 40, color: teal),
                      const SizedBox(height: 12),
                      MasterTextField(
                        controller: nameCtrl,
                        focusNode: nameFocus,
                        nextFocus: crFocus,
                        hintText: 'NAME',
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: MasterTextField(
                            controller: crCtrl,
                            focusNode: crFocus,
                            nextFocus: drFocus,
                            hintText: 'CR AMT',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MasterTextField(
                            controller: drCtrl,
                            focusNode: drFocus,
                            hintText: 'DR AMT',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onDone: _save,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      MasterDropdown(
                        value: group,
                        hintText: 'GROUP',
                        items: masterLedgerGroupOptions,
                        onChanged: (v) => setState(() => group = v),
                      ),
                      const SizedBox(height: 8),
                      MasterDropdown(
                        value: head,
                        hintText: 'HEAD',
                        items: masterLedgerGroupOptions,
                        onChanged: (v) => setState(() => head = v),
                      ),
                      const SizedBox(height: 8),
                      MasterDropdown(
                        value: groupWise,
                        hintText: 'GROUP WISE',
                        items: masterLedgerGroupOptions,
                        onChanged: (v) => setState(() => groupWise = v),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _reset,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              side: const BorderSide(color: border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                            ),
                            child: const Text('RESET', style: TextStyle(color: navy, fontWeight: FontWeight.w800, fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: navy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                            ),
                            child: Text(
                              _editingId == null ? 'SAVE' : 'UPDATE',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                            ),
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
                            style: const TextStyle(fontSize: 12),
                            decoration: masterCompactDecoration(hintText: 'Search Ledger Accounts Registry...').copyWith(
                              prefixIcon: const Icon(Icons.search, size: 16),
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'No ledger accounts yet. Save a new entry to list it here.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF748094), fontWeight: FontWeight.w600),
                                ),
                              )
                            : _LedgerTable(rows: filtered, onEdit: _loadForEdit),
                      ),
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
  final ValueChanged<Map<String, dynamic>> onEdit;
  const _LedgerTable({required this.rows, required this.onEdit});

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
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEDF0F5)))),
            child: Row(children: [
              Expanded(
                  flex: 4,
                  child: Text('${r['name']}', overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: navy))),
              Expanded(
                  flex: 2,
                  child: Text('${r['group_name'] ?? ''}',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF39485A)))),
              Expanded(
                  flex: 2,
                  child: Text(((r['cr_amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: green))),
              Expanded(
                  flex: 2,
                  child: Text(((r['dr_amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: red))),
              Expanded(
                  flex: 1,
                  child: Text('${r['updated_time'] ?? ''}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF748094)))),
              SizedBox(
                width: 40,
                child: InkWell(
                  onTap: () => onEdit(r),
                  child: const Icon(Icons.edit_outlined, size: 15, color: amber),
                ),
              ),
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
  late final List<FocusNode> _focus;

  @override
  void initState() {
    super.initState();
    _focus = List.generate(19, (_) => FocusNode());
    searchCtrl.addListener(() => setState(() {}));
    load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (selectedId == null) _focus[0].requestFocus();
    });
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    for (final f in _focus) {
      f.dispose();
    }
    for (final c in [
      nameCtrl, mobileCtrl, emailCtrl, addressCtrl, cityCtrl, pincodeCtrl, gstinCtrl,
      openCrCtrl, openDrCtrl, bankNameCtrl, bankAccCtrl, ifscCtrl, branchCtrl,
      shipNameCtrl, shipMobileCtrl, shipAddressCtrl, shipCityCtrl, shipPincodeCtrl, shipGstinCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async { data = await AppDatabase.instance.customers(); if(mounted) setState((){}); }

  Widget _customerField(
    int index,
    String label,
    TextEditingController controller, {
    bool requiredField = false,
    TextStyle? style,
  }) {
    return Field(
      label: label,
      requiredField: requiredField,
      child: MasterTextField(
        controller: controller,
        focusNode: _focus[index],
        nextFocus: index < _focus.length - 1 ? _focus[index + 1] : null,
        onDone: save,
        style: style,
      ),
    );
  }

  void _clearForm() {
    for (final c in [nameCtrl, mobileCtrl, emailCtrl, addressCtrl, cityCtrl, pincodeCtrl, gstinCtrl,
      bankNameCtrl, bankAccCtrl, ifscCtrl, branchCtrl, shipNameCtrl, shipMobileCtrl, shipAddressCtrl,
      shipCityCtrl, shipPincodeCtrl, shipGstinCtrl]) {
      c.clear();
    }
    openCrCtrl.text = '0';
    openDrCtrl.text = '0';
    setState(() => selectedId = null);
    _focus[0].requestFocus();
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
    if (nameCtrl.text.trim().isEmpty) {
      _notify('Customer / company name is required.');
      _focus[0].requestFocus();
      return;
    }
    final existingId = selectedId;
    if (existingId == null) {
      await AppDatabase.instance.insertCustomer({
        'customer_code': 'CUST-${DateTime.now().millisecondsSinceEpoch % 100000}',
        ..._formToRow(),
      });
      _notify('Customer saved.');
      _clearForm();
    } else {
      await AppDatabase.instance.updateCustomer(existingId, _formToRow());
      _notify('Customer updated.');
    }
    await load();
    if (existingId != null) {
      final row = data.where((c) => c['id'] == existingId).toList();
      if (row.isNotEmpty) _loadIntoForm(row.first);
    }
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
    final filtered = data
        .where((c) => matchesMasterSearch(searchCtrl.text, c, [
              'customer_name',
              'primary_mobile',
              'gstin',
              'city',
              'email',
            ]))
        .toList();
    final batch = 'CUST-${DateTime.now().toString().substring(0, 10).replaceAll('-', '').substring(2)}';
    final editing = selectedId != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: dark customer directory panel
        Container(
          width: masterDirectoryWidth(context),
          color: sidebarBg,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: const [
                Icon(Icons.grid_view_rounded, color: teal, size: 15),
                SizedBox(width: 8),
                Text('CUSTOMER DIRECTORY',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .5)),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: searchCtrl,
                onChanged: (_) => setState((){}),
                style: const TextStyle(fontSize: 12),
                decoration: masterSearchDecoration('Search customer records...'),
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
            padding: masterFormPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(width: 4, height: 18, color: navy),
                  const SizedBox(width: 10),
                  Text(editing ? 'MODIFY CUSTOMER RECORD' : 'CUSTOMER MASTER SETUP',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: navy)),
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
                const SizedBox(height: 14),
                _FormSectionBar(title: '1. CLIENT REGISTRATION SCHEMA DETAILS'),
                const SizedBox(height: 8),
                masterRow3(
                  context,
                  _customerField(0, 'CUSTOMER / COMPANY NAME', nameCtrl, requiredField: true),
                  _customerField(1, 'PRIMARY MOBILE NO', mobileCtrl),
                  _customerField(2, 'EMAIL ADDRESS', emailCtrl),
                ),
                const SizedBox(height: 8),
                masterRow3(
                  context,
                  _customerField(3, 'REGISTERED BILLING ADDRESS', addressCtrl),
                  _customerField(4, 'CITY', cityCtrl),
                  _customerField(5, 'PIN CODE', pincodeCtrl),
                ),
                const SizedBox(height: 8),
                masterRow3(
                  context,
                  _customerField(6, 'GSTIN COMPLIANCE NUMBER', gstinCtrl),
                  _customerField(7, 'OPENING BALANCE (CR)', openCrCtrl,
                      style: const TextStyle(color: green, fontWeight: FontWeight.w800)),
                  _customerField(8, 'OPENING BALANCE (DR)', openDrCtrl,
                      style: const TextStyle(color: red, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 14),
                _FormSectionBar(title: '2. CLIENT BANKING ACCOUNT CREDENTIALS'),
                const SizedBox(height: 8),
                masterRow3(
                  context,
                  _customerField(9, 'BANK NAME', bankNameCtrl),
                  _customerField(10, 'BANK ACCOUNT NUMBER', bankAccCtrl),
                  _customerField(11, 'IFSC CODE', ifscCtrl),
                ),
                const SizedBox(height: 8),
                _customerField(12, 'BRANCH LOCATION & ADDRESS DETAILS', branchCtrl),
                const SizedBox(height: 14),
                _FormSectionBar(title: '3. CORE LOGISTICS & SHIPPING DESTINATIONS'),
                const SizedBox(height: 8),
                masterRow2(
                  context,
                  _customerField(13, 'SHIPPING CONSIGNEE NAME', shipNameCtrl),
                  _customerField(14, 'SHIPPING CONTACT MOBILE', shipMobileCtrl),
                ),
                const SizedBox(height: 8),
                _customerField(15, 'CONSIGNMENT DELIVERY SHIPPING ADDRESS', shipAddressCtrl),
                const SizedBox(height: 8),
                masterRow3(
                  context,
                  _customerField(16, 'SHIPPING DESTINATION CITY', shipCityCtrl),
                  _customerField(17, 'SHIPPING TERMINAL PINCODE', shipPincodeCtrl),
                  _customerField(18, 'SHIPPING LOCATION GSTIN', shipGstinCtrl),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

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
  late final List<FocusNode> _focus;

  @override
  void initState() {
    super.initState();
    _focus = List.generate(20, (_) => FocusNode());
    searchCtrl.addListener(() => setState(() {}));
    load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (selectedId == null) _focus[0].requestFocus();
    });
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    for (final f in _focus) {
      f.dispose();
    }
    for (final c in [
      nameCtrl, contactCtrl, mobileCtrl, emailCtrl, addressCtrl, cityCtrl, pincodeCtrl, gstinCtrl,
      panCtrl, openCrCtrl, openDrCtrl, bankNameCtrl, bankAccCtrl, ifscCtrl, branchCtrl,
      shipNameCtrl, shipAddressCtrl, shipCityCtrl, shipPincodeCtrl, shipAltCodeCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async { data = await AppDatabase.instance.suppliers(); if(mounted) setState((){}); }

  Widget _supplierField(
    int index,
    String label,
    TextEditingController controller, {
    bool requiredField = false,
    TextStyle? style,
    TextInputType? keyboardType,
  }) {
    return Field(
      label: label,
      requiredField: requiredField,
      child: MasterTextField(
        controller: controller,
        focusNode: _focus[index],
        nextFocus: index < _focus.length - 1 ? _focus[index + 1] : null,
        onDone: save,
        style: style,
        keyboardType: keyboardType,
      ),
    );
  }

  void _clearForm() {
    for (final c in [nameCtrl, contactCtrl, mobileCtrl, emailCtrl, addressCtrl, cityCtrl, pincodeCtrl, gstinCtrl,
      panCtrl, bankNameCtrl, bankAccCtrl, ifscCtrl, branchCtrl, shipNameCtrl, shipAddressCtrl,
      shipCityCtrl, shipPincodeCtrl, shipAltCodeCtrl]) {
      c.clear();
    }
    openCrCtrl.text = '0';
    openDrCtrl.text = '0';
    setState(() => selectedId = null);
    _focus[0].requestFocus();
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
    if (nameCtrl.text.trim().isEmpty) {
      _notify('Vendor / corporate name is required.');
      _focus[0].requestFocus();
      return;
    }
    final existingId = selectedId;
    if (existingId == null) {
      await AppDatabase.instance.insertSupplier({
        'supplier_code': 'SUPP-${DateTime.now().millisecondsSinceEpoch % 100000}',
        ..._formToRow(),
      });
      _notify('Supplier saved.');
      _clearForm();
    } else {
      await AppDatabase.instance.updateSupplier(existingId, _formToRow());
      _notify('Supplier updated.');
    }
    await load();
    if (existingId != null) {
      final row = data.where((s) => s['id'] == existingId).toList();
      if (row.isNotEmpty) _loadIntoForm(row.first);
    } else {
      _focus[0].requestFocus();
    }
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
    final filtered = data
        .where((s) => matchesMasterSearch(searchCtrl.text, s, [
              'supplier_name',
              'primary_mobile',
              'gstin',
              'city',
              'contact_name',
              'email',
            ]))
        .toList();
    final batch = 'SUPP-${DateTime.now().toString().substring(0, 10).replaceAll('-', '')}';
    final editing = selectedId != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: dark supplier directory panel
        Container(
          width: masterDirectoryWidth(context),
          color: sidebarBg,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: const [
                Icon(Icons.local_shipping_outlined, color: teal, size: 15),
                SizedBox(width: 8),
                Text('SUPPLIER DIRECTORY',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .5)),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: searchCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: masterSearchDecoration('Search supplier records...'),
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
            padding: masterFormPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(width: 4, height: 18, color: navy),
                  const SizedBox(width: 10),
                  Text(editing ? 'MODIFY SUPPLIER RECORD' : 'SUPPLIER SETUP MATRIX',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: navy)),
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
                const SizedBox(height: 14),
                _FormSectionBar(title: '1. VENDOR REGISTRATION PRIMARY SCHEMA'),
                const SizedBox(height: 8),
                masterRow3(
                  context,
                  _supplierField(0, 'VENDOR / CORPORATE NAME', nameCtrl, requiredField: true),
                  _supplierField(1, 'CONTACT NAME', contactCtrl),
                  _supplierField(2, 'EMAIL ADDRESS', emailCtrl),
                ),
                const SizedBox(height: 8),
                masterRow3(
                  context,
                  _supplierField(3, 'REGISTERED BILLING ADDRESS', addressCtrl),
                  _supplierField(4, 'CITY', cityCtrl),
                  _supplierField(5, 'PIN CODE', pincodeCtrl),
                ),
                const SizedBox(height: 8),
                masterRow3(
                  context,
                  _supplierField(6, 'GSTIN COMPLIANCE NUMBER', gstinCtrl),
                  _supplierField(7, 'CORPORATE PAN CODE', panCtrl),
                  _supplierField(8, 'PRIMARY MOBILE NO', mobileCtrl),
                ),
                const SizedBox(height: 14),
                _FormSectionBar(title: '2. FINANCIAL SETTLEMENT & BANKING CREDENTIALS'),
                const SizedBox(height: 8),
                masterRow3(
                  context,
                  _supplierField(9, 'BANK NAME', bankNameCtrl),
                  _supplierField(10, 'BANK ACCOUNT NUMBER', bankAccCtrl),
                  _supplierField(11, 'IFSC CODE', ifscCtrl),
                ),
                const SizedBox(height: 8),
                _supplierField(12, 'BRANCH LOCATION & ADDRESS DETAILS', branchCtrl),
                const SizedBox(height: 14),
                _FormSectionBar(title: '3. LEDGER BALANCES & RISK CONTROL PROFILE'),
                const SizedBox(height: 8),
                masterRow2(
                  context,
                  _supplierField(13, 'OPENING BALANCE (CR)', openCrCtrl,
                      style: const TextStyle(color: green, fontWeight: FontWeight.w800),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  _supplierField(14, 'OPENING BALANCE (DR)', openDrCtrl,
                      style: const TextStyle(color: red, fontWeight: FontWeight.w800),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                ),
                const SizedBox(height: 10),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('4. LOGISTICS & SHIPPING WAREHOUSE ALTERNATES (OPTIONAL)',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: navy, letterSpacing: .3)),
                  children: [
                    const SizedBox(height: 8),
                    masterRow2(
                      context,
                      _supplierField(15, 'CONSIGNED CONSIGNMENT DELIVERY NAME', shipNameCtrl),
                      _supplierField(16, 'SHIPPING DELIVERY ADDRESS', shipAddressCtrl),
                    ),
                    const SizedBox(height: 8),
                    masterRow3(
                      context,
                      _supplierField(17, 'SHIPPING CITY', shipCityCtrl),
                      _supplierField(18, 'SHIPPING PINCODE', shipPincodeCtrl),
                      _supplierField(19, 'SHIPPING ALTERNATE CODE', shipAltCodeCtrl),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

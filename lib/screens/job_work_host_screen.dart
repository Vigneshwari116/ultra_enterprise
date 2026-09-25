import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../widgets/enterprise_widgets.dart';

final jobWorkHostKey = GlobalKey<JobWorkHostScreenState>();

enum JobWorkView { materialType, materialMaster }

abstract class JobWorkHostScreenState extends State<JobWorkHostScreen> {
  void showMaterialType();
  void showMaterialMaster();
}

class JobWorkHostScreen extends StatefulWidget {
  const JobWorkHostScreen({super.key});
  @override
  JobWorkHostScreenState createState() => _JobWorkHostScreenState();
}

class _JobWorkHostScreenState extends JobWorkHostScreenState {
  JobWorkView view = JobWorkView.materialType;

  @override
  void showMaterialType() => setState(() => view = JobWorkView.materialType);
  @override
  void showMaterialMaster() => setState(() => view = JobWorkView.materialMaster);

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: switch (view) {
        JobWorkView.materialType => const _MaterialTypeMasterPanel(),
        JobWorkView.materialMaster => const _MaterialMasterPanel(),
      },
    );
  }
}

// ─── Material Type Master ──────────────────────────────────────────────────────

class _MaterialTypeMasterPanel extends StatefulWidget {
  const _MaterialTypeMasterPanel();
  @override
  State<_MaterialTypeMasterPanel> createState() => _MaterialTypeMasterPanelState();
}

class _MaterialTypeMasterPanelState extends State<_MaterialTypeMasterPanel> {
  final db = AppDatabase.instance;
  final filter = TextEditingController();
  final typeCode = TextEditingController();
  final description = TextEditingController();
  List<Map<String, dynamic>> types = [];
  int? editingId;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    types = await db.materialTypes();
    if (mounted) setState(() {});
  }

  List<Map<String, dynamic>> get _filtered {
    final q = filter.text.trim().toLowerCase();
    if (q.isEmpty) return types;
    return types.where((t) => '${t['type_code']} ${t['description']}'.toLowerCase().contains(q)).toList();
  }

  void _select(Map<String, dynamic> t) {
    editingId = t['id'] as int;
    typeCode.text = '${t['type_code']}';
    description.text = '${t['description'] ?? ''}';
    setState(() {});
  }

  void _reset() {
    editingId = null;
    typeCode.clear();
    description.clear();
    setState(() {});
  }

  Future<void> _save() async {
    if (typeCode.text.trim().isEmpty) return;
    final row = {'type_code': typeCode.text.trim().toUpperCase(), 'description': description.text.trim()};
    if (editingId == null) {
      await db.insertMaterialType(row);
    } else {
      await db.updateMaterialType(editingId!, row);
    }
    await load();
    _reset();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('MATERIAL TYPE SAVED')));
  }

  Future<void> _delete(int id) async {
    await db.deleteMaterialType(id);
    if (editingId == id) _reset();
    await load();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 280,
          child: Container(
            color: const Color(0xFF1D2739),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('MATERIAL SYSTEM TYPES', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: filter,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 11),
                    decoration: InputDecoration(
                      hintText: 'Filter categories (e.g. COPPER)...',
                      hintStyle: const TextStyle(fontSize: 10, color: Color(0xFF9AA5B4)),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final t = _filtered[i];
                      final id = t['id'] as int;
                      final selected = editingId == id;
                      return Material(
                        color: selected ? sidebarActiveBg.withOpacity(.25) : Colors.transparent,
                        child: InkWell(
                          onTap: () => _select(t),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${t['type_code']}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                                      Text(
                                        '${t['description'] ?? ''}'.isEmpty ? 'No specification description' : '${t['description']}',
                                        style: const TextStyle(color: Colors.white54, fontSize: 9),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _delete(id),
                                  icon: const Icon(Icons.delete_outline, color: red, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: pageBg,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(editingId == null ? 'NEW TYPE PARAMETER' : 'MODIFY TYPE PARAMETER',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: navy)),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: const Text('SAVE TYPE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                      style: ElevatedButton.styleFrom(backgroundColor: navy, foregroundColor: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionTitle('1. MATERIAL CLASSIFICATION TOKENS'),
                TextField(
                  controller: typeCode,
                  decoration: _fieldDec('MATERIAL TYPE KEY CODE (E.G. COPPER, BRASS) *'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 18),
                _sectionTitle('2. CATEGORY SPECIFICATION SPEC SHEET REMARKS'),
                TextField(
                  controller: description,
                  maxLines: 5,
                  decoration: _fieldDec('CATEGORY DESCRIPTION REGISTERED'),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Material Master ───────────────────────────────────────────────────────────

class _MaterialMasterPanel extends StatefulWidget {
  const _MaterialMasterPanel();
  @override
  State<_MaterialMasterPanel> createState() => _MaterialMasterPanelState();
}

class _MaterialMasterPanelState extends State<_MaterialMasterPanel> {
  final db = AppDatabase.instance;
  final search = TextEditingController();
  final code = TextEditingController();
  final name = TextEditingController();
  final unitsBound = TextEditingController(text: '1');
  final rawSize = TextEditingController();
  final finishSize = TextEditingController();
  final purchaseRate = TextEditingController();
  final salesRate = TextEditingController();
  final hsn = TextEditingController();

  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> units = [];
  List<Map<String, dynamic>> materialTypes = [];
  int? unitId;
  int? materialTypeId;
  int? editingId;
  String? imageBase64;
  String logDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    products = await db.products();
    units = await db.units();
    materialTypes = await db.materialTypes();
    if (unitId == null && units.isNotEmpty) unitId = units.first['id'] as int;
    if (materialTypeId == null && materialTypes.isNotEmpty) materialTypeId = materialTypes.first['id'] as int;
    if (mounted) setState(() {});
  }

  List<Map<String, dynamic>> get _filtered {
    final q = search.text.trim().toLowerCase();
    if (q.isEmpty) return products;
    return products.where((p) => '${p['product_code']} ${p['product_name']}'.toLowerCase().contains(q)).toList();
  }

  void _select(Map<String, dynamic> p) {
    editingId = p['id'] as int;
    code.text = '${p['product_code'] ?? ''}';
    name.text = '${p['product_name'] ?? ''}';
    unitId = p['unit_id'] as int?;
    materialTypeId = p['material_type_id'] as int?;
    unitsBound.text = '${p['units_bound'] ?? 1}';
    rawSize.text = '${p['raw_material_size'] ?? ''}';
    finishSize.text = '${p['finishing_size'] ?? ''}';
    purchaseRate.text = '${p['purchase_rate'] ?? p['rate'] ?? 0}';
    salesRate.text = '${p['sales_rate'] ?? p['rate'] ?? 0}';
    hsn.text = '${p['hsn'] ?? ''}';
    imageBase64 = p['image_base64'] as String?;
    final ld = p['log_date'] as String?;
    if (ld != null && ld.isNotEmpty) {
      final d = DateTime.tryParse(ld);
      logDate = d == null ? ld : DateFormat('dd-MM-yyyy').format(d);
    } else {
      logDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    }
    setState(() {});
  }

  void _reset() {
    editingId = null;
    code.clear();
    name.clear();
    unitsBound.text = '1';
    rawSize.clear();
    finishSize.clear();
    purchaseRate.clear();
    salesRate.clear();
    hsn.clear();
    imageBase64 = null;
    logDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    setState(() {});
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) return;
    setState(() => imageBase64 = base64Encode(bytes));
  }

  Future<void> _save() async {
    if (code.text.trim().isEmpty || name.text.trim().isEmpty) return;
    final purchase = double.tryParse(purchaseRate.text) ?? 0;
    final sales = double.tryParse(salesRate.text) ?? 0;
    final row = {
      'product_code': code.text.trim(),
      'product_name': name.text.trim(),
      'unit_id': unitId,
      'material_type_id': materialTypeId,
      'hsn': hsn.text.trim(),
      'rate': sales,
      'purchase_rate': purchase,
      'sales_rate': sales,
      'units_bound': double.tryParse(unitsBound.text) ?? 1,
      'raw_material_size': rawSize.text.trim(),
      'finishing_size': finishSize.text.trim(),
      'image_base64': imageBase64,
      'log_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'status': 'ACTIVE',
    };
    final isNew = editingId == null;
    if (isNew) {
      row['opening_stock'] = 0;
      row['current_stock'] = 0;
      await db.insertProduct(row);
    } else {
      await db.updateProduct(editingId!, row);
    }
    await load();
    _reset();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isNew ? 'MATERIAL MASTER SAVED' : 'MATERIAL MASTER UPDATED')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 260,
          child: Container(
            color: const Color(0xFF1D2739),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('PRODUCT DIRECTORY POOL', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(
                    hintText: 'Search items or tokens...',
                    hintStyle: const TextStyle(fontSize: 10, color: Color(0xFF9AA5B4)),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final p = _filtered[i];
                      final selected = editingId == p['id'];
                      final thumb = p['image_base64'] as String?;
                      return Material(
                        color: selected ? sidebarActiveBg.withOpacity(.2) : Colors.transparent,
                        child: InkWell(
                          onTap: () => _select(p),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: Row(
                              children: [
                                _thumb(thumb),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${p['product_code']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                                      Text('${p['product_name']}', style: const TextStyle(color: Colors.white54, fontSize: 9), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.edit_note, color: Color(0xFFE67E22), size: 18),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(editingId == null ? 'NEW PRODUCT DATA MASTER' : 'MODIFY MASTER REGISTRY',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: navy)),
                    if (editingId != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        color: const Color(0xFFFFE4CC),
                        child: Text('EDITING ID: $editingId', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFE67E22))),
                      ),
                    ],
                    const Spacer(),
                    TextButton(onPressed: _reset, child: const Text('X RESET FIELDS', style: TextStyle(color: red, fontWeight: FontWeight.w800, fontSize: 10))),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: Icon(editingId == null ? Icons.save_outlined : Icons.check, size: 16),
                      label: Text(editingId == null ? 'SAVE MASTER' : 'UPDATE SNAPS', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                      style: ElevatedButton.styleFrom(backgroundColor: navy, foregroundColor: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionTitle('1. SYSTEM IDENTIFICATION PARAMETERS'),
                Align(alignment: Alignment.centerRight, child: Text('Log Compilation System Date: $logDate', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF748094)))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: code, decoration: _fieldDec('Material Code Key (e.g. MAT001) *'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: name, decoration: _fieldDec('Product Name *'))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: unitId,
                        decoration: _fieldDec('UOM Parameter Spec *'),
                        items: units.map((u) => DropdownMenuItem(value: u['id'] as int, child: Text('${u['code']}'))).toList(),
                        onChanged: (v) => setState(() => unitId = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: unitsBound, keyboardType: TextInputType.number, decoration: _fieldDec('Units Conversion Bound Total *'))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: materialTypeId,
                        decoration: _fieldDec('Material Master Type *'),
                        items: materialTypes
                            .map((t) => DropdownMenuItem(value: t['id'] as int, child: Text('${t['type_code']}')))
                            .toList(),
                        onChanged: (v) => setState(() => materialTypeId = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(controller: hsn, decoration: _fieldDec('HSN (for invoicing)')),
                const SizedBox(height: 16),
                _sectionTitle('2. PHYSICAL GEOMETRY DIMENSIONAL MATRIX'),
                Row(
                  children: [
                    Expanded(child: TextField(controller: rawSize, decoration: _fieldDec('Raw Material Size (e.g. 100MM)'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: finishSize, decoration: _fieldDec('Finishing Size (e.g. 98MM)'))),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionTitle('3. COMMERCIAL VALUATION METRICS'),
                Row(
                  children: [
                    Expanded(child: TextField(controller: purchaseRate, keyboardType: TextInputType.number, decoration: _fieldDec('Purchase Rate (₹) *'))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: salesRate,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: green, fontWeight: FontWeight.w800),
                        decoration: _fieldDec('Sales Rate (₹) *'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionTitle('4. PRODUCT IMAGE CONTROL'),
                InkWell(
                  onTap: _pickImage,
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F7),
                      border: Border.all(color: border),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: imageBase64 != null && imageBase64!.isNotEmpty
                        ? Image.memory(base64Decode(imageBase64!), fit: BoxFit.contain)
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_camera_outlined, size: 36, color: Color(0xFF748094)),
                              SizedBox(height: 8),
                              Text('TAP TO MAP PRODUCT IMAGE BINARY THROUGH FILESTREAM POOL',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF748094)),
                                  textAlign: TextAlign.center),
                            ],
                          ),
                  ),
                ),
                if (imageBase64 != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: () => setState(() => imageBase64 = null), child: const Text('Remove image', style: TextStyle(fontSize: 10))),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumb(String? b64) {
    if (b64 != null && b64.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Image.memory(base64Decode(b64), width: 36, height: 36, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 36,
      height: 36,
      color: const Color(0xFF31445F),
      child: const Icon(Icons.inventory_2_outlined, color: Colors.white38, size: 18),
    );
  }
}

Widget _sectionTitle(String t) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: const Color(0xFFE8ECF0),
      child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: navy)),
    );

InputDecoration _fieldDec(String label) => InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: border)),
    );

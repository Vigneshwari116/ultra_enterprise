import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/ultra_repository.dart';
import '../utils/api_errors.dart';
import '../utils/party_directory.dart';
import '../utils/voucher_display.dart';
import '../widgets/compact_date_picker.dart';
import '../widgets/enterprise_form_fields.dart';
import '../widgets/enterprise_widgets.dart';

enum AccountVoucherKind { receipt, payment, expense, salary }

class AccountVoucherPanel extends StatefulWidget {
  const AccountVoucherPanel({super.key, required this.kind});

  final AccountVoucherKind kind;

  @override
  State<AccountVoucherPanel> createState() => _AccountVoucherPanelState();
}

class _AccountVoucherPanelState extends State<AccountVoucherPanel> {
  final repo = UltraRepository.instance;
  final amountCtrl = TextEditingController();
  final narrationCtrl = TextEditingController();

  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> expenseLedgers = [];

  int? editingId;
  int? partyId;
  int? expenseLedgerId;
  String cashBank = 'CASH';
  String voucherDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool loading = true;
  bool partiesLoading = false;
  bool expenseLedgersLoading = false;
  bool saving = false;

  String get _title => switch (widget.kind) {
        AccountVoucherKind.receipt => 'RECEIPT VOUCHER',
        AccountVoucherKind.payment => 'PAYMENT VOUCHER',
        AccountVoucherKind.expense => 'EXPENSE VOUCHER',
        AccountVoucherKind.salary => 'SALARY VOUCHER',
      };

  String _displayNo(Map<String, dynamic> r) => switch (widget.kind) {
        AccountVoucherKind.receipt => receiptDisplayNo(r),
        AccountVoucherKind.payment => paymentDisplayNo(r),
        AccountVoucherKind.expense => expenseVoucherDisplayNo(r),
        AccountVoucherKind.salary => salaryVoucherDisplayNo(r),
      };

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant AccountVoucherPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) {
      _resetForm();
      load();
    }
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    narrationCtrl.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      if (widget.kind == AccountVoucherKind.receipt) {
        rows = [];
        partiesLoading = true;
        if (mounted) setState(() {});
        customers = await loadCustomersDirectory(repo, snackbarContext: context);
        partiesLoading = false;
        rows = await repo.allReceipts();
      } else if (widget.kind == AccountVoucherKind.payment) {
        rows = [];
        partiesLoading = true;
        if (mounted) setState(() {});
        suppliers = await repo.suppliers();
        partiesLoading = false;
        rows = await repo.allPayments();
      } else if (widget.kind == AccountVoucherKind.expense) {
        rows = [];
        expenseLedgersLoading = true;
        if (mounted) setState(() {});
        expenseLedgers = await repo.expenseLedgers();
        expenseLedgersLoading = false;
        _applyDefaultExpenseLedger();
        rows = await repo.expenseVouchers();
      } else if (widget.kind == AccountVoucherKind.salary) {
        rows = [];
        rows = await repo.salaryVouchers();
      }
    } catch (e) {
      if (mounted) showReadableErrorSnackBar(context, e);
    }
    if (mounted) setState(() => loading = false);
  }

  void _applyDefaultExpenseLedger() {
    if (expenseLedgerId != null) return;
    for (final l in expenseLedgers) {
      final key = '${l['system_key'] ?? ''}'.toUpperCase();
      final name = '${l['name'] ?? ''}'.toLowerCase();
      if (key == 'EXPENSES' || name == 'expenses') {
        expenseLedgerId = parseApiInt(l['id']);
        break;
      }
    }
    expenseLedgerId ??= expenseLedgers.isEmpty ? null : parseApiInt(expenseLedgers.first['id']);
  }

  String _partyLabel(Map<String, dynamic> r) {
    switch (widget.kind) {
      case AccountVoucherKind.receipt:
        final cid = parseApiInt(r['customer_id']);
        for (final c in customers) {
          if (parseApiInt(c['id']) == cid) return '${c['customer_name']}';
        }
        return 'Customer';
      case AccountVoucherKind.payment:
        final sid = parseApiInt(r['supplier_id']);
        for (final s in suppliers) {
          if (parseApiInt(s['id']) == sid) return '${s['supplier_name']}';
        }
        return 'Supplier';
      case AccountVoucherKind.expense:
        return '${r['expense_ledger_name'] ?? r['ledger_name'] ?? 'Expense'}';
      case AccountVoucherKind.salary:
        return 'Salary';
    }
  }

  void _resetForm() {
    editingId = null;
    partyId = null;
    expenseLedgerId = null;
    cashBank = 'CASH';
    voucherDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    amountCtrl.clear();
    narrationCtrl.clear();
  }

  void _loadRow(Map<String, dynamic> r) {
    editingId = parseApiInt(r['id']);
    cashBank = '${r['cash_bank'] ?? 'CASH'}'.toUpperCase();
    if (cashBank != 'BANK') cashBank = 'CASH';
    amountCtrl.text = '${parseApiAmount(r['amount'])}';
    narrationCtrl.text = '${r['narration'] ?? ''}';
    switch (widget.kind) {
      case AccountVoucherKind.receipt:
        voucherDate = '${r['receipt_date'] ?? voucherDate}'.split('T').first;
        partyId = parseApiInt(r['customer_id']);
      case AccountVoucherKind.payment:
        voucherDate = '${r['payment_date'] ?? voucherDate}'.split('T').first;
        partyId = parseApiInt(r['supplier_id']);
      case AccountVoucherKind.expense:
      case AccountVoucherKind.salary:
        voucherDate = '${r['voucher_date'] ?? voucherDate}'.split('T').first;
        expenseLedgerId = parseApiInt(r['expense_ledger_id']);
    }
    setState(() {});
  }

  Future<void> _pickDate() async {
    final picked = await pickCompactDate(
      context,
      initialDate: DateTime.tryParse(voucherDate) ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() => voucherDate = formatIsoDate(picked));
    }
  }

  Future<void> _save() async {
    final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than zero.')),
      );
      return;
    }
    if (widget.kind == AccountVoucherKind.receipt && partyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a customer.')),
      );
      return;
    }
    if (widget.kind == AccountVoucherKind.payment && partyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a supplier.')),
      );
      return;
    }
    if (widget.kind == AccountVoucherKind.expense && expenseLedgerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an expense ledger.')),
      );
      return;
    }

    setState(() => saving = true);
    String? priorDisplay;
    if (editingId != null) {
      final match = rows.where((r) => parseApiInt(r['id']) == editingId);
      if (match.isNotEmpty) priorDisplay = _displayNo(match.first);
    }
    try {
      Map<String, dynamic> saved;
      if (widget.kind == AccountVoucherKind.receipt) {
        final body = {
          'customer_id': partyId,
          'receipt_date': voucherDate,
          'amount': amt,
          'narration': narrationCtrl.text,
          'cash_bank': cashBank,
        };
        if (editingId == null) {
          saved = await repo.saveReceipt(body);
        } else {
          await repo.updateReceipt(editingId!, body);
          saved = {'voucher_no_display': priorDisplay};
        }
      } else if (widget.kind == AccountVoucherKind.payment) {
        final body = {
          'supplier_id': partyId,
          'payment_date': voucherDate,
          'amount': amt,
          'narration': narrationCtrl.text,
          'cash_bank': cashBank,
          'reference_no': '',
        };
        if (editingId == null) {
          saved = await repo.savePayment(body);
        } else {
          await repo.updatePayment(editingId!, body);
          saved = {'voucher_no_display': priorDisplay};
        }
      } else if (widget.kind == AccountVoucherKind.expense) {
        final body = {
          'voucher_date': voucherDate,
          'expense_ledger_id': expenseLedgerId,
          'amount': amt,
          'narration': narrationCtrl.text,
          'cash_bank': cashBank,
        };
        if (editingId == null) {
          saved = await repo.saveExpenseVoucher(body);
        } else {
          await repo.updateExpenseVoucher(editingId!, body);
          saved = {'voucher_no_display': priorDisplay};
        }
      } else {
        final body = {
          'voucher_date': voucherDate,
          'amount': amt,
          'narration': narrationCtrl.text,
          'cash_bank': cashBank,
        };
        if (editingId == null) {
          saved = await repo.saveSalaryVoucher(body);
        } else {
          await repo.updateSalaryVoucher(editingId!, body);
          saved = {'voucher_no_display': priorDisplay};
        }
      }
      final display = priorDisplay ?? voucherDisplayNo(saved);
      _resetForm();
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved — $display')),
        );
      }
    } catch (e) {
      if (mounted) showReadableErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete voucher?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      switch (widget.kind) {
        case AccountVoucherKind.receipt:
          await repo.deleteReceipt(id);
        case AccountVoucherKind.payment:
          await repo.deletePayment(id);
        case AccountVoucherKind.expense:
          await repo.deleteExpenseVoucher(id);
        case AccountVoucherKind.salary:
          await repo.deleteSalaryVoucher(id);
      }
      if (editingId == id) _resetForm();
      await load();
    } catch (e) {
      if (mounted) showReadableErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ACCOUNTS', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF748094))),
          Text(_title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: navy)),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _formCard(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _listCard(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            enterpriseInsetDropdown<String>(
              label: 'CASH / BANK',
              value: cashBank,
              items: const [
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                DropdownMenuItem(value: 'BANK', child: Text('Bank')),
              ],
              onChanged: (v) => setState(() => cashBank = v ?? 'CASH'),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDate,
              child: enterpriseInsetFieldShell(
                label: 'VOUCHER DATE',
                child: Text(voucherDate, style: enterpriseInsetValueStyle),
              ),
            ),
            const SizedBox(height: 10),
            if (widget.kind == AccountVoucherKind.receipt) ...[
              enterpriseInsetDropdown<int>(
                label: 'CUSTOMER *',
                value: partyId,
                items: customers
                    .map((c) => DropdownMenuItem(
                          value: parseApiInt(c['id']),
                          child: Text('${c['customer_name']}'),
                        ))
                    .whereType<DropdownMenuItem<int>>()
                    .toList(),
                onChanged: partiesLoading ? null : (v) => setState(() => partyId = v),
              ),
              partyDirectoryStatus(loading: partiesLoading, isCustomer: true, itemCount: customers.length),
            ],
            if (widget.kind == AccountVoucherKind.payment) ...[
              enterpriseInsetDropdown<int>(
                label: 'SUPPLIER *',
                value: partyId,
                items: suppliers
                    .map((s) => DropdownMenuItem(
                          value: parseApiInt(s['id']),
                          child: Text('${s['supplier_name']}'),
                        ))
                    .whereType<DropdownMenuItem<int>>()
                    .toList(),
                onChanged: partiesLoading ? null : (v) => setState(() => partyId = v),
              ),
              partyDirectoryStatus(loading: partiesLoading, isCustomer: false, itemCount: suppliers.length),
            ],
            if (widget.kind == AccountVoucherKind.expense) ...[
              enterpriseInsetDropdown<int>(
                label: 'EXPENSE LEDGER *',
                value: expenseLedgerId,
                items: expenseLedgers
                    .map((l) => DropdownMenuItem(
                          value: parseApiInt(l['id']),
                          child: Text('${l['name']}'),
                        ))
                    .whereType<DropdownMenuItem<int>>()
                    .toList(),
                onChanged: expenseLedgersLoading ? null : (v) => setState(() => expenseLedgerId = v),
              ),
              if (expenseLedgersLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else if (expenseLedgers.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('No expense ledgers found', style: TextStyle(fontSize: 10, color: Color(0xFF748094))),
                ),
            ],
            const SizedBox(height: 10),
            enterpriseInsetTextField(
              label: 'AMOUNT *',
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 10),
            enterpriseInsetTextField(
              label: 'NARRATION',
              controller: narrationCtrl,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: saving ? null : _save,
              child: Text(saving ? 'SAVING…' : (editingId == null ? 'SAVE' : 'UPDATE')),
            ),
            if (editingId != null)
              TextButton(onPressed: _resetForm, child: const Text('Cancel edit')),
          ],
        ),
      ),
    );
  }

  Widget _listCard() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (rows.isEmpty) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('No vouchers yet.', style: TextStyle(color: Color(0xFF748094))),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final r = rows[i];
          final id = parseApiInt(r['id']) ?? 0;
          final date = switch (widget.kind) {
            AccountVoucherKind.receipt => r['receipt_date'],
            AccountVoucherKind.payment => r['payment_date'],
            _ => r['voucher_date'],
          };
          return ListTile(
            title: Text(_displayNo(r), style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              '${date ?? ''} · ${_partyLabel(r)} · ₹${parseApiAmount(r['amount']).toStringAsFixed(2)} · ${r['cash_bank'] ?? 'CASH'}',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _loadRow(r)),
                IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: red), onPressed: () => _delete(id)),
              ],
            ),
          );
        },
      ),
    );
  }
}

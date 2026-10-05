import 'package:flutter/material.dart';

import '../models/company_settings.dart';
import '../services/ultra_repository.dart';
import '../widgets/enterprise_form_fields.dart';
import '../widgets/enterprise_widgets.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final repo = UltraRepository.instance;
  bool loading = true;
  bool saving = false;

  final companyName = TextEditingController();
  final tagline = TextEditingController();
  final officeAddress = TextEditingController();
  final worksAddress = TextEditingController();
  final teleFax = TextEditingController();
  final mobile = TextEditingController();
  final gstin = TextEditingController();
  final serviceTaxNo = TextEditingController();
  final bankName = TextEditingController();
  final bankAccount = TextEditingController();
  final ifsc = TextEditingController();
  final branch = TextEditingController();
  final terms = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await repo.companySettings();
    companyName.text = s.companyName;
    tagline.text = s.tagline;
    officeAddress.text = s.officeAddress;
    worksAddress.text = s.worksAddress;
    teleFax.text = s.teleFax;
    mobile.text = s.mobile;
    gstin.text = s.gstin;
    serviceTaxNo.text = s.serviceTaxNo;
    bankName.text = s.bankName;
    bankAccount.text = s.bankAccountNo;
    ifsc.text = s.ifscCode;
    branch.text = s.branch;
    terms.text = s.terms.join('\n');
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    for (final c in [
      companyName,
      tagline,
      officeAddress,
      worksAddress,
      teleFax,
      mobile,
      gstin,
      serviceTaxNo,
      bankName,
      bankAccount,
      ifsc,
      branch,
      terms,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => saving = true);
    final termLines = terms.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    await repo.saveCompanySettings(CompanySettings(
      companyName: companyName.text.trim(),
      tagline: tagline.text.trim(),
      officeAddress: officeAddress.text.trim(),
      worksAddress: worksAddress.text.trim(),
      teleFax: teleFax.text.trim(),
      mobile: mobile.text.trim(),
      gstin: gstin.text.trim(),
      serviceTaxNo: serviceTaxNo.text.trim(),
      bankName: bankName.text.trim(),
      bankAccountNo: bankAccount.text.trim(),
      ifscCode: ifsc.text.trim(),
      branch: branch.text.trim(),
      terms: termLines.isEmpty ? defaultCompanyTerms : termLines,
    ));
    if (mounted) {
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company settings saved.')),
      );
    }
  }

  Widget _field(String label, TextEditingController c, {int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: enterpriseInsetTextField(
        label: label,
        controller: c,
        maxLines: lines,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COMPANY & INVOICE PRINT SETTINGS',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF10233F)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Values appear on tax invoices, delivery challans, quotations and purchase documents.',
            style: TextStyle(fontSize: 9, color: Color(0xFF748094)),
          ),
          const SizedBox(height: 16),
          _field('COMPANY NAME', companyName),
          _field('TAGLINE / SUBTITLE', tagline),
          _field('OFFICE ADDRESS', officeAddress, lines: 3),
          _field('WORKS ADDRESS', worksAddress, lines: 3),
          _field('TELE FAX', teleFax),
          _field('MOBILE', mobile),
          _field('COMPANY GSTIN', gstin),
          _field('SERVICE TAX NO.', serviceTaxNo),
          const SizedBox(height: 8),
          const Text('BANK DETAILS (PRINTED ON INVOICE)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
          const SizedBox(height: 8),
          _field('BANK NAME', bankName),
          _field('ACCOUNT NO', bankAccount),
          _field('IFS CODE', ifsc),
          _field('BRANCH', branch),
          _field('TERMS & CONDITIONS (ONE LINE PER POINT)', terms, lines: 8),
          const SizedBox(height: 8),
          PrimaryButton(
            label: saving ? 'SAVING…' : 'SAVE COMPANY SETTINGS',
            onPressed: saving ? () {} : _save,
          ),
        ],
      ),
    );
  }
}

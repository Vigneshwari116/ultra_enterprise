/// Printable company profile stored in local settings (single row).
class CompanySettings {
  final String companyName;
  final String tagline;
  final String officeAddress;
  final String worksAddress;
  final String teleFax;
  final String mobile;
  final String gstin;
  final String serviceTaxNo;
  final String bankName;
  final String bankAccountNo;
  final String ifscCode;
  final String branch;
  final List<String> terms;

  const CompanySettings({
    this.companyName = '',
    this.tagline = '',
    this.officeAddress = '',
    this.worksAddress = '',
    this.teleFax = '',
    this.mobile = '',
    this.gstin = '',
    this.serviceTaxNo = '',
    this.bankName = '',
    this.bankAccountNo = '',
    this.ifscCode = '',
    this.branch = '',
    this.terms = defaultCompanyTerms,
  });

  factory CompanySettings.fromMap(Map<String, dynamic>? row) {
    if (row == null || row.isEmpty) return const CompanySettings();
    final termsRaw = row['terms_json'];
    List<String> terms = defaultCompanyTerms;
    if (termsRaw is String && termsRaw.trim().isNotEmpty) {
      try {
        final decoded = termsRaw
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (decoded.isNotEmpty) terms = decoded;
      } catch (_) {}
    }
    return CompanySettings(
      companyName: '${row['company_name'] ?? ''}',
      tagline: '${row['tagline'] ?? ''}',
      officeAddress: '${row['office_address'] ?? ''}',
      worksAddress: '${row['works_address'] ?? ''}',
      teleFax: '${row['tele_fax'] ?? ''}',
      mobile: '${row['mobile'] ?? ''}',
      gstin: '${row['gstin'] ?? ''}',
      serviceTaxNo: '${row['service_tax_no'] ?? ''}',
      bankName: '${row['bank_name'] ?? ''}',
      bankAccountNo: '${row['bank_account_no'] ?? ''}',
      ifscCode: '${row['ifsc_code'] ?? ''}',
      branch: '${row['branch'] ?? ''}',
      terms: terms,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': 1,
        'company_name': companyName,
        'tagline': tagline,
        'office_address': officeAddress,
        'works_address': worksAddress,
        'tele_fax': teleFax,
        'mobile': mobile,
        'gstin': gstin,
        'service_tax_no': serviceTaxNo,
        'bank_name': bankName,
        'bank_account_no': bankAccountNo,
        'ifsc_code': ifscCode,
        'branch': branch,
        'terms_json': terms.join('\n'),
      };
}

/// Editable in one place; persisted via company settings when saved.
const List<String> defaultCompanyTerms = [
  '1. Good once sold will not be taken back or exchanged.',
  '2. Interest @24% will be charged if not paid within the due period.',
  '3. All Disputes Subject to Bangalore Jurisdiction Only.',
  '4. All Payment Should Be Made By A/c Payee Cheque/D.D Only',
  '5. Our Risk/Responsibility Ceases Once Goods Leave Our Premises',
];

import '../config/company_settings_defaults.dart';

/// Printable company profile stored locally and synced from the server API.
class CompanySettings {
  final String companyName;
  final String tagline;
  final List<String> headerLines;
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
  final int settingsRevision;

  const CompanySettings({
    this.companyName = '',
    this.tagline = '',
    this.headerLines = const [],
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
    this.terms = CompanySettingsDefaults.terms,
    this.settingsRevision = 0,
  });

  List<String> get effectiveHeaderLines {
    if (headerLines.isNotEmpty) return headerLines;
    if (officeAddress.isNotEmpty || worksAddress.isNotEmpty) {
      return [
        if (officeAddress.isNotEmpty) officeAddress,
        if (worksAddress.isNotEmpty) worksAddress,
      ];
    }
    return CompanySettingsDefaults.headerLines;
  }

  factory CompanySettings.fromMap(Map<String, dynamic>? row) {
    if (row == null || row.isEmpty) return CompanySettings.withDefaults();
    final headerRaw = '${row['header_lines'] ?? ''}'.trim();
    final headerLines = headerRaw.isEmpty
        ? <String>[]
        : headerRaw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    List<String> terms = CompanySettingsDefaults.terms;
    final termsRaw = row['terms_json'];
    if (termsRaw is String && termsRaw.trim().isNotEmpty) {
      final decoded = termsRaw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (decoded.isNotEmpty) terms = decoded;
    }

    return CompanySettings(
      companyName: '${row['company_name'] ?? ''}',
      tagline: '${row['tagline'] ?? ''}',
      headerLines: headerLines,
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
      settingsRevision: (row['settings_revision'] as num?)?.toInt() ?? 0,
    ).withDefaults();
  }

  factory CompanySettings.withDefaults() {
    return const CompanySettings().withDefaults();
  }

  CompanySettings withDefaults() {
    String def(String v, String d) => v.trim().isEmpty ? d : v.trim();
    return CompanySettings(
      companyName: def(companyName, CompanySettingsDefaults.companyName),
      tagline: def(tagline, CompanySettingsDefaults.tagline),
      headerLines: headerLines.isEmpty ? CompanySettingsDefaults.headerLines : headerLines,
      officeAddress: officeAddress,
      worksAddress: worksAddress,
      teleFax: teleFax,
      mobile: mobile,
      gstin: def(gstin, CompanySettingsDefaults.gstin),
      serviceTaxNo: def(serviceTaxNo, CompanySettingsDefaults.serviceTaxNo),
      bankName: bankName,
      bankAccountNo: bankAccountNo,
      ifscCode: ifscCode,
      branch: branch,
      terms: terms.isEmpty ? CompanySettingsDefaults.terms : terms,
      settingsRevision: settingsRevision,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': 1,
        'company_name': companyName,
        'tagline': tagline,
        'header_lines': effectiveHeaderLines.join('\n'),
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
        'settings_revision': settingsRevision,
      };
}

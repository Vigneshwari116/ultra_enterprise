/// Single source for seeded company settings (not duplicated in invoice.dart).
class CompanySettingsDefaults {
  static const companyName = 'ULTRA ENGINEERING WORKS';
  static const tagline = 'SPM MANUFACTURERS & FABRICATORS';

  /// Five header lines exactly as on the reference (correct spelling).
  static const headerLines = [
    'OFFICE:NO:15/6,5th CROSS ,VIDYA NAGAR,S.K.F.FACTORY',
    'BOMMASANDRA INDL.AREA,BENGALURU-560 099.',
    'Tele Fax:080-27834287, Mob: 9342509313',
    'Works:No.B-48,KSSIDC INDL Estate,Near',
    'Karnataka Bank,Bommasandra Indl.Area,BENGALURU-560 099.',
  ];

  static const gstin = '29AHOPK6473G1ZS';
  static const serviceTaxNo = 'AHOPK6473GSD001';

  static const terms = [
    '1. Goods once sold will not be taken back or exchanged.',
    '2. Interest @24% will be charged if not paid within the due period.',
    '3. All disputes subject to Bangalore jurisdiction only.',
    '4. All payments should be made by A/c payee cheque/D.D only.',
    '5. Our risk/responsibility ceases once goods leave our premises.',
  ];

  static Map<String, dynamic> seedRow() => {
        'id': 1,
        'company_name': companyName,
        'tagline': tagline,
        'header_lines': headerLines.join('\n'),
        'office_address': headerLines[0],
        'works_address': '${headerLines[3]}\n${headerLines[4]}',
        'tele_fax': '080-27834287',
        'mobile': '9342509313',
        'gstin': gstin,
        'service_tax_no': serviceTaxNo,
        'bank_name': '',
        'bank_account_no': '',
        'ifsc_code': '',
        'branch': '',
        'terms_json': terms.join('\n'),
        'settings_revision': 1,
      };

  static const legacyTermTypos = [
    'Good once sold',
    'Reponsebility',
    'Judrisdiction',
    'with inthe due period',
    'A\\c',
    'KarnatakaBank',
  ];
}

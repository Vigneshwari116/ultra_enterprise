/// Fixed company identity and banking details for all ULTRA print formats.
class UltraCompanyConstants {
  static const String legalName = 'ULTRA ENGINEERING WORKS';
  static const String tagline = 'SPM MANUFACTURERS & FABRICATORS';

  /// Tax / labour bill header (regular_bill.pdf line breaks).
  static const String billOfficeLine1 =
      'OFFICE:NO: 15/6, 5th CROSS, VIDYA NAGAR, OPP. S.K.F. FACTORY,';
  static const String billOfficeLine2 =
      'Hosur Road, BOMMASANDRA INDL. AREA, BENGALURU-560 099.';
  static const String billContactLine =
      'Tele Fax: 080-27834287, Mob: 9342509313 Email: ueworks@gmail.com';
  static const String billWorksLine =
      'Works: No.B-48, KSSIDC INDL Estate, Near Karnataka Bank, Bommasandra Indl. Area, BENGALURU-560 099.';

  /// Delivery challan header (dc_sample.pdf — no SPM tagline).
  static const String dcOfficeLine1 =
      'OFFICE:NO: 15/6, 5th CROSS, VIDYA NAGAR, OPP. S.K.F. FACTORY,';
  static const String dcOfficeLine2 =
      'Hosur Road, BOMMASANDRA INDL. AREA, BENGALURU-560 099.';
  static const String dcContactLine =
      'Tele Fax: 080-27834287, Mob:9342408610 Email: ueworks@gmail.com';
  static const String dcWorksLine =
      'Works: No.B-48,KSSIDC INDL Estate,Near Karnataka Bank,Bommasandra Indl.Area,BENGALURU-560 099.';

  @Deprecated('Use billOfficeLine1/2 for invoices')
  static const String officeAddressLine = billOfficeLine1;
  @Deprecated('Use billContactLine')
  static const String contactLine = billContactLine;
  @Deprecated('Use billWorksLine')
  static const String worksAddressLine = billWorksLine;

  static const String gstin = '29AHOPK6473G1ZS';
  static const String serviceTaxNo = 'AHOPK6473GSD001';
  static const String tanNo = 'BLRK06993A';

  static const String bankName = 'STATE BANK OF INDIA';
  static const String bankAccountNo = '54009859972';
  static const String bankIfsc = 'SBIN0040552';
  static const String bankBranch = 'SINGASANDRA';
}

/// Single original copy label on tax / labour bills (matches paper samples).
const List<String> ultraSalesBillCopyLabels = ['ORIGINAL FOR BUYER'];

const List<String> ultraNormalBillTerms = [
  '1.Good once sold will not be taken back or exchange',
  '2.Interest @24% will be charged if not paid with inthe due period.',
  '3.All Disputes Subject to Bangalore Judrisdiction Only.',
  '4.All Payment Should Be Made By A\\c Payee Cheque/D.D Only',
  '5.Our Risk/Reponsebility Ceases Once Goods Leave Our Premises',
];

const List<String> ultraLabourBillTerms = [
  '1.Good once sold will not be taken back or exchange',
  '2.Interest @24% will be charged if not paid with inthe due period.',
  '3.All Disputes Subject to Bangalore Judrisdiction Only.',
  '4.This is a Job Work service bill as per gst provisions',
];

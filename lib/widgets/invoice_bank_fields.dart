import '../models/company_settings.dart';

class InvoiceBankFields {
  final String bankName;
  final String accountNo;
  final String ifscCode;
  final String branch;

  const InvoiceBankFields({
    this.bankName = '',
    this.accountNo = '',
    this.ifscCode = '',
    this.branch = '',
  });
}

/// Priority: document snapshot → company settings → blank.
InvoiceBankFields resolveInvoiceBank({
  Map<String, dynamic>? documentRow,
  required CompanySettings company,
}) {
  String pick(String docKey, String companyVal) {
    final fromDoc = '${documentRow?[docKey] ?? ''}'.trim();
    if (fromDoc.isNotEmpty) return fromDoc;
    return companyVal.trim();
  }

  return InvoiceBankFields(
    bankName: pick('print_bank_name', company.bankName),
    accountNo: pick('print_bank_account_no', company.bankAccountNo),
    ifscCode: pick('print_ifsc_code', company.ifscCode),
    branch: pick('print_branch', company.branch),
  );
}

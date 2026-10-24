import 'package:flutter_test/flutter_test.dart';
import 'package:ultra_enterprise/config/ultra_company_constants.dart';
import 'package:ultra_enterprise/widgets/invoice.dart';

import 'pdf_document_layout_test.dart';

const _longConsignee =
    'SUPRAJIT ENGINEERING LIMITED UNIT-2 — HYDRAULIC CYLINDER AND PRECISION MACHINING DIVISION';
const _longDescription =
    'Fabricated stub shaft with induction hardened bearing journal, ground to 12.5 microns Ra, '
    'including material test certificate and third-party dimensional report per customer drawing';

InvoiceItem _stressItem() => InvoiceItem(
      description: _longDescription,
      hsnCode: '8471',
      qty: 10,
      price: 1250.5,
      remarks: 'Handle with care — heavy',
    );

InvoiceData _normalBillStress() => InvoiceData(
      kind: UltraBillKind.taxInvoice,
      salesBillType: UltraSalesBillType.normal,
      documentTitle: 'TAX INVOICE',
      copyLabels: ultraSalesBillCopyLabels,
      invoiceNo: '208',
      date: '12-Oct-26',
      custPo: '4500123456',
      poDate: '10-Oct-26',
      dcNo: '338',
      dcDate: '11-Oct-26',
      dispatch: 'KA50B2331',
      ewbNo: '291234567890',
      consigneeName: _longConsignee,
      consigneeAddress: 'Plot 42, Bommasandra Industrial Area, Phase II',
      consigneeCityLine: 'Bengaluru - 560099',
      gstin: '29AACCC5171H1ZM',
      mobile: '9876543210',
      selDcNo: '',
      selDcDate: '',
      items: [_stressItem()],
      pAndF: 850,
      cgstAmountOverride: 2362.59,
      sgstAmountOverride: 2362.59,
      igstAmountOverride: 0,
      grandTotalOverride: 30975.68,
      amountInWords: 'THIRTY THOUSAND NINE HUNDRED SEVENTY SIX ONLY',
      bankName: UltraCompanyConstants.bankName,
      accountNo: UltraCompanyConstants.bankAccountNo,
      ifscCode: UltraCompanyConstants.bankIfsc,
      bankAddress: UltraCompanyConstants.bankBranch,
      leftSignatureLabel: 'Receiver signature & Seal',
    );

InvoiceData _labourBillStress() => InvoiceData(
      kind: UltraBillKind.taxInvoice,
      salesBillType: UltraSalesBillType.labour,
      documentTitle: 'LABOUR BILL - JOB WORK SERVICE INVOICE',
      copyLabels: ultraSalesBillCopyLabels,
      invoiceNo: '209',
      date: '28 September 2026',
      selDcNo: 'SEL-9921',
      selDcDate: '20-Sep-26',
      dcNo: '338',
      dcDate: '18-Sep-26',
      dispatch: '',
      ewbNo: '',
      consigneeName: _longConsignee,
      consigneeAddress: 'Plot 42, Bommasandra Industrial Area, Phase II',
      shippingName: _longConsignee,
      shippingAddress: 'Same as billing — gate 3 inward',
      gstin: '29AACCC5171H1ZM',
      mobile: '9876543210',
      items: [
        InvoiceItem(
          description: _longDescription,
          hsnCode: '',
          qty: 1,
          price: 18500,
        ),
      ],
      cgstAmountOverride: 1665,
      sgstAmountOverride: 1665,
      igstAmountOverride: 0,
      grandTotalOverride: 21830,
      amountInWords: 'TWENTY ONE THOUSAND EIGHT HUNDRED THIRTY ONLY',
      bankName: UltraCompanyConstants.bankName,
      accountNo: UltraCompanyConstants.bankAccountNo,
      ifscCode: UltraCompanyConstants.bankIfsc,
      bankAddress: UltraCompanyConstants.bankBranch,
      leftSignatureLabel: 'Receiver signature & Seal',
    );

InvoiceData _proformaStress() => InvoiceData(
      kind: UltraBillKind.deliveryChallan,
      salesBillType: UltraSalesBillType.proforma,
      documentTitle: 'PROFORMA INVOICE',
      copyLabels: ultraSalesBillCopyLabels,
      invoiceNo: 'PF-1024',
      date: '12-Oct-26',
      custPo: '4500123456',
      poDate: '10-Oct-26',
      dcNo: '338',
      dcDate: '11-Oct-26',
      dispatch: 'KA50B2331',
      ewbNo: '291234567890',
      consigneeName: _longConsignee,
      consigneeAddress: 'Plot 42, Bommasandra Industrial Area, Phase II',
      consigneeCityLine: 'Bengaluru - 560099',
      gstin: '29AACCC5171H1ZM',
      mobile: '9876543210',
      items: [_stressItem()],
      pAndF: 500,
      cgstPercent: 0,
      sgstPercent: 0,
      igstPercent: 18,
      cgstAmountOverride: 0,
      sgstAmountOverride: 0,
      igstAmountOverride: 33.12,
      grandTotalOverride: 217.12,
      amountInWords: 'TWO HUNDRED SEVENTEEN ONLY',
      bankName: UltraCompanyConstants.bankName,
      accountNo: UltraCompanyConstants.bankAccountNo,
      ifscCode: UltraCompanyConstants.bankIfsc,
      bankAddress: UltraCompanyConstants.bankBranch,
      leftSignatureLabel: 'Receiver signature & Seal',
    );

InvoiceData _dcStress({required bool inward}) => InvoiceData(
      kind: UltraBillKind.deliveryChallan,
      documentTitle:
          inward ? 'DELIVERY CHALLAN - INWARD' : 'DELIVERY CHALLAN',
      copyLabels: [
        inward ? 'DELIVERY CHALLAN - INWARD' : 'DELIVERY CHALLAN',
      ],
      invoiceNo: '338',
      date: '23-Oct-2026 2:53 pm',
      custPo: 'CUST-DC-7788',
      poDate: '22-Oct-26',
      dcNo: 'PO-9912',
      dcDate: '21-Oct-26',
      dispatch: '0',
      ewbNo: '67777',
      consigneeName: _longConsignee,
      consigneeAddress: 'Plot 42, Bommasandra Industrial Area, Phase II',
      gstin: '29ADHPN6794L1ZL',
      mobile: 'NOT AVAILABLE',
      items: [_stressItem()],
      pAndF: 0,
      grandTotalOverride: 12505,
      amountInWords: 'TWELVE THOUSAND FIVE HUNDRED FIVE ONLY',
      bankName: UltraCompanyConstants.bankName,
      accountNo: UltraCompanyConstants.bankAccountNo,
      ifscCode: UltraCompanyConstants.bankIfsc,
      bankAddress: UltraCompanyConstants.bankBranch,
      forwardingLabel: 'Forwarding',
      totalGrandLabel: 'Total Value',
    );

void main() {
  final cases = <String, InvoiceData>{
    'normal bill': _normalBillStress(),
    'labour bill': _labourBillStress(),
    'proforma': _proformaStress(),
    'DC inward': _dcStress(inward: true),
    'DC outward': _dcStress(inward: false),
  };

  for (final entry in cases.entries) {
    test('${entry.key} PDF builds one page without layout exception', () async {
      final bytes = await buildUltraInvoicePdf(entry.value);
      expect(bytes, isNotEmpty);
      expect(pdfPageCount(bytes), 1);
    });
  }
}

import 'package:ultra_enterprise/config/ultra_company_constants.dart';
import 'package:ultra_enterprise/widgets/invoice.dart';

/// Consignee block from docs/bill_formats/regular_bill.pdf (invoice 224).
const String billSampleSuprajitName = 'SUPRAJIT ENGINEERING LIMITED UNIT-2';
const String billSampleSuprajitAddress =
    '#189A & 189B, BOMMASANDRA INDL AREA, BOMMASANDRA';
const String billSampleSuprajitCityLine = 'BANGALORE - 560 099';
const String billSampleSuprajitGstin = '29AADCS1638L1Z0';
const String billSampleSuprajitMobile = '9845012345';

/// Line items from docs/bill_formats/regular_bill.pdf.
List<InvoiceItem> regularBill224Items() => [
      InvoiceItem(
        description:
            'CUTTING AND FORMING MACHINE BLADE SET\nWITH HSS TEETH AND MOUNTING HARDWARE',
        hsnCode: '7308',
        qty: 3,
        price: 4860,
      ),
      InvoiceItem(
        description: 'GRIPPER SET',
        hsnCode: '7308',
        qty: 3,
        price: 3900,
      ),
    ];

/// Normal tax invoice 224 (regular_bill.pdf).
InvoiceData normalBillSample() => InvoiceData(
      kind: UltraBillKind.taxInvoice,
      salesBillType: UltraSalesBillType.normal,
      documentTitle: 'TAX INVOICE',
      copyLabels: ultraSalesBillCopyLabels,
      invoiceNo: '224',
      date: '12-Oct-26',
      custPo: 'Mr. Murugesh',
      poDate: '12-Oct-26',
      dcNo: '0',
      dcDate: '12-Oct-26',
      dispatch: 'By HAND',
      ewbNo: '',
      consigneeName: billSampleSuprajitName,
      consigneeAddress: billSampleSuprajitAddress,
      consigneeCityLine: billSampleSuprajitCityLine,
      gstin: billSampleSuprajitGstin,
      mobile: billSampleSuprajitMobile,
      items: regularBill224Items(),
      pAndF: 0,
      cgstAmountOverride: 2365.20,
      sgstAmountOverride: 2365.20,
      igstAmountOverride: 0,
      roundOff: 0,
      grandTotalOverride: 31010.40,
      amountInWords: 'THIRTY ONE THOUSAND TEN ONLY',
      bankName: UltraCompanyConstants.bankName,
      accountNo: UltraCompanyConstants.bankAccountNo,
      ifscCode: UltraCompanyConstants.bankIfsc,
      bankAddress: UltraCompanyConstants.bankBranch,
      leftSignatureLabel: 'Receiver signature & Seal',
    );

/// Labour bill (labour_bill.pdf line item; consignee GSTIN matches regular sample).
InvoiceData labourBillSample() => InvoiceData(
      kind: UltraBillKind.taxInvoice,
      salesBillType: UltraSalesBillType.labour,
      documentTitle: 'LABOUR BILL - JOB WORK SERVICE INVOICE',
      copyLabels: ultraSalesBillCopyLabels,
      invoiceNo: '212',
      date: '28 September 2026',
      selDcNo: '927000483',
      selDcDate: '25 September 2026',
      dcNo: '299',
      dcDate: '28/09/2026',
      dispatch: 'KA35D2463',
      ewbNo: '',
      consigneeName: billSampleSuprajitName,
      consigneeAddress: billSampleSuprajitAddress,
      consigneeCityLine: billSampleSuprajitCityLine,
      shippingName: billSampleSuprajitName,
      shippingAddress:
          '#101, BOMMASANDRA INDL. AREA, HOSUR ROAD, BANGALORE - 560 099',
      gstin: billSampleSuprajitGstin,
      mobile: billSampleSuprajitMobile,
      items: [
        InvoiceItem(
          description:
              'MATERIAL NO: COM-CCI-00430 JOB WORK SERVICE CHARGES FOR WELDING '
              'INNER DIA 9.5MM 56 STRANDS [SEL9/102/170] AKK11424 - WELDING & '
              'RETURNED',
          hsnCode: '',
          qty: 900,
          price: 14.40,
        ),
      ],
      cgstAmountOverride: 1166.40,
      sgstAmountOverride: 1166.40,
      igstAmountOverride: 0,
      roundOff: 0,
      grandTotalOverride: 15292.80,
      amountInWords: 'FIFTEEN THOUSAND TWO HUNDRED AND NINETY THREE ONLY',
      bankName: UltraCompanyConstants.bankName,
      accountNo: UltraCompanyConstants.bankAccountNo,
      ifscCode: UltraCompanyConstants.bankIfsc,
      bankAddress: UltraCompanyConstants.bankBranch,
      leftSignatureLabel: 'Receiver signature & Seal',
    );

/// Proforma based on invoice 224 party and lines (inter-state IGST example).
InvoiceData proformaSample() => InvoiceData(
      kind: UltraBillKind.deliveryChallan,
      salesBillType: UltraSalesBillType.proforma,
      documentTitle: 'PROFORMA INVOICE',
      copyLabels: ultraSalesBillCopyLabels,
      invoiceNo: '224',
      date: '12-Oct-26',
      custPo: 'Mr. Murugesh',
      poDate: '12-Oct-26',
      dcNo: '338',
      dcDate: '12-Oct-26',
      dispatch: 'By HAND',
      ewbNo: '',
      consigneeName: billSampleSuprajitName,
      consigneeAddress: billSampleSuprajitAddress,
      consigneeCityLine: billSampleSuprajitCityLine,
      gstin: billSampleSuprajitGstin,
      mobile: billSampleSuprajitMobile,
      items: regularBill224Items(),
      pAndF: 0,
      cgstPercent: 0,
      sgstPercent: 0,
      igstPercent: 18,
      cgstAmountOverride: 0,
      sgstAmountOverride: 0,
      igstAmountOverride: 4730.40,
      roundOff: 0,
      grandTotalOverride: 31010.40,
      amountInWords: 'THIRTY ONE THOUSAND TEN ONLY',
      bankName: UltraCompanyConstants.bankName,
      accountNo: UltraCompanyConstants.bankAccountNo,
      ifscCode: UltraCompanyConstants.bankIfsc,
      bankAddress: UltraCompanyConstants.bankBranch,
      leftSignatureLabel: 'Receiver signature & Seal',
    );

/// Delivery challan party and lines from docs/bill_formats/dc_sample.pdf.
InvoiceData dcSample({required bool inward}) => InvoiceData(
      kind: UltraBillKind.deliveryChallan,
      documentTitle:
          inward ? 'DELIVERY CHALLAN - INWARD' : 'DELIVERY CHALLAN',
      copyLabels: [
        inward ? 'DELIVERY CHALLAN - INWARD' : 'DELIVERY CHALLAN',
      ],
      invoiceNo: '338',
      date: '23-Oct-2026 2:53 pm',
      custPo: '0',
      poDate: '23-10-2026',
      dcNo: '0',
      dcDate: '23-10-2026',
      dispatch: '',
      ewbNo: '',
      consigneeName: 'DHOOT TRANSMISSION PVT LTD P1 HOSUR',
      consigneeAddress:
          'PLOT NO.5 S. NOS 738/2, 739A/2 # 3, 737 POONAPALLI VILLAGE, '
          'HOSUR TALUK, KRISHNAGIRI DIST, 635110',
      gstin: '',
      mobile: '',
      items: [
        InvoiceItem(
          description: 'PIN PRESSING FIXTURE',
          hsnCode: '',
          qty: 1,
          price: 0,
          remarks: 'NEW',
        ),
        InvoiceItem(
          description: '350x350MM PLATE - 8MM THICKNESS',
          hsnCode: '',
          qty: 1,
          price: 0,
          remarks: 'NEW',
        ),
      ],
      pAndF: 0,
      grandTotalOverride: 0,
      amountInWords: '',
      bankName: UltraCompanyConstants.bankName,
      accountNo: UltraCompanyConstants.bankAccountNo,
      ifscCode: UltraCompanyConstants.bankIfsc,
      bankAddress: UltraCompanyConstants.bankBranch,
      forwardingLabel: 'Forwarding',
      totalGrandLabel: 'Total Value',
    );

/// Purchase order sample. Supplier mobile is printed on the GSTIN row.
InvoiceData purchaseOrderPdfSample() => InvoiceData(
      kind: UltraBillKind.purchaseOrder,
      documentTitle: 'PURCHASE ORDER',
      partySectionTitle: 'NAME & ADDRESS OF SUPPLIER',
      copyLabels: ultraDocumentCopyLabels,
      invoiceNo: 'PO-2026-291330',
      date: '06-10-2026',
      custPo: 'SUP-REF-18',
      poDate: '20-10-2026',
      dcNo: '4',
      dispatch: 'Road',
      ewbNo:
          'Deliver to the stores gate. Call the purchase desk before unloading the crates.',
      consigneeName: 'SUPRAJIT ENGINEERING LIMITED UNIT-2',
      consigneeAddress:
          '#189A & 189B, BOMMASANDRA INDL AREA, BOMMASANDRA, BANGALORE - 560 099',
      gstin: '29AADCS1638L1Z0',
      mobile: '9845012345',
      items: [
        InvoiceItem(
          description: 'HSS BLADE SET',
          hsnCode: '8202',
          qty: 2,
          price: 1500,
        ),
      ],
      pAndF: 100,
      forwardingLabel: 'Estimated Freight',
      totalGrandLabel: 'Total Value',
      cgstPercent: 9,
      sgstPercent: 9,
      igstPercent: 0,
      cgstAmountOverride: 270,
      sgstAmountOverride: 270,
      igstAmountOverride: 0,
      roundOff: 0,
      grandTotalOverride: 3640,
      amountInWords: 'THREE THOUSAND SIX HUNDRED FORTY RUPEES ONLY',
      bankName: UltraCompanyConstants.bankName,
      accountNo: UltraCompanyConstants.bankAccountNo,
      ifscCode: UltraCompanyConstants.bankIfsc,
      bankAddress: UltraCompanyConstants.bankBranch,
      leftSignatureLabel: 'Receiver signature & Seal',
    );

/// Purchase voucher sample (voucher 261). Same supplier mobile as the PO.
InvoiceData purchaseVoucherPdfSample() => InvoiceData(
      kind: UltraBillKind.purchaseVoucher,
      documentTitle: 'PURCHASE VOUCHER',
      partySectionTitle: 'NAME & ADDRESS OF SUPPLIER',
      copyLabels: ultraDocumentCopyLabels,
      invoiceNo: '261',
      date: '06-10-2026',
      custPo: 'INV-8841',
      poDate: '05-10-2026',
      dcNo: 'PO-2026-291330',
      dcDate: '01-10-2026',
      dispatch: '',
      ewbNo: '',
      consigneeName: 'SUPRAJIT ENGINEERING LIMITED UNIT-2',
      consigneeAddress:
          '#189A & 189B, BOMMASANDRA INDL AREA, BOMMASANDRA, BANGALORE - 560 099',
      gstin: '29AADCS1638L1Z0',
      mobile: '9845012345',
      items: [
        InvoiceItem(
          description: 'HSS BLADE SET',
          hsnCode: '8202',
          qty: 2,
          price: 1500,
        ),
      ],
      cgstPercent: 9,
      sgstPercent: 9,
      igstPercent: 0,
      cgstAmountOverride: 270,
      sgstAmountOverride: 270,
      igstAmountOverride: 0,
      roundOff: 0,
      grandTotalOverride: 3540,
      totalGrandLabel: 'Total Value',
      amountInWords: 'THREE THOUSAND FIVE HUNDRED FORTY RUPEES ONLY',
      bankName: UltraCompanyConstants.bankName,
      accountNo: UltraCompanyConstants.bankAccountNo,
      ifscCode: UltraCompanyConstants.bankIfsc,
      bankAddress: UltraCompanyConstants.bankBranch,
      leftSignatureLabel: 'Receiver signature & Seal',
    );

import 'package:postgres/postgres.dart';
import 'package:shelf_router/shelf_router.dart';

import 'routes/adjustment_notes.dart';
import 'routes/cash_transactions.dart';
import 'routes/delivery_challans.dart';
import 'routes/journal.dart';
import 'routes/ledger.dart';
import 'routes/masters.dart';
import 'routes/material_types.dart';
import 'routes/products.dart';
import 'routes/purchase_orders.dart';
import 'routes/purchase_vouchers.dart';
import 'routes/quotations.dart';
import 'routes/sales_invoices.dart';
import 'routes/units.dart';

/// Registers **missing** REST routes for merge into the existing VPS `ultra_server`.
void registerMergedRoutes(Router router, Connection conn) {
  registerSalesInvoiceRoutes(router, conn);
  registerPurchaseVoucherRoutes(router, conn);
  registerCustomerSupplierRoutes(router, conn);
  registerPurchaseOrderRoutes(router, conn);
  registerQuotationRoutes(router, conn);
  registerDeliveryChallanRoutes(router, conn);
  registerCashTransactionRoutes(router, conn);
  registerJournalRoutes(router, conn);
  registerLedgerRoutes(router, conn);
  registerAdjustmentNoteRoutes(router, conn);
  registerMaterialTypeRoutes(router, conn);
  registerUnitRoutes(router, conn);
  registerProductRoutes(router, conn);
}

# ULTRA — Commercial Enterprise Platform

This ZIP contains the complete Flutter application source for the Ultra commercial billing platform.

## Priority

The UI follows the supplied Ultra reference format:
- Dark navy enterprise sidebar
- Same navigation hierarchy
- Same commercial terminal visual language
- Same section numbering and field grouping
- Sales Invoice remains the priority detailed screen
- All other modules are included and navigable

## Modules included

1. Login
2. Dashboard / Home
3. Unit Master
4. Ledger Master
5. Customer Master
6. Product / Material Master
7. Delivery Challan
8. Quotation
9. Sales Invoice
10. Sales Reports
11. Purchase Order
12. Purchase Voucher
13. Purchase Reports
14. Transactions
15. Stock
16. Sync Queue
17. Settings

## Database

SQLite is used locally. The database is shared by all screens.

The project is prepared as a Flutter source project. Because this environment does not contain the Flutter SDK, platform runner folders are not generated here.

After extracting:

```powershell
cd ultra_enterprise_full
flutter create .
flutter pub get
flutter run -d windows
```

`flutter create .` creates the standard Android/Windows/macOS/iOS runner files while preserving this `lib/` and `pubspec.yaml`.

## VPS connection

The API base URL is defined in:

`lib/services/api_service.dart`

Set it to the deployed Ultra API URL before production use.

Current backend contract:
- GET /health
- GET /api/units
- GET /api/customers
- GET /api/products
- GET /api/stock
- POST /api/sales-invoices
- GET /api/sales-invoices
- GET /api/sales-invoices/:id
- POST /api/sales-invoices/:id/cancel

The Sales Invoice screen saves locally first and creates a sync queue entry. Server synchronization is intentionally separated so the same SQLite database can support offline operation.

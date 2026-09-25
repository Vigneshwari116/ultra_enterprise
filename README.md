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

## VPS connection (server-primary)

Data mode is controlled in `lib/config/ultra_config.dart`:

- `persistLocally = false` (default) — all saves **POST/PUT directly to the Ultra REST API** (no SQLite writes).
- `persistLocally = true` — legacy offline-first SQLite + sync queue.

API base URL: `UltraConfig.apiBaseUrl` (override at build time with `--dart-define=ULTRA_API_URL=https://your-api-host`).

### REST contract

Health and masters:

- `GET /health`
- `GET|POST /api/units` — `PUT|DELETE /api/units/:id`
- `GET|POST /api/customers` — `PUT /api/customers/:id`
- `GET|POST /api/suppliers` — `PUT /api/suppliers/:id`
- `GET|POST /api/products` — `PUT /api/products/:id`
- `GET|POST /api/ledger-accounts` — `PUT /api/ledger-accounts/:id`
- `GET|POST /api/material-types` — `PUT|DELETE /api/material-types/:id`
- `GET /api/stock` — `POST /api/stock/adjust` `{ product_id, quantity_delta, reason }`

Commercial documents (header fields use **snake_case** matching the Flutter forms; line rows live in an `items` array; quotations also send `terms`):

- `GET|POST /api/sales-invoices` — `GET /api/sales-invoices/:id` — `POST /api/sales-invoices/:id/cancel`
- `GET|POST /api/purchase-orders` — `GET /api/purchase-orders/:id` — `PUT /api/purchase-orders/:id/status`
- `GET|POST /api/purchase-vouchers`
- `GET|POST /api/delivery-challans` — `GET /api/delivery-challans/:id`
- `GET|POST /api/quotations` — `GET /api/quotations/:id` — `PUT /api/quotations/:id/status`
- `GET|POST /api/adjustment-notes` — `GET /api/adjustment-notes/:id`
- `GET|POST /api/receipts` — `GET|POST /api/payments`
- `GET|POST /api/journal-vouchers` — `GET /api/journal-vouchers/summary`
- `GET /api/cash-passbook`

List endpoints may return a JSON array or `{ "results": [ ... ] }`. Create endpoints must return `{ "id": <number>, ... }`.

### Example: sales invoice POST body

```json
{
  "uuid": "550e8400-e29b-41d4-a716-446655440000",
  "invoice_no": 12,
  "transaction_date": "2026-09-25",
  "customer_id": 3,
  "state_zone": "INTRA",
  "taxable_total": 10000,
  "cgst_total": 900,
  "sgst_total": 900,
  "igst_total": 0,
  "grand_total": 11800,
  "status": "POSTED",
  "items": [
    {
      "product_id": 1,
      "description": "Widget",
      "uom": "PCS",
      "hsn": "8471",
      "quantity": 10,
      "rate": 1000,
      "cgst_percent": 9,
      "sgst_percent": 9,
      "igst_percent": 0,
      "taxable": 10000,
      "cgst": 900,
      "sgst": 900,
      "igst": 0,
      "total": 11800
    }
  ]
}
```

Implementation entry point: `lib/services/ultra_repository.dart`.

# PostgreSQL reference

Handlers assume tables aligned with the Flutter SQLite schema in `lib/database/app_database.dart` and the live VPS `ultra_enterprise` database.

Do **not** run destructive migrations on production. If a table is missing on VPS, add it manually to match the SQLite `CREATE TABLE` definitions before enabling the corresponding routes.

Accounting migration: `migrations/001_accounting.sql` (`ledgers`, `journal_entries`, `voucher_counters`, party ledger backfill).

Sales invoice **POST** is implemented in `lib/routes/sales_invoices.dart` with automatic posting (`lib/accounting/post_sales.dart`).

**Numbering:** `invoice_no` is allocated from `sales_invoice_number_seq` (global, never reset per FY). User-facing `voucher_no_display` (e.g. `SAL-26-27-1`) comes from `voucher_counters` and resets each FY. Migration `001_accounting.sql` defines sequences and `sync_global_voucher_sequences()` to `setval` past existing `MAX` values.

## `units`

Columns used by merged routes:

| Column | Notes |
|--------|--------|
| `id` | serial PK |
| `code` | required; stored uppercased |
| `name` | required (or derived from `description`) |
| `description` | optional; UOM master description |
| `is_active` | boolean; `GET /api/units` returns all rows |
| `created_at` | timestamptz |

### `DELETE /api/units/:id`

- If any **product** references `unit_id`, the unit is **not** hard-deleted. The handler sets `is_active = false` and returns `{ "deactivated": true }` so historical product and document rows keep valid `unit_id` values.
- If nothing references the unit, the row is **hard-deleted**.

## `products`

Columns used by merged routes:

| Column | Notes |
|--------|--------|
| `id`, `uuid` | PK; UUID assigned on create |
| `product_code` | from `barcode` / `product_code` in JSON |
| `product_name` | required on create |
| `unit_id` | required on create; FK to `units` |
| `material_type_id` | optional |
| `hsn_code` | from `hsn` / `hsn_code` |
| `sales_rate`, `purchase_rate`, `gst_rate` | optional numerics |
| `reorder_level`, `opening_stock`, `current_stock` | defaults 0 on create |
| `is_active` | `GET /api/products` lists only `is_active = true` |

Stock fields and balances are **not** changed on `PUT` unless explicitly sent (Flutter product master does not send stock on update).

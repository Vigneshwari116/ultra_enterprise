# SQL statement audit vs `vps_ultra_enterprise_schema.sql`

Columns listed per statement after PR #21 VPS fixes.

## `purchase_vouchers.dart`

| Location | SQL | Table | Columns |
|----------|-----|-------|---------|
| list | `SELECT id, uuid, status, data, voucher_no_display, created_at FROM purchase_vouchers` | purchase_vouchers | id, uuid, status, data, voucher_no_display, created_at |
| get header | `SELECT id, uuid, status, data, voucher_no_display, created_at FROM purchase_vouchers WHERE id = @id` | purchase_vouchers | same |
| get supplier | `SELECT id, data FROM suppliers WHERE id = @id` | suppliers | id, data |
| get PO | `SELECT po_no, po_date FROM purchase_orders WHERE id = @id` | purchase_orders | po_no, po_date |
| get items | `SELECT id, parent_id, data FROM purchase_voucher_items WHERE parent_id = @id` | purchase_voucher_items | id, parent_id, data |
| create header | `INSERT INTO purchase_vouchers (uuid, status, data, voucher_no_display, created_at) VALUES (...)` | purchase_vouchers | uuid, status, data, voucher_no_display, created_at |
| create item | `INSERT INTO purchase_voucher_items (parent_id, data) VALUES (...)` | purchase_voucher_items | parent_id, data |

## `cash_transactions.dart`

| Location | SQL | Table | Columns |
|----------|-----|-------|---------|
| list receipts | `SELECT id, uuid, kind, data, voucher_no_display, created_at FROM receipts` | receipts | id, uuid, kind, data, voucher_no_display, created_at |
| create receipt | `INSERT INTO receipts (uuid, kind, data, voucher_no_display, created_at) VALUES (...)` | receipts | uuid, kind, data, voucher_no_display, created_at |
| list payments | `SELECT id, uuid, kind, data, voucher_no_display, created_at FROM payments` | payments | id, uuid, kind, data, voucher_no_display, created_at |
| create payment | `INSERT INTO payments (uuid, kind, data, voucher_no_display, created_at) VALUES (...)` | payments | uuid, kind, data, voucher_no_display, created_at |
| passbook | reads `receipts.data`, `payments.data` JSON keys; joins `customers`, `suppliers` | receipts, payments, customers, suppliers | envelope data + customer_name / supplier data |

## `masters.dart` (suppliers)

| Location | SQL | Table | Columns |
|----------|-----|-------|---------|
| get | `SELECT id, uuid, status, data, created_at FROM suppliers WHERE id = @id` | suppliers | id, uuid, status, data, created_at |
| create | `INSERT INTO suppliers (uuid, status, data) VALUES (...)` | suppliers | uuid, status, data |
| update select | `SELECT data FROM suppliers WHERE id = @id` | suppliers | data |
| update | `UPDATE suppliers SET data = @data, status = COALESCE(@status, status) WHERE id = @id` | suppliers | data, status |

## `ledger.dart` (ledger_accounts envelope)

| Location | SQL | Table | Columns |
|----------|-----|-------|---------|
| list | `SELECT id, uuid, status, data, created_at FROM ledger_accounts` | ledger_accounts | id, uuid, status, data, created_at |
| create | `INSERT INTO ledger_accounts (uuid, status, data, created_at) VALUES (...)` | ledger_accounts | uuid, status, data, created_at |
| update | `SELECT data` / `UPDATE ledger_accounts SET data = @data WHERE id = @id` | ledger_accounts | data |

## `accounting_ledgers.dart` + `ledger_service.dart`

| Location | SQL | Table | Columns |
|----------|-----|-------|---------|
| party get | `SELECT id, name, party_kind, party_id, opening_balance, opening_type FROM ledgers WHERE ...` | ledgers | accounting migration |
| party upsert | `UPDATE/INSERT ledgers (...)` | ledgers | name, group_type, party_kind, party_id, opening_balance, opening_type |
| ensure supplier | `SELECT data FROM suppliers` / `INSERT INTO ledgers (...)` | suppliers, ledgers | data; ledger columns |

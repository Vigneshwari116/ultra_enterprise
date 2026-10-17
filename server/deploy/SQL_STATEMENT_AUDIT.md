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
| update select | `SELECT uuid, status, data, voucher_no_display FROM purchase_vouchers WHERE id = @id` | purchase_vouchers | uuid, status, data, voucher_no_display |
| update header | `UPDATE purchase_vouchers SET status = @status, data = @data WHERE id = @id` | purchase_vouchers | status, data |
| update delete items | `DELETE FROM purchase_voucher_items WHERE parent_id = @id` | purchase_voucher_items | parent_id |
| delete select | `SELECT data FROM purchase_vouchers WHERE id = @id` | purchase_vouchers | data |
| delete header | `DELETE FROM purchase_vouchers WHERE id = @id RETURNING id` | purchase_vouchers | id |

## `sales_invoices.dart`

| Location | SQL | Table | Columns |
|----------|-----|-------|---------|
| update select | `SELECT invoice_no, voucher_no_display FROM sales_invoices WHERE id = @id` | sales_invoices | invoice_no, voucher_no_display |
| update header | `UPDATE sales_invoices SET customer_id, transaction_date, ... WHERE id = @id` | sales_invoices | customer_id, transaction_date, po_no, po_date, state_zone_id, challan_dc_no, challan_dc_date, total_packages, vehicle_dispatch_mode, due_days, eway_bill_no, taxable_total, cgst_total, sgst_total, igst_total, compound_gst_total, fwd_charge, grand_total, status, updated_at |
| update delete items | `DELETE FROM sales_invoice_items WHERE invoice_id = @id` | sales_invoice_items | invoice_id |
| delete select | `SELECT invoice_no FROM sales_invoices WHERE id = @id` | sales_invoices | invoice_no |
| delete header | `DELETE FROM sales_invoices WHERE id = @id RETURNING id` | sales_invoices | id |

## `cash_transactions.dart`

| Location | SQL | Table | Columns |
|----------|-----|-------|---------|
| list receipts | `SELECT id, uuid, kind, data, voucher_no_display, created_at FROM receipts` | receipts | id, uuid, kind, data, voucher_no_display, created_at |
| create receipt | `INSERT INTO receipts (uuid, kind, data, voucher_no_display, created_at) VALUES (...)` | receipts | uuid, kind, data, voucher_no_display, created_at |
| list payments | `SELECT id, uuid, kind, data, voucher_no_display, created_at FROM payments` | payments | id, uuid, kind, data, voucher_no_display, created_at |
| create payment | `INSERT INTO payments (uuid, kind, data, voucher_no_display, created_at) VALUES (...)` | payments | uuid, kind, data, voucher_no_display, created_at |
| passbook | reads `receipts.data`, `payments.data` JSON keys; joins `customers`, `suppliers` | receipts, payments, customers, suppliers | envelope data + customer_name / supplier data |
| update receipt select | `SELECT uuid, data, voucher_no_display, created_at FROM receipts WHERE id = @id` | receipts | uuid, data, voucher_no_display, created_at |
| update receipt | `UPDATE receipts SET data = @data WHERE id = @id` | receipts | data |
| delete receipt select | `SELECT data FROM receipts WHERE id = @id` | receipts | data |
| delete receipt | `DELETE FROM receipts WHERE id = @id RETURNING id` | receipts | id |
| update payment select | `SELECT uuid, data, voucher_no_display, created_at FROM payments WHERE id = @id` | payments | uuid, data, voucher_no_display, created_at |
| update payment | `UPDATE payments SET data = @data WHERE id = @id` | payments | data |
| delete payment select | `SELECT data FROM payments WHERE id = @id` | payments | data |
| delete payment | `DELETE FROM payments WHERE id = @id RETURNING id` | payments | id |

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

## `expense_vouchers.dart`

| Location | SQL | Table | Columns |
|----------|-----|-------|---------|
| list expense ledgers | `SELECT id, name, group_type, system_key FROM ledgers WHERE group_type = 'expense'` | ledgers | id, name, group_type, system_key |
| list | `SELECT ev.*, l.name AS expense_ledger_name FROM expense_vouchers ev JOIN ledgers l ...` | expense_vouchers, ledgers | id, uuid, voucher_no, voucher_no_display, voucher_date, expense_ledger_id, amount, cash_bank, narration, created_at, expense_ledger_name |
| get | `SELECT ev.*, l.name ... WHERE ev.id = @id` | expense_vouchers, ledgers | same |
| create | `INSERT INTO expense_vouchers (voucher_no, voucher_no_display, voucher_date, expense_ledger_id, amount, cash_bank, narration, created_at)` | expense_vouchers | voucher_no, voucher_no_display, voucher_date, expense_ledger_id, amount, cash_bank, narration, created_at |
| update select | `SELECT voucher_no, voucher_no_display FROM expense_vouchers WHERE id = @id` | expense_vouchers | voucher_no, voucher_no_display |
| update | `UPDATE expense_vouchers SET voucher_date, expense_ledger_id, amount, cash_bank, narration WHERE id = @id` | expense_vouchers | voucher_date, expense_ledger_id, amount, cash_bank, narration |
| delete select | `SELECT voucher_no FROM expense_vouchers WHERE id = @id` | expense_vouchers | voucher_no |
| delete | `DELETE FROM expense_vouchers WHERE id = @id RETURNING id` | expense_vouchers | id |

## `salary_vouchers.dart`

| Location | SQL | Table | Columns |
|----------|-----|-------|---------|
| list | `SELECT id, uuid, voucher_no, voucher_no_display, voucher_date, amount, cash_bank, narration, created_at FROM salary_vouchers` | salary_vouchers | id, uuid, voucher_no, voucher_no_display, voucher_date, amount, cash_bank, narration, created_at |
| get | `SELECT ... FROM salary_vouchers WHERE id = @id` | salary_vouchers | same |
| create | `INSERT INTO salary_vouchers (voucher_no, voucher_no_display, voucher_date, amount, cash_bank, narration, created_at)` | salary_vouchers | voucher_no, voucher_no_display, voucher_date, amount, cash_bank, narration, created_at |
| update select | `SELECT voucher_no, voucher_no_display FROM salary_vouchers WHERE id = @id` | salary_vouchers | voucher_no, voucher_no_display |
| update | `UPDATE salary_vouchers SET voucher_date, amount, cash_bank, narration WHERE id = @id` | salary_vouchers | voucher_date, amount, cash_bank, narration |
| delete select | `SELECT voucher_no FROM salary_vouchers WHERE id = @id` | salary_vouchers | voucher_no |
| delete | `DELETE FROM salary_vouchers WHERE id = @id RETURNING id` | salary_vouchers | id |

## `ledger_service.dart` (expense ledger resolve)

| Location | SQL | Table | Columns |
|----------|-----|-------|---------|
| resolve expense | `SELECT id FROM ledgers WHERE id = @id AND group_type = 'expense'` | ledgers | id |

## `accounting_ledgers.dart` + `ledger_service.dart`

| Location | SQL | Table | Columns |
|----------|-----|-------|---------|
| party get | `SELECT id, name, party_kind, party_id, opening_balance, opening_type FROM ledgers WHERE ...` | ledgers | accounting migration |
| party upsert | `UPDATE/INSERT ledgers (...)` | ledgers | name, group_type, party_kind, party_id, opening_balance, opening_type |
| ensure supplier | `SELECT data FROM suppliers` / `INSERT INTO ledgers (...)` | suppliers, ledgers | data; ledger columns |

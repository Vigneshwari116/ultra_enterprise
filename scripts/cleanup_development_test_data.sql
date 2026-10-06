-- Removes development / QA transactional and master business data from the Ultra PostgreSQL database.
-- Preserves schema, indexes, constraints, and standard UOM rows (PCS, KG, LTR, BOX, NOS, MTR).
-- Run on the VPS (or any environment) with:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f scripts/cleanup_development_test_data.sql
--
-- Review FK order before running on production. Wrapped in a single transaction.

BEGIN;

-- Optional: uncomment if your VPS has a stock_movements (or similar) audit table.
-- DELETE FROM stock_movements;

-- Transaction line items (children first)
DELETE FROM purchase_voucher_items;
DELETE FROM sales_invoice_items;
DELETE FROM purchase_order_items;
DELETE FROM quotation_items;
DELETE FROM quotation_terms;
DELETE FROM delivery_challan_items;
DELETE FROM adjustment_note_items;
DELETE FROM journal_voucher_lines;

-- Transaction headers
DELETE FROM purchase_vouchers;
DELETE FROM sales_invoices;
DELETE FROM purchase_orders;
DELETE FROM quotations;
DELETE FROM delivery_challans;
DELETE FROM adjustment_notes;
DELETE FROM journal_vouchers;
DELETE FROM receipts;
DELETE FROM payments;

-- Stock balances (products removed below)
DELETE FROM stock;

-- Business masters created during testing
DELETE FROM products;
DELETE FROM customers;
DELETE FROM suppliers;
DELETE FROM ledger_accounts;

-- Remove non-standard units; keep canonical UOM codes used by the app.
DELETE FROM units
WHERE UPPER(code) NOT IN ('PCS', 'KG', 'LTR', 'BOX', 'NOS', 'MTR');

-- Material types are structural master configuration — preserved intentionally.

COMMIT;

-- Post-cleanup verification (run manually after commit):
-- SELECT 'customers' AS t, COUNT(*) FROM customers
-- UNION ALL SELECT 'suppliers', COUNT(*) FROM suppliers
-- UNION ALL SELECT 'products', COUNT(*) FROM products
-- UNION ALL SELECT 'stock', COUNT(*) FROM stock
-- UNION ALL SELECT 'purchase_orders', COUNT(*) FROM purchase_orders
-- UNION ALL SELECT 'purchase_vouchers', COUNT(*) FROM purchase_vouchers
-- UNION ALL SELECT 'sales_invoices', COUNT(*) FROM sales_invoices
-- UNION ALL SELECT 'units', COUNT(*) FROM units;

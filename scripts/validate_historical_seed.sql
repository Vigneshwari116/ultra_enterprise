-- Post-seed validation for Ultra Enterprise historical import.
-- Run after scripts/seed_historical_data.py --execute
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f scripts/validate_historical_seed.sql

\echo '=== Table counts ==='
SELECT 'state_zones' AS table_name, COUNT(*)::bigint AS row_count FROM state_zones
UNION ALL SELECT 'units', COUNT(*) FROM units
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'suppliers', COUNT(*) FROM suppliers
UNION ALL SELECT 'purchase_vouchers', COUNT(*) FROM purchase_vouchers
UNION ALL SELECT 'purchase_voucher_items', COUNT(*) FROM purchase_voucher_items
UNION ALL SELECT 'sales_invoices', COUNT(*) FROM sales_invoices
UNION ALL SELECT 'sales_invoice_items', COUNT(*) FROM sales_invoice_items
UNION ALL SELECT 'stock', COUNT(*) FROM stock
UNION ALL SELECT 'stock_movements', COUNT(*) FROM stock_movements
ORDER BY table_name;

\echo '=== Expected count checks ==='
WITH expected(name, want) AS (
  VALUES
    ('state_zones', 2),
    ('units', 9),
    ('products', 982),
    ('customers', 16),
    ('suppliers', 87),
    ('purchase_vouchers', 261),
    ('purchase_voucher_items', 874),
    ('sales_invoices', 208),
    ('sales_invoice_items', 371)
),
actual AS (
  SELECT 'state_zones' AS name, COUNT(*)::bigint AS got FROM state_zones
  UNION ALL SELECT 'units', COUNT(*) FROM units
  UNION ALL SELECT 'products', COUNT(*) FROM products
  UNION ALL SELECT 'customers', COUNT(*) FROM customers
  UNION ALL SELECT 'suppliers', COUNT(*) FROM suppliers
  UNION ALL SELECT 'purchase_vouchers', COUNT(*) FROM purchase_vouchers
  UNION ALL SELECT 'purchase_voucher_items', COUNT(*) FROM purchase_voucher_items
  UNION ALL SELECT 'sales_invoices', COUNT(*) FROM sales_invoices
  UNION ALL SELECT 'sales_invoice_items', COUNT(*) FROM sales_invoice_items
)
SELECT e.name, e.want, a.got, CASE WHEN e.want = a.got THEN 'OK' ELSE 'FAIL' END AS status
FROM expected e
JOIN actual a USING (name)
ORDER BY e.name;

\echo '=== Purchase voucher header coverage ==='
SELECT COUNT(*) AS distinct_voucher_nos
FROM purchase_vouchers
WHERE (data->>'voucher_no') ~ '^[0-9]+$';

\echo '=== Orphan purchase voucher items ==='
SELECT COUNT(*) AS orphan_purchase_items
FROM purchase_voucher_items pvi
LEFT JOIN purchase_vouchers pv ON pv.id = pvi.parent_id
WHERE pv.id IS NULL;

\echo '=== Orphan sales invoice items ==='
SELECT COUNT(*) AS orphan_sales_items
FROM sales_invoice_items sii
LEFT JOIN sales_invoices si ON si.id = sii.invoice_id
WHERE si.id IS NULL;

\echo '=== Negative stock ==='
SELECT product_id, quantity
FROM stock
WHERE quantity < 0;

\echo '=== State zone distribution ==='
SELECT state_zone_id, COUNT(*) AS invoice_count
FROM sales_invoices
GROUP BY state_zone_id
ORDER BY state_zone_id;

\echo '=== Required units present ==='
SELECT code
FROM units
WHERE UPPER(code) IN ('SQM', 'COIL', 'SET')
ORDER BY code;

\echo '=== Blank HSN products ==='
SELECT COUNT(*) AS blank_hsn_products
FROM products
WHERE COALESCE(TRIM(hsn_code), '') = '';

\echo '=== Duplicate product keys ==='
SELECT product_code, COUNT(*) AS copies
FROM products
GROUP BY product_code
HAVING COUNT(*) > 1;

SELECT uuid, COUNT(*) AS copies
FROM products
GROUP BY uuid
HAVING COUNT(*) > 1;

\echo '=== Duplicate purchase voucher UUIDs ==='
SELECT uuid, COUNT(*) AS copies
FROM purchase_vouchers
GROUP BY uuid
HAVING COUNT(*) > 1;

SELECT (data->>'voucher_no')::int AS voucher_no, COUNT(*) AS copies
FROM purchase_vouchers
WHERE data->>'voucher_no' IS NOT NULL
GROUP BY (data->>'voucher_no')::int
HAVING COUNT(*) > 1;

\echo '=== Duplicate sales invoice UUIDs ==='
SELECT uuid, COUNT(*) AS copies
FROM sales_invoices
GROUP BY uuid
HAVING COUNT(*) > 1;

SELECT invoice_no, COUNT(*) AS copies
FROM sales_invoices
GROUP BY invoice_no
HAVING COUNT(*) > 1;

\echo '=== Deterministic UUID pattern checks ==='
SELECT COUNT(*) AS purchase_uuid_pattern_ok
FROM purchase_vouchers
WHERE uuid LIKE 'PURCHASE:%';

SELECT COUNT(*) AS sales_uuid_pattern_ok
FROM sales_invoices
WHERE uuid LIKE 'SALES:%';

SELECT COUNT(*) AS product_uuid_pattern_ok
FROM products
WHERE uuid LIKE 'PRODUCT:%';

\echo '=== Purchase stock movement count ==='
SELECT COUNT(*) AS purchase_stock_movements
FROM stock_movements
WHERE movement_type = 'PURCHASE_VOUCHER';

SELECT COUNT(*) AS invalid_reference_type_rows
FROM stock_movements
WHERE movement_type = 'PURCHASE_VOUCHER'
  AND (reference_type IS NOT NULL OR reference_id IS NOT NULL);

\echo '=== Stock movement field sanity ==='
SELECT COUNT(*) AS bad_movement_rows
FROM stock_movements
WHERE movement_type <> 'PURCHASE_VOUCHER'
   OR quantity <= 0
   OR balance_after < 0;

\echo '=== Stock balance consistency (products with purchase movements) ==='
SELECT p.id AS product_id,
       COALESCE(st.quantity, 0) AS stock_qty,
       COALESCE(mv.last_balance, 0) AS last_movement_balance
FROM products p
LEFT JOIN stock st ON st.product_id = p.id
LEFT JOIN (
  SELECT DISTINCT ON (product_id)
         product_id, balance_after AS last_balance
  FROM stock_movements
  ORDER BY product_id, created_at DESC, id DESC
) mv ON mv.product_id = p.id
WHERE EXISTS (
  SELECT 1 FROM stock_movements sm
  WHERE sm.product_id = p.id AND sm.movement_type = 'PURCHASE_VOUCHER'
)
AND COALESCE(st.quantity, 0) <> COALESCE(mv.last_balance, 0);

\echo '=== State zone master rows ==='
SELECT id, code, name, is_active
FROM state_zones
ORDER BY id;

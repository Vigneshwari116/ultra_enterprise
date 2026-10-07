-- Read-only live VPS schema preflight for historical seed.
-- Run: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f scripts/preflight_live_schema.sql

\echo '=== customers.uuid ==='
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'customers'
  AND column_name = 'uuid';

\echo '=== suppliers.uuid ==='
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'suppliers'
  AND column_name = 'uuid';

\echo '=== stock_movements.uuid ==='
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'stock_movements'
  AND column_name = 'uuid';

\echo '=== stock_movements triggers ==='
SELECT tgname, pg_get_triggerdef(oid) AS definition
FROM pg_trigger
WHERE tgrelid = 'public.stock_movements'::regclass
  AND NOT tgisinternal;

\echo '=== Seed INSERT column presence ==='
WITH expected(table_name, columns) AS (
  VALUES
    ('products', ARRAY['uuid','product_code','product_name','unit_id','hsn_code','sales_rate','purchase_rate','gst_rate','reorder_level','is_active','created_at']),
    ('customers', ARRAY['uuid','customer_code','customer_name','address','city','postal_pincode','gstin','opening_balance_cr','opening_balance_dr','is_active','created_at']),
    ('suppliers', ARRAY['uuid','status','data','created_at']),
    ('purchase_vouchers', ARRAY['uuid','status','data','created_at']),
    ('purchase_voucher_items', ARRAY['parent_id','data','created_at']),
    ('sales_invoices', ARRAY['uuid','invoice_no','transaction_date','customer_id','state_zone_id','po_no','po_date','challan_dc_no','challan_dc_date','total_packages','vehicle_dispatch_mode','due_days','eway_bill_no','taxable_total','cgst_total','sgst_total','igst_total','compound_gst_total','grand_total','status']),
    ('sales_invoice_items', ARRAY['uuid','invoice_id','product_id','description','unit_id','hsn_code','quantity','rate','cgst_percent','sgst_percent','igst_percent','taxable_amount','cgst_amount','sgst_amount','igst_amount','compound_total']),
    ('stock', ARRAY['product_id','quantity','updated_at']),
    ('stock_movements', ARRAY['uuid','product_id','movement_type','reference_type','reference_id','quantity','balance_after','created_at'])
),
expanded AS (
  SELECT e.table_name, col AS column_name
  FROM expected e
  CROSS JOIN LATERAL unnest(e.columns) AS col
)
SELECT
  x.table_name,
  x.column_name,
  c.data_type,
  CASE WHEN c.column_name IS NULL THEN 'MISSING' ELSE 'OK' END AS status
FROM expanded x
LEFT JOIN information_schema.columns c
  ON c.table_schema = 'public'
 AND c.table_name = x.table_name
 AND c.column_name = x.column_name
ORDER BY x.table_name, x.column_name;

\echo '=== Full column types for seed tables ==='
SELECT table_name, column_name, data_type, udt_name, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
    'products','customers','suppliers','purchase_vouchers','purchase_voucher_items',
    'sales_invoices','sales_invoice_items','stock','stock_movements','state_zones','units'
  )
ORDER BY table_name, ordinal_position;

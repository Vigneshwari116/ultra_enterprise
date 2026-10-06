#!/usr/bin/env bash
# Run development test-data cleanup against PostgreSQL.
# Requires DATABASE_URL (postgresql://...) with rights on the Ultra database.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "ERROR: Set DATABASE_URL to your PostgreSQL connection string." >&2
  exit 1
fi
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$ROOT/scripts/cleanup_development_test_data.sql"
echo "--- Row counts after cleanup ---"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "
SELECT 'customers' AS table_name, COUNT(*)::bigint AS row_count FROM customers
UNION ALL SELECT 'suppliers', COUNT(*) FROM suppliers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'stock', COUNT(*) FROM stock
UNION ALL SELECT 'purchase_orders', COUNT(*) FROM purchase_orders
UNION ALL SELECT 'purchase_vouchers', COUNT(*) FROM purchase_vouchers
UNION ALL SELECT 'sales_invoices', COUNT(*) FROM sales_invoices
UNION ALL SELECT 'units', COUNT(*) FROM units
ORDER BY table_name;
"

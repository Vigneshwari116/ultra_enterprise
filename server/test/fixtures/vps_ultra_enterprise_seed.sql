INSERT INTO state_zones (id, code, name) VALUES
  (1, 'INTRA', 'Intra State'),
  (2, 'INTER', 'Inter State');

INSERT INTO units (id, code, name) VALUES (1, 'PCS', 'Pieces');

INSERT INTO customers (id, customer_name) VALUES (1, 'VPS Test Customer');

INSERT INTO suppliers (id, uuid, status, data) VALUES (
  1,
  'sup-uuid-1',
  'ACTIVE',
  '{"supplier_name":"VPS Test Supplier","supplier_code":"S1"}'
);

INSERT INTO products (id, product_name, unit_id) VALUES (1, 'Test Widget', 1);

SELECT setval('public.state_zones_id_seq', (SELECT COALESCE(MAX(id), 1) FROM state_zones));
SELECT setval('public.units_id_seq', (SELECT COALESCE(MAX(id), 1) FROM units));
SELECT setval('public.customers_id_seq', (SELECT COALESCE(MAX(id), 1) FROM customers));
SELECT setval('public.suppliers_id_seq', (SELECT COALESCE(MAX(id), 1) FROM suppliers));
SELECT setval('public.products_id_seq', (SELECT COALESCE(MAX(id), 1) FROM products));

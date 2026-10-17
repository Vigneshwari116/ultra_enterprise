INSERT INTO state_zones (id, name) VALUES (1, 'Intra State'), (2, 'Inter State');
INSERT INTO units (id, code, name) VALUES (1, 'PCS', 'Pieces');
INSERT INTO customers (id, customer_name) VALUES (1, 'VPS Test Customer');
INSERT INTO suppliers (id, uuid, status, data) VALUES (
  1,
  'sup-uuid-1',
  'ACTIVE',
  '{"supplier_name":"VPS Test Supplier","supplier_code":"S1"}'
);
INSERT INTO products (id, product_name, unit_id) VALUES (1, 'Test Widget', 1);

INSERT INTO state_zones (id, code, name) VALUES
  (1, 'INTRA', 'Intra State'),
  (2, 'INTER', 'Inter State');

INSERT INTO units (id, code, name) VALUES (1, 'PCS', 'Pieces');

INSERT INTO customers (id, customer_name) VALUES (1, 'VPS Test Customer');
INSERT INTO customers (id, customer_name) VALUES (17, 'Customer Seventeen');

INSERT INTO suppliers (id, uuid, status, data) VALUES (
  1,
  'sup-uuid-1',
  'ACTIVE',
  '{"supplier_name":"VPS Test Supplier","supplier_code":"S1"}'
);

INSERT INTO suppliers (id, uuid, status, data) VALUES (
  92,
  'sup-uuid-92',
  'ACTIVE',
  '{"supplier_name":"Supplier Ninety Two","supplier_code":"S92"}'
);

INSERT INTO material_types (id, uuid, status, data) VALUES (
  1,
  'mt-uuid-1',
  'ACTIVE',
  '{"type_code":"RM","description":"Raw Material"}'
);

INSERT INTO delivery_challans (id, uuid, dc_type, status, data) VALUES (
  1,
  'dc-uuid-inward',
  'INWARD',
  'POSTED',
  '{"serial_no":1,"document_date":"2026-10-15","party_kind":"SUPPLIER","party_id":1,"grand_total":1000,"total_pcs":10}'
);

INSERT INTO delivery_challans (id, uuid, dc_type, status, data) VALUES (
  2,
  'dc-uuid-proforma',
  'PROFORMA',
  'DRAFT',
  '{"serial_no":2,"document_date":"2026-10-16","party_kind":"CUSTOMER","party_id":17,"grand_total":500,"total_pcs":5}'
);

INSERT INTO products (id, product_name, unit_id) VALUES (1, 'Test Widget', 1);

SELECT setval('public.state_zones_id_seq', (SELECT COALESCE(MAX(id), 1) FROM state_zones));
SELECT setval('public.units_id_seq', (SELECT COALESCE(MAX(id), 1) FROM units));
SELECT setval('public.customers_id_seq', (SELECT COALESCE(MAX(id), 1) FROM customers));
SELECT setval('public.suppliers_id_seq', (SELECT COALESCE(MAX(id), 1) FROM suppliers));
SELECT setval('public.material_types_id_seq', (SELECT COALESCE(MAX(id), 1) FROM material_types));
SELECT setval('public.delivery_challans_id_seq', (SELECT COALESCE(MAX(id), 1) FROM delivery_challans));
SELECT setval('public.products_id_seq', (SELECT COALESCE(MAX(id), 1) FROM products));
